# qa-agent-backend

GraphQL API for the `qa-agent-web` frontend. Ruby 4.0, Rails 8.1 (API-only), PostgreSQL, Sidekiq on Redis 7+ for background jobs and cache. Deployed on Heroku.

## Setup

```bash
rbenv install 4.0.7          # or your version manager; see .ruby-version
bundle install
cp .env.example .env         # then fill in DATABASE_USERNAME and DATABASE_PASSWORD (Twilio is optional, see SMS)
bin/rails db:prepare
SUPER_ADMIN_EMAIL=you@example.com SUPER_ADMIN_PASSWORD='Str0ng!pass' bin/rails db:seed
bin/rails server             # http://localhost:3000/graphql
bundle exec sidekiq -C config/sidekiq.yml   # background jobs and mail (Redis 7+)
```

In development, emails (login codes, invitations) are written to `tmp/mails/`. Sidekiq 8 needs Redis 7 or newer; point `REDIS_URL` at one.

## Checks

```bash
bundle exec rspec
bundle exec rubocop
bin/brakeman
bundle exec bundle-audit check --update
bin/rails graphql:schema:idl   # after any API change; commit schema.graphql
```

There is no CI yet; run these before pushing.

## How it fits together

| Concern | Where |
| --- | --- |
| HTTP entry, bearer token → `Session` → `Current` | `app/controllers/graphql_controller.rb` |
| Schema limits and error mapping | `app/graphql/qa_agent_backend_schema.rb`, `app/graphql/graphql_errors.rb` |
| Auth required by default, rate limits, policy context | `app/graphql/concerns/graphql_operation.rb` |
| Operations | `app/graphql/queries/**`, `app/graphql/mutations/**` |
| Business operations (`.call` → `ServiceResult`) | `app/services/**` |
| List filtering | `app/queries/**` |
| Who may do what | `app/policies/**` |
| Email delivery log | `app/mailers/concerns/email_logging.rb` |

## QA Agent domain

A **project** is an app under test. Each project has **memberships** (`member` reads; `admin` also connects integrations, stores credentials, approves scope, scans and runs), a GitHub App **integration** that is scanned into **scope features**, per-role **credentials** (encrypted at rest, write-only through the API), and **runs** of an approved feature as one role. The Playwright worker (`qa-agent-worker`) reports each run's **findings** and result back; findings sharing a fingerprint are one issue, with Sentry-style new/ongoing/regressed/resolved status (`Findings::IssueStats`).

| Concern | Where |
| --- | --- |
| Who may use a project (members read, admins change, super admins both) | `app/policies/project_policy.rb`, `app/graphql/concerns/project_access.rb` |
| Run lifecycle (`queued`, `running`, `blocked`, `completed`, `failed`) | `app/models/run.rb` |
| Dispatching to the worker; stale runs failed every few minutes | `app/services/agent_worker_client.rb`, `RunDispatchJob`, `FailStaleRunsJob` (`bin/rails runs:fail_stale`) |
| GitHub App, repository scan | `app/services/git_hub_*.rb`, `codebase_analyzer.rb`, `app/services/integrations/**` |
| Issue stats, findings list, dashboard | `app/queries/findings/**`, `app/queries/projects/coverage.rb` |
| The worker's three operations (`X-Agent-Token`) | `docs/agent-contract.md`, `GraphqlOperation.agent_only!` |
| Request and job instrumentation for QA runs | `lib/qa_probe/**` (off unless `QA_PROBE_TOKEN` is set) |

Environment (add these to `.env`; production fails to boot without the encryption keys):

| Key | Purpose |
| --- | --- |
| `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT` | Encrypt role credentials. Generate with `bin/rails db:encryption:init`. Development and test fall back to fixed throwaway values. |
| `AGENT_API_TOKEN` | Shared secret the worker sends as `X-Agent-Token` |
| `AGENT_WORKER_BASE_URL`, `AGENT_WORKER_API_TOKEN` | Where runs are dispatched, and the bearer token for it |
| `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_APP_SLUG`, `GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET` | The GitHub App |
| `CLICKUP_API_TOKEN` | Posting findings to ClickUp |
| `QA_PROBE_TOKEN`, `QA_PROBE_ENABLED`, `QA_PROBE_SLOW_SQL_MS`, `QA_PROBE_N_PLUS_ONE_THRESHOLD`, `QA_PROBE_IGNORED_EXCEPTIONS` | The probe |
| `REDISCLOUD_URL` | Heroku Redis Cloud; takes precedence over `REDIS_URL` |

The evidence bucket is the boilerplate's `S3_BUCKET`, and the worker's callback URL is built from `APP_HOST`.

## Roles

- **user**: registers publicly or is invited; manages only their own account.
- **super_admin**: lists and edits every account, reads the email log, invites people (either role), archives users, revokes and restores access, and impersonates regular users for one hour.

## Authentication flow

Every code is 6 digits, valid 10 minutes, 5 wrong attempts, and can be resent 30 seconds after the previous one. `validateOtp` and `resendOtp` take a required `purpose` (`login` or `password_reset`) naming the screen's flow.

1. `registerUser` or `loginUser` (email + password) emails a 6-digit code.
2. `validateOtp` exchanges the code for `token`. Send it as `Authorization: Bearer <token>`.
3. `logout` deletes the session. Changing the password, archiving a user or revoking access also ends that user's sessions.

Password reset: `sendResetPasswordInstructions` → `validateOtp` (returns `resetPasswordToken`, no session) → `setPassword`.
Invitations: `createInvitation` emails `FRONTEND_URL/setup-account?token=…` → `validateInvitationToken` → `acceptInvitation`.
Email change: `requestEmailChange(email, currentPassword)` emails one code to the new address → `confirmEmailChange` switches the email and alerts the old address. `resendEmailChangeCode` sends a fresh code (30 s apart).

## Sign in with Google

The API runs the whole OAuth redirect, so the frontend holds no Google config, not even the client ID:

1. The frontend creates a random `nonce`, keeps it in sessionStorage, and sends the browser to `GET /auth/google?nonce=…`.
2. The API stores the nonce's digest and a PKCE verifier under a random `state` (10 minutes, single use) and redirects to Google.
3. Google redirects to `GET /auth/google/callback`. The API checks the state, exchanges the code (client secret + PKCE) for the profile, requires a verified email, then finds the account by Google uid, else by email (linking it), else creates a `user` with no password (only while `sign_up_enabled` is on). Only a **new** account is filled from Google: first and last name, phone (when it is a valid international number; it can finish onboarding and send the welcome SMS) and the photo (`AttachGooglePictureJob`, Google's image hosts only). Signing in to an existing account never changes its data. `Auth::CompleteGoogleSignIn::NEW_ACCOUNT_FIELDS` is the map; Google's birthday and locale are already read and only need a column and a line there. Archived, revoked and pending-invitation accounts are refused.
4. The browser goes back to `FRONTEND_URL/auth/google/callback#code=…`: a one-time code, valid 1 minute, in the fragment so no server logs it. Failures travel the same way.
5. `signInWithGoogle(code, nonce)` returns `token` and `user`. The nonce must match the browser that started, so a forwarded link can't sign someone else in. No emailed code follows: Google verified the email.

The `state` and the one-time code live in the Redis cache. Create a Google OAuth client (type *Web application*) with `GOOGLE_REDIRECT_URI` (default `http://localhost:3000/auth/google/callback`) as an authorized redirect URI, then set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`. Without them, Google sign-in reports `GOOGLE_SIGN_IN_DISABLED`. Phone and birthday come from Google's People API: enable it in the Cloud project and add the `user.phonenumbers.read` and `user.birthday.read` scopes under Data Access. Google treats them as sensitive, so outside test users they need Google's app verification, and Google shares only a profile contact phone (never the sign-in or recovery phone). They are off by default; `GOOGLE_PEOPLE_DETAILS=true` turns them on. Turn on `google_sign_in_enabled` in the dashboard to offer the button.

## Onboarding

Users who sign up or are invited onboard in order: step 1 `step1` (first and last name), then step 2 `step2` (phone). Every `User` carries `onboarding { required completed currentStep steps { step position completed missingFields } }`, so `fetchUser` and the user returned at sign-in tell the client where to go: `currentStep` is the first incomplete step (null when done). Steps are saved with `updateUser` (`firstName`, `lastName`, `phone`; phone must include its country code and is validated with Phonelib, then stored in E.164 like `+12015550123`). Super admins don't onboard (`required: false`). Steps are declared in `User::ONBOARDING_STEPS`.

## SMS (Twilio)

Every SMS gets an `SmsLog` row and is sent by `SmsDeliveryJob` through Twilio (`Sms::TwilioSender`). The log stores what Twilio answered, not delivery to the phone (there are no Twilio callbacks): `pending` until handed over, then Twilio's own status, `queued` (or `accepted` through a Messaging Service) with its message SID and time, or `failed` with Twilio's error code and message. Twilio outages, rate limits and timeouts retry (5 attempts, then `failed`); a refusal such as an invalid or opted-out number fails at once, with Twilio's error code and a readable message.

A welcome SMS is sent once, when a user completes onboarding (a unique index guarantees one per user). Super admins read the logs with `allSmsLogs` and `fetchSmsLog`. SMS always go through Twilio; without credentials they are recorded as failed ("Twilio is not configured"). The test suite never reaches Twilio: it uses fixed test credentials and WebMock answers Twilio's API. Logs older than 90 days are deleted by `bin/rails sms_logs:purge_expired`.

SMS is **opt-in** in QA Agent. It stays off until `sms_enabled` is switched on for a user or role, and the phone onboarding step (`step2`) only exists for users who have it on. Production only requires Twilio at boot when `SMS_ENABLED=true`.

To use it, set `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM_NUMBER` (or `TWILIO_MESSAGING_SERVICE_SID`); restart the API and Sidekiq after changing them. In development use Twilio's **test** credentials with `TWILIO_FROM_NUMBER=+15005550006`: real API answers, nothing is sent or charged; magic recipients such as `+15005550001` (invalid number, 21211) or `+15005550004` (opted out, 21610) produce failures.

## Email logs

Every email gets one `EmailLog` row (recipient, mailer, subject, body, status, error, attempts); Sidekiq retries update that row, so it always shows the latest outcome. Super admins read them with `allEmailLogs` and `fetchEmailLog`. Bodies are stored as sent, including sign-in codes and invitation links, so access is limited to super admins. A failed attempt is recorded and re-raised so Sidekiq retries it. Logs older than 90 days (`EmailLog::RETENTION`) are deleted by `bin/rails email_logs:purge_expired`, which only runs when scheduled or run by hand.

## Feature flags

Flags live in Flipper (Redis) and are managed in the dashboard at `/flipper`. Each flag can be switched on for everyone (Boolean), for a role (Groups: `users`, `super_admins`, one per `User.role`), or for one user (Actors: `User;<id>`). A flag is off for anyone it isn't switched on for.

| Flag | Checked against | On | Off |
| --- | --- | --- | --- |
| `sign_up_enabled` | the role signing up (`user`) | `registerUser` works | `SIGN_UP_DISABLED` |
| `otp_enabled` | the user signing in or up | an emailed code, then `validateOtp` | `token` returned at once |
| `email_change_otp_enabled` | the user changing email | code to the new address | changed at once, old address notified |
| `invitations_enabled` | the role being invited | `createInvitation` allowed | `FORBIDDEN` |
| `impersonation_enabled` | the user being impersonated | `impersonateUser` allowed (super admins only) | `FORBIDDEN` |
| `google_sign_in_enabled` | the user signing in (or the role sign-up creates) | Sign in with Google works | `GOOGLE_SIGN_IN_DISABLED` |
| `sms_enabled` | the user being texted | the welcome SMS is sent through Twilio and logged | nothing sent, nothing logged |

`sign_up_enabled`, `invitations_enabled` and `impersonation_enabled` never apply to `super_admin`, even when fully on (`FeatureFlag::NEVER_FOR_ROLES`): nobody signs up as, is invited as, or is impersonated as a super admin. The dashboard doesn't offer the `super_admins` group for those flags, and refuses (with a message) a super admin added as an actor; the same guard (`FeatureFlag::EligibleTargetsAdapter`) covers the console.

Every `User` carries its flags as `featureFlags` (booleans, resolved for that user and role), so `fetchUser`, `validateOtp`, `loginUser` and `registerUser` hand the client its flags with the user. Signed-out pages, which have no user, use `fetchPublicFeatureFlags`: the only query that needs no sign-in, and it returns just `signUpEnabled`, `otpEnabled` and `googleSignInEnabled` for the role public sign-up creates (the server picks it; it takes no role). Every other flag needs sign-in: `User.featureFlags`, or `fetchFeatureFlags(role:)` to ask about a role (e.g. whether users of it can be invited). The list and the checks are in `FeatureFlag` (`app/models/feature_flag.rb`); `bin/rails feature_flags:register` adds new flags to the dashboard: `bin/setup` runs it locally and the Heroku release phase on deploy; on any other host, run it after migrations in the deploy step, or new flags won't appear in `/flipper`. Every flag change is logged (`[feature flag] enable sms_enabled (groups=users)`) with what changed and when; the dashboard's shared login means it can't say who. Flipper memoizes flags per request, so a users list reads them from Redis once, not once per row.

## Operations

Queries: `fetchUser`, `allUsers`, `validateInvitationToken`, `allEmailLogs`, `fetchEmailLog`, `allSmsLogs`, `fetchSmsLog`, `fetchFeatureFlags`, `fetchPublicFeatureFlags`.

Mutations: `registerUser`, `loginUser`, `validateOtp`, `signInWithGoogle`, `resendOtp`, `sendResetPasswordInstructions`, `setPassword`, `acceptInvitation`, `logout`, `impersonateUser`, `requestEmailChange`, `resendEmailChangeCode`, `confirmEmailChange`, `updateUser`, `updatePassword`, `archiveUser`, `updateUserAccess`, `createInvitation`, `resendInvitation`, `deleteInvitation`.

Full contract: [`schema.graphql`](schema.graphql).

Every error carries `extensions.code`: `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION_FAILED` (the message lists what's wrong), `ACCESS_REVOKED`, `INVALID_CREDENTIALS`, `INVALID_CODE`, `INVALID_TOKEN`, `RATE_LIMITED`, `SIGN_UP_DISABLED`, `GOOGLE_SIGN_IN_DISABLED`, `GOOGLE_SIGN_IN_FAILED`, `BAD_REQUEST`, `INTERNAL_SERVER_ERROR`.

## Deploying to Heroku

```bash
heroku create your-app-name
heroku addons:create heroku-postgresql
heroku addons:create heroku-redis          # Redis 7+
heroku addons:create scheduler
heroku config:set \
  RAILS_MASTER_KEY="$(cat config/master.key)" \
  APP_HOST=your-app-name.herokuapp.com ALLOWED_HOSTS=your-app-name.herokuapp.com \
  FRONTEND_URL=https://app.example.com CORS_ALLOWED_ORIGINS=https://app.example.com \
  REDIS_SSL_VERIFY_NONE=true \
  S3_BUCKET=... AWS_REGION=... AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
  SMTP_ADDRESS=... SMTP_USERNAME=... SMTP_PASSWORD=... MAILER_SENDER=no-reply@example.com \
  FLIPPER_UI_USERNAME=... FLIPPER_UI_PASSWORD=... \
  TWILIO_ACCOUNT_SID=... TWILIO_AUTH_TOKEN=... TWILIO_FROM_NUMBER=+1... \
  GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... GOOGLE_REDIRECT_URI=https://your-app-name.herokuapp.com/auth/google/callback \
  WEB_CONCURRENCY=2 RAILS_MAX_THREADS=5
git push heroku main                       # the release phase migrates and registers feature flags
heroku ps:scale web=1 worker=1
heroku run 'SUPER_ADMIN_EMAIL=you@example.com SUPER_ADMIN_PASSWORD=... bin/rails db:seed'
```

- `Procfile`: `release` migrates and registers feature flags, `web` runs Puma, `worker` runs Sidekiq. Scale the worker to at least 1, or mail is never sent.
- Heroku sets `DATABASE_URL`, `REDIS_URL` and `PORT`. Set `REDIS_SSL_VERIFY_NONE=true`, because Heroku Redis uses a self-signed TLS certificate. Production refuses to boot without `APP_HOST`, `FRONTEND_URL`, `CORS_ALLOWED_ORIGINS`, `FLIPPER_UI_USERNAME` and `FLIPPER_UI_PASSWORD`. With `SMS_ENABLED=true` it also needs `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM_NUMBER` or `TWILIO_MESSAGING_SERVICE_SID`.
- S3: create a dedicated IAM user that can only `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on this one private bucket.
- Heroku Scheduler: run `bin/rails auth:purge_expired_credentials`, `bin/rails email_logs:purge_expired` and `bin/rails sms_logs:purge_expired` daily.
- Optional: `SENTRY_DSN` turns on error reporting (no personal data is sent).
