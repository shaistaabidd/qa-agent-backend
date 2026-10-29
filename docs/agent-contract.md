# Agent contract (frozen)

`qa-agent-worker` is a separate service. It receives dispatched runs over HTTP and reports back through this API's GraphQL endpoint. Changing anything below breaks the worker, so it stays byte-compatible. The worker only depends on what is listed here: it treats any entry in `errors` as a failure and logs the `message`, and it does not read error codes (errors carry `extensions.code`, for example `UNAUTHENTICATED` or `RUN_NOT_ACTIVE`).

## Backend to worker: `POST {AGENT_WORKER_BASE_URL}/runs`

Headers: `Authorization: Bearer {AGENT_WORKER_API_TOKEN}`, `Content-Type: application/json`. Built by `AgentWorkerClient`.

```json
{
  "run_id": 1,
  "target_url": "https://app.example.com",
  "role_name": "admin",
  "scope_feature": { "name": "Checkout", "route": "/checkout" },
  "callback_url": "{scheme}://{APP_HOST}/graphql",
  "credential_fetch_token": "<opaque signed token, valid 1 hour>"
}
```

The raw credential never travels in this payload. The worker exchanges `credential_fetch_token` for it with `resolveRoleCredential`.

## Worker to backend: `POST {callback_url}` (GraphQL)

Every request carries `X-Agent-Token: {AGENT_API_TOKEN}`, checked with a constant-time compare. User bearer tokens are not accepted on these operations, and the agent token never authenticates a user.

| Operation | Shape the worker sends | Selection the worker reads |
| --- | --- | --- |
| `resolveRoleCredential` (query) | `resolveRoleCredential(token: String!)` | the returned `String` |
| `createFinding` (mutation) | `input: CreateFindingInput!` with `runId`, `title`, `reproSteps` ([String]), `severity` (upper case enum: `LOW MEDIUM HIGH CRITICAL`), optional `category`, `details` (JSON), `fingerprint`, `screenshot` (multipart `Upload`, `variables.input.screenshot`) | `finding { id }` |
| `receiveRunResult` (mutation) | `input: ReceiveResultInput!` with `runId`, `status` (upper case `RunResultStatusEnum`, for example `COMPLETED`), optional `auditLogEntries` (`[{ actionTaken, targetElement }]`), `networkLog` (JSON), `summary` (JSON) | `run { id status }` |

Keep these input type names (`CreateFindingInput`, `ReceiveResultInput`): they come from the mutation class names `Findings::CreateFinding` and `Runs::ReceiveResult` under the Relay classic naming rule.

## Behaviour the specs pin down

- `resolveRoleCredential` and both mutations reject a missing or wrong agent token (`UNAUTHENTICATED`), including a valid user session.
- `resolveRoleCredential` refuses a run that is not `running`.
- `createFinding` rejects a duplicate title within the same run.
- `createFinding` with a screenshot attaches it and enqueues the ClickUp post job.
- `receiveRunResult` records the audit log entries and moves the run to the reported status.

`spec/graphql/agent_contract_spec.rb` and `spec/requests/agent_contract_spec.rb` replay these cases with the worker's own documents (the second over HTTP, including the multipart upload) and must keep passing.
