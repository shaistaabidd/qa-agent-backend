# qa-agent-backend

GraphQL API for the QA Agent: projects, GitHub-scanned scope features, role credentials, runs and findings. It is built on the `saas-api` boilerplate (auth, policies, services, jobs), with the QA domain on top. The web client is `qa-agent-web`; runs execute in `qa-agent-worker` over HTTP.

## Conventions (inherited from the boilerplate)

- Ruby 4.0, Rails 8.1 API-only, PostgreSQL, Sidekiq 8 on Redis 7+ (jobs and cache). No Devise or JWT: sessions are opaque bearer tokens (`Session`).
- Business logic is a service: `Foo::Bar.call(...)` returns a `ServiceResult`. New failure codes go in `ServiceError::CODES` with an `errors.<code>` message in `config/locales/en.yml`.
- Operations extend `Mutations::BaseMutation` or `Queries::BaseQuery`; auth is required unless `allow_unauthenticated!`. Authorize with Action Policy (`authorize!`, `authorized_scope`).
- Lists use Pagy through `Paginatable` and a `PaginatedFilterInput`.
- Specs run the real schema with `execute_graphql(query, as: user)`; WebMock blocks the network, so stub every outbound call.
- After any API change run `bin/rails graphql:schema:idl` and commit `schema.graphql`; the web reads it.

## Agent contract: do not change

`qa-agent-worker` calls `receiveRunResult`, `createFinding` and `resolveRoleCredential` with `X-Agent-Token`. Their names, arguments, input type names and enum values are frozen. See `docs/agent-contract.md`.

## Checks (run before committing)

```bash
bundle exec rspec
bundle exec rubocop
bin/brakeman
```

There is no Ruby on the host in some setups; use `docker compose run --rm web <command>` with `RAILS_ENV=test` and a test `DATABASE_URL` for specs.

## Git

Branches `feature/*`, `fix/*`, `chore/*`. Commit messages are one line, Conventional Commits (`type: summary`), with no body and no AI-attribution trailer.
