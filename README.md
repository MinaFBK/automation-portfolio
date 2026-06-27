# Mina Bekhit — Automation & Integration Engineer

I build automations that hold up in production — not demos that fall over the first time an API returns something unexpected. My focus is **self-hosted n8n** with the engineering most no-code people skip: Docker, PostgreSQL, secret management, tested disaster recovery, and reliability layers around AI.

**Location:** Egypt — open to remote worldwide.
**Contact:** menafbk@gmail.com · [LinkedIn](https://www.linkedin.com/in/minafbk/)
**Résumé:** [📄 Download CV (PDF)](./Mina-Bekhit-CV.pdf)

---

## Portfolio projects

### 1. [AI Invoice-Extraction Pipeline](./invoice-extractor/) — reliable AI, not a party trick
Upload an invoice → **Gemini** reads it → but the system **refuses to trust the output**. Every extraction is validated (types, and whether subtotal + tax reconciles to the total within a cent), valid rows go to **Postgres**, and anything suspect is routed to a **human review queue** with the reasons attached instead of being silently saved wrong. Retries handle flaky API calls; validation handles confidently-wrong output — two different problems, two different tools.

`n8n` · `Google Gemini` · `LLM integration` · `PostgreSQL` · `JSON schema validation` · `error handling`

### 2. [Self-hosted n8n platform](./self-hosted-n8n-platform/) — production-shaped infrastructure
A self-hosted n8n stack, not a one-click cloud signup. **Docker Compose + PostgreSQL**, encrypted secrets in a gitignored `.env`, nightly off-site backups to Google Drive (`rclone`), and a **disaster recovery I actually tested** by restoring into a fresh twin instance. Live over **HTTPS via a Cloudflare Tunnel** — no open ports, no static IP. Includes a documented migration runbook across hosts and a [Slack failure-alerter](./slack-alerter/) as production monitoring.

`Docker` · `PostgreSQL` · `Linux` · `Cloudflare Tunnel` · `rclone` · `secret management` · `disaster recovery`

### 3. [Slack failure-alerter](./slack-alerter/) — production monitoring for workflows
An n8n Error Trigger → HTTP webhook flow that catches any failed workflow and posts the workflow name, failing node, and error message to Slack. Small, but it's the difference between "a job silently broke" and "I knew within a minute."

`n8n` · `Error Trigger` · `webhooks` · `Slack API`

### 4. Automated Currency Sync & Billing System — a pipeline before n8n
A `systemd`-scheduled Python pipeline that pulls FX rates from an API and securely logs customer usage events, plus a billing module that generates utility-style PDF invoices from relational records (ReportLab). Same instinct as my n8n work — automate the dull, error-prone data flow and produce something a business can actually use.

`Python` · `PostgreSQL` · `Linux` · `systemd` · `REST APIs`

---

## Stack

- **Automation:** n8n (self-hosted), webhooks, HTTP/REST integration
- **Infra:** Docker, Docker Compose, PostgreSQL, Linux, Cloudflare Tunnel, rclone
- **AI:** LLM integration (Gemini), structured output + validation, prompt design
- **Languages:** Python (read + modify), Bash, SQL, YAML
- **Ops:** `.env`/secret management, scheduled backups, restore/migration runbooks, Git
