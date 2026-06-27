# n8n → Slack Failure Alerter

A reusable n8n error-handler workflow. Point any workflow's **Error Workflow** setting at it, and
when that workflow fails in production it posts a formatted alert to a Slack `#alerts` channel —
with the failed workflow's name, the node that broke, and the actual error message.

Built and run end-to-end on my own self-hosted n8n stack (Docker + PostgreSQL, WSL2), **June 2026**.

---

## The problem it solves

Automations are built to run **without supervision** — that's the whole point of them. Which is
exactly what makes a silent failure dangerous: when something breaks and nothing tells you, it just
keeps failing, unnoticed. Think of a web app quietly dropping orders in the background — that's real
losses piling up, and you don't even know *why* until someone happens to notice.

So building a reliable system means knowing its limits up front: what can fail, and which failures
actually matter. A few transient hiccups — a brief timeout, a blip — fix themselves on a retry and
aren't worth alerting on. The failures you want to *know* about are the real ones: something broke
and **couldn't recover on its own**. This workflow is that trigger — when a monitored workflow fails
for real, it pings a human in Slack with the workflow name, the node that broke, and the error, so
the gap between *it broke* and *I found out* closes fast.

---

## Architecture

```
┌──────────────────┐   a monitored workflow         ┌──────────────────┐     POST {text}      ┌─────────────┐
│  Error Trigger   │ ─ fails in production ──▶       │  HTTP Request    │  ───────────────▶    │   Slack     │
│ (this workflow = │   (retries exhausted /          │ (POST to Slack   │   JSON body          │  #alerts    │
│  the handler)    │   no error-output branch)       │  incoming webhook)│                      │  channel    │
└──────────────────┘                                 └──────────────────┘                      └─────────────┘
```

Two nodes. The value isn't node count — it's that it's a **reusable, centralized error handler**
that other workflows point at (n8n's per-workflow Error Workflow setting), secret-safe, and it
actually fires on real failures.

---

## How it works

1. **Error Trigger** — n8n's built-in node that fires when a workflow pointing at this one fails.
   You assign it **per workflow** (Settings → Error Workflow); n8n has no native instance-wide
   default, so one centralized alerter gets reused across whichever workflows you want monitored.
2. **HTTP Request (POST)** — sends a JSON body to a Slack incoming webhook. The message text is built
   from the error payload n8n hands the trigger:
   - `$json.workflow.name` — which workflow failed
   - `$json.execution.lastNodeExecuted` — which node it died on
   - `$json.execution.error.message` — the actual error

Example alert in Slack:

> 🚨 *Workflow failed:* `Break test`
> Node: `Code`
> Error: `Intentional failure for alert test`

### Proven against a real failure

To prove it actually fires (not just "looks right in the editor"), I built a throwaway `Break test`
workflow — Schedule Trigger every 1 minute → Code node that `throw`s — published it, and watched a
**real production failure auto-alert to `#alerts`** with the correct workflow name, node, and error.

---

## Secret handling (the part that matters)

The Slack webhook URL never touches the workflow JSON or git. It rides three hops:

```
.env (gitignored, backed up off-site)  →  ${SLACK_WEBHOOK_URL} in docker-compose  →  $env.SLACK_WEBHOOK_URL in the node
```

So the exported `workflow.json` in this folder is safe to publish — there is no secret in it. The
webhook lives only in the `.env` on the instance (and in the Google Drive backup).

**Design reasoning:** a secret *URL* has no n8n credential type, so it belongs in an **environment
variable**, not a "credential." n8n credentials are for auth tokens/headers; env vars are for config
secrets like a webhook URL.

---

## Debugging stories (what actually went wrong)

These are the real failures I diagnosed building this — the engineering, not the happy path.

1. **`$env` returned `access denied`.** `$env.SLACK_WEBHOOK_URL` came back as
   `[ERROR: access to env vars denied]`. Traced it to **n8n v2.0 flipping
   `N8N_BLOCK_ENV_ACCESS_IN_NODE` to default-`true`** (checked the n8n docs, didn't guess). Fixed by
   setting it `false` in compose. Understood the trade-off: this exposes *all* env vars to any
   workflow expression — acceptable on a single-operator instance, a real risk on a multi-user one.
   Also learned a UI quirk: the editor preview still shows the error, but the **runtime reads it
   fine** — trust the execution, not the preview.

2. **Slack returned `invalid_payload` (HTTP 400).** Key insight: that's a reply *from Slack*, so the
   request reached it and the URL resolved — the **body** was the problem, not reachability. An empty
   / Raw body → fixed by sending a proper JSON body with a `text` field. Reachability-vs-bad-payload
   is the status-code reasoning that makes integration debugging fast.

3. **The alert wouldn't fire on test runs.** Error workflows only fire on **published + production**
   executions, never on manual test runs — and unpublished workflows grey out in the Error Workflow
   picker ("not published, can be used for manual testing"). Fixed by **publishing** the alerter.
   This is the single most important gotcha with n8n error handling and it's not obvious.

---

## What I learned

- n8n's **Error Trigger** is a *reusable* handler, but it's assigned **per workflow** (no native
  instance-wide default) — one alerter workflow, pointed at from each workflow's settings.
- Version-default changes (`N8N_BLOCK_ENV_ACCESS_IN_NODE`) can silently break expressions; read the
  changelog, don't assume your config is wrong.
- HTTP status codes tell you *where* the problem is (reachability vs body vs auth) before you touch
  the payload.
- "Published + production" is a hard requirement for error workflows — test-run success means nothing.

## What I'd do differently / next (v2)

- **Bot token instead of webhook** — move from an incoming webhook to a Slack bot token in an n8n
  **encrypted credential** (`chat:write`), so the secret is managed by n8n's credential system and the
  message can be richer (Block Kit formatting, threads).
- **Retry On Fail on the send** — if Slack itself is briefly down, the alert about a failure
  shouldn't fail silently.
- **Severity routing** — different channels / @-mentions based on which workflow failed.

---

## Stack

- **n8n** v2.21.7 (self-hosted, pinned)
- **Docker Compose** — n8n + **PostgreSQL** backend (not the SQLite default)
- **Linux / WSL2**, off-site backups to Google Drive via rclone
- **Slack** incoming webhook
- Secrets: `.env` + gitignore, env-var injection through compose

## Cost

$0. Runs on the existing self-hosted instance; Slack incoming webhooks are free.

---

## Files in this folder

- `workflow.json` — the exported n8n workflow (import it into any n8n instance to inspect/run)
- `screenshots/` — Slack alert + the n8n editor view
- `architecture.png` — diagram (optional; the ASCII version above covers it)

## To reproduce

1. Create a Slack incoming webhook for your channel; put the URL in `.env` as `SLACK_WEBHOOK_URL`.
2. Inject it through compose: `SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}` in the n8n service environment.
3. Set `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` (n8n v2.0+) so expressions can read `$env`.
4. Import `workflow.json` and **publish** it. Then on each workflow you want monitored, set
   Settings → **Error Workflow** → `Failure Alerts`. (No native global default; a community
   "watchdog" workflow can backfill it across all workflows.)
5. Trigger any failing workflow → watch the alert land in Slack.
