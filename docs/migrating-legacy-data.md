# Migrating the old app's data (Heroku)

The app was rebuilt on a new schema, so the old database can't simply be migrated in place: the new migrations create tables the old database already has. Instead the new app gets an **empty Postgres**, and `legacy:import` copies the old data into it. The old database is only ever read, and it stays attached as the backup and the way back.

What the import does (`lib/legacy/import.rb`, covered by `spec/lib/legacy/import_spec.rb`):

- Copies users, projects, memberships, integrations, scope features, role credentials, runs, audit log entries, findings and the Active Storage records, **keeping every id**.
- Users keep their password (the old bcrypt hash is read as is). They have no name, so they add one through onboarding at the next sign-in. Nobody becomes a super admin.
- Role credentials are copied as the ciphertext they already are, so they stay readable only while production keeps the same `AR_ENCRYPTION_*` values.
- Screenshots keep working while the new app uses the same bucket (`EVIDENCE_S3_BUCKET` or `S3_BUCKET`).
- Dry run by default; it writes only with `APPLY=1`, in one transaction, and checks the row counts per table. It refuses a database that already has data.

Heroku commands below use two placeholders; replace them once:

```bash
BACKEND=<your backend app name>
WEB=<your web app name>
```

The Heroku commands were not run against your apps; the import itself was rehearsed on a copy of the staging dump (fresh database built with `db:migrate`, dry run, apply, sign-in with an old password, second run refused).

## 1. Before the cutover (no downtime)

```bash
# 1. The config var NAMES (not values). All of these must exist:
#    APP_BASE_URL FRONTEND_ORIGINS EVIDENCE_S3_BUCKET AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION
#    AR_ENCRYPTION_PRIMARY_KEY AR_ENCRYPTION_DETERMINISTIC_KEY AR_ENCRYPTION_KEY_DERIVATION_SALT
#    AGENT_API_TOKEN AGENT_WORKER_API_TOKEN AGENT_WORKER_BASE_URL REDISCLOUD_URL
#    GITHUB_APP_ID GITHUB_APP_SLUG GITHUB_APP_PRIVATE_KEY GITHUB_APP_CLIENT_ID GITHUB_APP_CLIENT_SECRET
#    and RAILS_MASTER_KEY or SECRET_KEY_BASE
heroku config -a $BACKEND --shell | cut -d= -f1 | sort

# 2. Optional new settings. Without SMTP_* the API boots but reset and invitation emails fail;
#    without FLIPPER_UI_* the /flipper and /sidekiq dashboards are not routed.
heroku config:set -a $BACKEND SMTP_ADDRESS=... SMTP_USERNAME=... SMTP_PASSWORD=... MAILER_SENDER=no-reply@example.com
heroku config:set -a $BACKEND FLIPPER_UI_USERNAME=... FLIPPER_UI_PASSWORD=...

# 3. The new code needs Ruby 4.0.7 (.ruby-version) and Rails 8.1. Check the stack supports it, ideally by deploying
#    this branch to a throwaway review app first.
heroku stack -a $BACKEND
heroku buildpacks -a $BACKEND

# 4. Which database is the old one, and what plan is it? Note the attachment name, e.g. HEROKU_POSTGRESQL_AMBER.
heroku pg:info -a $BACKEND

# 5. A backup you can restore from, kept outside Heroku too.
heroku pg:backups:capture -a $BACKEND
heroku pg:backups:download -a $BACKEND

# 6. The web build reads VITE_APP_API_URL at build time. It must be the backend's https URL.
heroku config:get VITE_APP_API_URL -a $WEB
```

## 2. Cutover (about ten minutes of downtime)

The old web app can't talk to the new API (the GraphQL operation names changed), so both apps go into maintenance.

```bash
# Stop traffic and anything that writes to the old database.
heroku maintenance:on -a $WEB
heroku maintenance:on -a $BACKEND
heroku ps:scale web=0 worker=0 -a $BACKEND

# Optional: confirm nothing is left in the old queues (run this BEFORE scaling to zero if you want to check).
#   heroku run -a $BACKEND "bin/rails runner 'p Sidekiq::Queue.all.to_h { [_1.name, _1.size] }, Sidekiq::RetrySet.new.size'"

# A last backup, now that writes have stopped.
heroku pg:backups:capture -a $BACKEND

# A new, empty database, promoted BEFORE the new code is pushed: the release phase runs db:migrate
# against DATABASE_URL, and that must never be the old database.
heroku addons:create heroku-postgresql:<same plan as the old one> --as NEW_DB -a $BACKEND
heroku pg:wait -a $BACKEND
heroku pg:promote NEW_DB -a $BACKEND
heroku pg:info -a $BACKEND          # DATABASE_URL is now NEW_DB; the old one is still attached under its colour name

# Deploy the backend. The release phase builds the schema and registers the feature flags.
git push heroku feature/boilerplate-migration:main     # or main, once the PR is merged
heroku releases -a $BACKEND -n 3                         # the latest release must say "succeeded"

# Import. Single quotes: the dyno expands the variable, so no URL is typed or printed.
# Replace AMBER with the old database's colour from pg:info.
heroku run -a $BACKEND 'LEGACY_DATABASE_URL=$HEROKU_POSTGRESQL_AMBER_URL bin/rails legacy:import'            # dry run
heroku run -a $BACKEND 'APPLY=1 LEGACY_DATABASE_URL=$HEROKU_POSTGRESQL_AMBER_URL bin/rails legacy:import'    # for real

# Make the people who run the Flipper dashboards and the user list super admins (db:seed does not promote an
# existing user). Nobody is a super admin after the import.
heroku run -a $BACKEND "bin/rails runner 'User.find_by!(email: %q(you@example.com)).update_column(:role, User.roles.fetch(%q(super_admin)))'"

# Bring the backend up, then deploy the web app on top of it.
heroku ps:scale web=1 worker=1 -a $BACKEND
heroku maintenance:off -a $BACKEND
git push heroku-web feature/boilerplate-migration:main   # the web repo's Heroku remote; keep whatever you deploy with today
heroku maintenance:off -a $WEB
```

The import runs in one transaction, so a failed import leaves the new database empty and can simply be run again.

## 3. After the cutover

```bash
# Healthy, and no boot errors. A "SMTP_ADDRESS is not set" warning is expected until you set it.
curl -s -o /dev/null -w '%{http_code}\n' https://<backend host>/up        # 200
heroku logs -a $BACKEND -n 200

# The counts must equal the dry run's.
heroku run -a $BACKEND "bin/rails runner 'puts [User.count, Project.count, Run.count, Finding.count].inspect'"

# Role credentials must be readable. Anything printed as unreadable has to be saved again in the UI
# (the AR_ENCRYPTION_* values differ from the ones it was written with).
heroku run -a $BACKEND "bin/rails runner 'RoleCredential.find_each { |c| c.encrypted_credential_ref rescue puts(%q(unreadable ) + c.id.to_s) }'"

# Heroku Scheduler (add these in the dashboard):
#   bin/rails runs:fail_stale                       every 10 minutes
#   bin/rails auth:purge_expired_credentials        daily
#   bin/rails email_logs:purge_expired              daily
#   bin/rails sms_logs:purge_expired                daily
heroku addons:open scheduler -a $BACKEND
```

Then check by hand: sign in as a real user and finish onboarding, open a project and an issue with a screenshot, and dispatch a run so the worker's callback is exercised.

Keep the old database attached for a week or two. When you are sure, remove it:

```bash
heroku addons:destroy HEROKU_POSTGRESQL_AMBER -a $BACKEND --confirm $BACKEND
```

## Rolling back (while the old database still exists)

```bash
heroku maintenance:on -a $WEB && heroku maintenance:on -a $BACKEND
heroku ps:scale web=0 worker=0 -a $BACKEND
heroku pg:promote HEROKU_POSTGRESQL_AMBER -a $BACKEND       # the old database is primary again
heroku releases -a $BACKEND                                  # find the last release of the old code, say v41
heroku rollback v41 -a $BACKEND
heroku releases -a $WEB                                      # same for the web app
heroku rollback <the web app's last old release> -a $WEB
heroku ps:scale web=1 worker=1 -a $BACKEND
heroku maintenance:off -a $BACKEND && heroku maintenance:off -a $WEB
```

Anything written to the new database after the cutover is not in the old one.

## Rehearsing on a copy

This is how it was tested, and costs nothing on Heroku:

```bash
heroku pg:backups:download -a $BACKEND                       # latest.dump
createdb qa_old && createdb qa_new
pg_restore --no-owner --no-acl -d qa_old latest.dump         # needs pg_restore 18 for a Postgres 18 dump
DATABASE_URL=postgres:///qa_new bin/rails db:migrate
DATABASE_URL=postgres:///qa_new LEGACY_DATABASE_URL=postgres:///qa_old bin/rails legacy:import           # dry run
DATABASE_URL=postgres:///qa_new LEGACY_DATABASE_URL=postgres:///qa_old APPLY=1 bin/rails legacy:import
```
