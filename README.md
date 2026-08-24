# Mina Bekhit — Cloud Operations & Infrastructure

I run self-hosted systems and keep them running. The projects below are built on n8n, and what they
demonstrate is the operating side underneath: Docker, PostgreSQL, encrypted secrets, off-site backups
I have restored from, a migration between hosts, and alerting when something fails.

**Location:** Egypt — open to remote worldwide.
**Contact:** menafbk@gmail.com · [LinkedIn](https://www.linkedin.com/in/minafbk/)

---

## Portfolio projects

### 1. [Self-hosted n8n platform](./self-hosted-n8n-platform/) — the infrastructure piece
A self-hosted **n8n + PostgreSQL** stack on Docker, live over HTTPS through a **Cloudflare Tunnel** with nothing inbound open and no static IP. Secrets held in an encryption key and a gitignored `.env`, daily off-site backups to Google Drive with `rclone`, and a disaster-recovery restore verified by rebuilding both volumes as a working twin. I later moved the whole instance **from Windows to Linux** using the migration runbook, without losing a credential.

`Docker` · `PostgreSQL` · `Linux` · `Cloudflare Tunnel` · `rclone` · `secret management` · `disaster recovery` · `host migration`

### 2. [Slack failure-alerter](./slack-alerter/) — monitoring for the workflows above
An n8n Error Trigger and HTTP webhook that catches any failed workflow and posts the workflow name, the node that broke, and the error message to a Slack channel. Small piece of plumbing that closes the gap between a job breaking and me finding out.

`n8n` · `Error Trigger` · `webhooks` · `Slack API`

### 3. [Invoice extraction pipeline](./invoice-extractor/) — validation around an LLM
Upload a document, **Gemini** extracts the fields, then five checks validate the JSON, the field types, and that subtotal plus tax reconciles to the stated total within one cent. Failures land in a **review queue** with the reasons attached and a Slack notice. Retries handle transient API failures; validation handles output that is well-formed but wrong. Two different problems, two different tools.

`n8n` · `Google Gemini` · `PostgreSQL` · `JSON schema validation` · `error handling`

### 4. Automated currency sync & billing — a pipeline before n8n
A `systemd`-scheduled Python pipeline that pulls FX rates from an API and logs customer usage events, plus a billing module that renders those records into utility-style PDF invoices with ReportLab.

`Python` · `PostgreSQL` · `Linux` · `systemd` · `REST APIs`

---

## Stack

- **Linux & systems:** Linux, systemd, Bash, log and network debugging
- **Infrastructure:** Docker, Docker Compose, PostgreSQL, Cloudflare Tunnel, rclone
- **AWS:** VPC networking — subnets, route tables, security groups, NACLs, NAT gateways
- **Reliability:** secret management, scheduled off-site backups, disaster recovery, host migration, failure alerting
- **Automation:** n8n (self-hosted), webhooks, HTTP/REST integration
- **Languages:** Python, Bash, SQL, YAML
