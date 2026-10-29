# Running the whole stack

The QA Agent is three services and a web app: this API (with Sidekiq), `qa-agent-worker`, and `qa-agent-web`. This is how to run them together and check a run end to end.

## 1. Environment

Put these in `qa-agent-backend/.env` (see the README table for what each does). Use fresh random values; never reuse the ones that were in the old `docker-compose.yml`.

- `AGENT_API_TOKEN`: the worker sends it as `X-Agent-Token`. Set the same value in the worker's `AGENT_API_TOKEN`.
- `AGENT_WORKER_BASE_URL`: where the API reaches the worker, for example `http://host.docker.internal:4000` when the API runs in Docker and the worker on the host.
- `AGENT_WORKER_API_TOKEN`: the bearer token the API sends to the worker. Set the same value in the worker's `WORKER_API_TOKEN`.
- `GITHUB_APP_*`, `CLICKUP_API_TOKEN`: only for the GitHub and ClickUp steps.
- `QA_PROBE_TOKEN` (optional): switches the request and job probe on.

The API container must be able to resolve `host.docker.internal`. On Linux add `extra_hosts: ["host.docker.internal:host-gateway"]` to the `web` and `worker` services of your local `docker-compose.yml`.

## 2. Start

```bash
docker compose up                  # API on :3001, Sidekiq, Postgres, Redis
cd ../qa-agent-worker && npm run setup && npm start    # Chromium, then the worker on :4000
cd ../qa-agent-web && npm run dev                      # the web app, VITE_APP_API_URL=http://localhost:3001
```

Seed a super admin with `SUPER_ADMIN_EMAIL=you@example.com SUPER_ADMIN_PASSWORD='Str0ng!pass' bin/rails db:seed`. In development the sign-in code is in `tmp/mails/` or at `/letter_opener`.

## 3. Check a run

1. Sign in, then create a project with a target URL the worker can reach.
2. On the Overview tab choose Connect GitHub, finish on GitHub, pick the repository, then Scan codebase.
3. On Scope features, approve one feature.
4. On Credentials, save a role (for example `admin`) with `{"email":"...","password":"..."}` for the target app.
5. On Runs, dispatch the feature as that role. The row should go queued, then running (the list refreshes by itself), then completed.
6. Open the run: the summary, endpoints and audit log should be filled in. Open Issues: findings appear, each opening to its evidence.

If a run stays `queued`, check Sidekiq (`/sidekiq`, protected with `FLIPPER_UI_USERNAME` and `FLIPPER_UI_PASSWORD`). If it fails straight away, the API could not reach the worker: check `AGENT_WORKER_BASE_URL` and the worker token. A run the worker loses is failed automatically after `Run::STALE_AFTER` by `bin/rails runs:fail_stale`; run it from a scheduler.

The worker's three calls back to the API are described in [agent-contract.md](agent-contract.md).
