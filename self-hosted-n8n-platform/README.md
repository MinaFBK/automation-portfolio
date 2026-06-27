# Self-Hosted n8n Automation Platform

A production-shaped, self-hosted **n8n + PostgreSQL** stack I run on Docker, **live at a public HTTPS
URL: [`https://n8n.minafbk.com`](https://n8n.minafbk.com)** — fronted by a Cloudflare Tunnel with real
TLS and **no open inbound ports**. Secrets managed through an encryption key and `.env`, off-site
backups to Google Drive, **disaster recovery proven by restoring into a twin**, and a migration
runbook I've now *executed* — the same licensed instance moved across hosts without losing a single
credential.

Built and run on my own machine (Docker on Linux), **2026**. This is the infrastructure piece — the
part that separates "I can self-host and operate n8n" from "I know the n8n UI."

> **Honest availability note:** the URL is genuinely live — public DNS, valid TLS, reachable from
> anywhere. But it's **laptop-hosted**, so it's up when my machine is on, **not 24/7** — a deliberate
> $0 choice, not a broken deploy. The same domain and the migration runbook below move it to an
> always-on VPS the day that's worth paying for. I'd rather state the trade-off than overclaim a
> 24/7 SLA I'm not running.

---

## Why self-hosted (the problem it solves)

n8n offers one-click cloud hosting. Choosing to self-host instead *is* the point. The hosted UI is
the easy 10%; the operating side — keeping the instance persistent, secret-safe, backed up, and
recoverable across machines — is the 90% where the real engineering lives, and it's what businesses
actually pay someone to own.

A junior automation listing I'm targeting asks, almost word for word, to *"install and configure n8n
self-hosted with authentication and HTTPS, set up credential management and environment variables for
all APIs."* That is this stack. Most applicants who "know n8n" only know the hosted dashboard — so
the operating skills below are the edge, not an afterthought.

---

## Architecture

```
                                              Host: LMDE 7 (Linux native), Docker Engine
  internet visitor                ┌──────────────────────────────────────────────────────────┐
        │                         │                                                            │
        ▼                         │   cloudflared           Docker Compose project             │
  https://n8n.minafbk.com         │  (systemd service)                                         │
        │                         │   ┌──────────┐      ┌────────────────┐   ┌──────────────┐ │
        ▼                         │   │  tunnel  │ ───▶ │      n8n        │ ─▶│  PostgreSQL  │ │
  Cloudflare edge ──┐             │   │ connector│ HTTP │ n8nio/n8n:2.21.7│DB │ postgres:16  │ │
  (TLS terminates,  │  outbound   │   └────▲─────┘ :5678│  (host-only)    │   │(no pub. port)│ │
   reverse proxy)   └─────────────┼────────┘            └───────┬────────┘   └──────┬───────┘ │
        ▲      ▲                  │   ↑ tunnel dials OUT          │ vol               │ vol     │
        │      └── DNS: n8n.minafbk.com → Cloudflare         [n8n_data]          [pg_data]     │
   (admin on LAN → 127.0.0.1:5678 direct)                                  named volumes        │
                                  └──────────────────────────────┼──────────────────┼──────────┘
                                                                 └─────────┬─────────┘
                                                                           ▼
                                                          backup.sh  (tar both volumes)
                                                                           ▼
                                              rclone ──▶ Google Drive  (off-site, daily via cron)
```

Two app containers, named volumes for all state, and the n8n UI still bound to `127.0.0.1` only —
**nothing inbound is opened on the host.** Public reach comes from `cloudflared`, a separate process
that dials **outbound** to Cloudflare and holds the line open; Cloudflare's edge terminates TLS and
forwards requests back down that tunnel to `localhost:5678`. Postgres has **no published port at
all** — reachable only by n8n over the Compose network. The off-site backup runs daily via cron.

---

## Live HTTPS deployment (Cloudflare Tunnel)

The instance is reachable at **[`https://n8n.minafbk.com`](https://n8n.minafbk.com)** — real,
edge-terminated TLS (cert by Google Trust Services, auto-renewing), reachable from any machine. Three
separate things make that work, and the value is in keeping them distinct:

- **The domain** (`minafbk.com`) — a name in global DNS, bought once via Cloudflare Registrar (1 yr,
  **auto-renew off** on purpose). A DNS record points `n8n.minafbk.com` at Cloudflare.
- **`cloudflared`** — a small program on the host, run as a **persistent `systemd` service** (enabled
  + active, survives reboot). It dials **outbound** to Cloudflare and holds that connection open;
  ingress rules in `/etc/cloudflared/config.yml` forward tunneled requests to `localhost:5678`.
- **Cloudflare's edge** — the public front door. It terminates HTTPS and reverse-proxies each request
  down the open tunnel to the origin.

**Why a tunnel instead of port-forwarding** (the obvious alternative — open a router port, point the
domain at my home IP, run Caddy for TLS):

- **The firewall stays closed.** Nothing inbound is exposed; port-forwarding opens the machine to
  internet scanners. The tunnel's only connection is outbound.
- **No static/public IP needed.** Home IPs change, and many ISPs use CGNAT (no real public IP at
  all), which *breaks* port-forwarding outright. An outbound tunnel doesn't care.
- **Free automatic HTTPS.** TLS terminates at Cloudflare's edge — no certificates for me to issue or
  renew.

**Is it a reverse proxy?** Yes — with a twist. A classic reverse proxy (Nginx, Caddy, Traefik) reaches
*inward* to the origin and so needs a reachable IP/port. Here the origin dials *outward* to the proxy.
Same job — terminate TLS, forward to the backend — opposite connection direction, and that direction
is exactly what removes the need for open ports or a static IP. **This replaced the Caddy reverse
proxy** that was the original HTTPS plan: same outcome, simpler, and safer for a home host.

**What n8n needed to know** to run correctly behind a public hostname (set in Compose via `.env`, so
the same file is host-agnostic) — otherwise logins, links, and webhook URLs break:

```yaml
N8N_HOST: n8n.minafbk.com          # the hostname it serves under
N8N_PROTOCOL: https                # generates https:// links + sets secure login cookies
WEBHOOK_URL: https://n8n.minafbk.com/        # public base handed to external services
N8N_EDITOR_BASE_URL: https://n8n.minafbk.com/  # keeps editor/OAuth-callback links on the public host
```

**Honest trade-off:** the host is a laptop, so the URL is up while the machine is on, not 24/7. That's
the deliberate $0 choice — a tunnel on owned hardware beats paying for a VPS while I'm learning. The
documented upgrade is a low-cost always-on VPS; the **same domain, same Compose, same encryption key,
and the migration runbook below all carry over unchanged.** Optional second auth layer (Cloudflare
Access in front of the URL) is noted in the [Roadmap](#roadmap).

---

## Key design decisions (and why)

Each of these is a deliberate choice, not a default:

- **PostgreSQL, not the SQLite default.** SQLite works until it doesn't; migrating SQLite → Postgres
  later is painful. Paying one extra container on day one buys a real production DB forever.
- **Named volumes** (`n8n_data`, `pg_data`) instead of bind mounts — bind mounts have
  file-permission quirks on Windows/WSL2; named volumes avoid them and keep state off the container.
- **Healthcheck + `depends_on: condition: service_healthy`** — fixes the classic start-vs-ready race
  where n8n boots before Postgres is *accepting connections* (not just *started*).
- **Host-only port publish** (`127.0.0.1:5678`) — the UI isn't exposed even to the local network, and
  the DB isn't published at all. Public reach is added *only* through the outbound Cloudflare Tunnel
  (above), never by opening a port. Nothing is reachable that doesn't need to be.
- **Pinned image** (`n8nio/n8n:2.21.7`) — reproducible boots, no surprise breaking upgrade. Pinned
  *after* the first stable boot, not before.
- **`restart: unless-stopped`** — survives reboots and crashes without coming back from a manual stop.

Sanitized Compose excerpt (full deployable config lives in a private repo — see [Files](#files)):

```yaml
services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}   # from .env, never in git
      POSTGRES_DB: n8n
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 5s
      timeout: 5s
      retries: 10

  n8n:
    image: n8nio/n8n:2.21.7
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}  # load-bearing — see Secrets
      GENERIC_TIMEZONE: Africa/Cairo
    ports:
      - "127.0.0.1:5678:5678"                    # host-only
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
  pg_data:
```

---

## Secret management

Nothing secret is ever committed. Secrets live in a **gitignored `.env`**, referenced from Compose
via `${VAR}` substitution; a committed **`.env.example`** documents the shape without the values.

The load-bearing secret is **`N8N_ENCRYPTION_KEY`** (`openssl rand -hex 32`). It encrypts every
stored credential in the database. The rules I operate by:

- **Never rotate it.** Changing or losing it makes every stored credential undecryptable — the
  instance is effectively dead.
- **Keep a copy off the machine** (password manager) so a dead disk doesn't mean a dead instance.
- It rides every backup and every migration *unchanged* — that's what makes the instance portable.

| In git (the *record*) | Never in git (the *secrets*) |
|---|---|
| `docker-compose.yml`, `.env.example`, workflow JSON exports, notes | the real `.env` (encryption key + DB password), volume tarballs |

---

## Backups & disaster recovery

**Off-site from day one**, not deferred to "production later."

- `backup.sh` tars both volumes → **rclone → Google Drive** (`n8n-backups/`, scope locked to
  `drive.file` so the token can't touch the rest of my Drive).
- **Daily automated** via **cron** (14:00 on the Linux host), verified end-to-end.
- Date-stamped filenames; retention = last 7 dailies + 4 weeklies.
- Images are **not** backed up — they re-pull from Docker Hub on restore. Only state travels.

### Disaster recovery — proven, not assumed

A backup that's never been restored isn't a backup. To prove mine actually rebuild the instance, I
restored from the Google Drive backup into an **isolated twin on different ports** — workflows and
credentials **decrypted cleanly** and the license stayed intact, then I tore the twin down (one
license, one instance). The backup alone can recreate the whole platform.

---

## Portability — migrate the *same* instance across hosts (done, not theoretical)

The instance is designed to move, and **I've now moved it for real.** The same Compose file, the same
volumes (restored from backup), and the same encryption key reproduce the same instance on a new host.
The runbook:

1. `docker compose down` on the source.
2. Tar both volumes.
3. Copy `docker-compose.yml`, `.env`, and both tarballs to the target.
4. Scaffold empty volumes on the target, untar into them.
5. `docker compose up -d`.
6. **Verify credentials still decrypt** — that's the proof the encryption key carried over.

**Executed migration:** the licensed instance moved from a Windows/WSL2 host to a native **LMDE 7
(Linux) laptop** by restoring straight from the Google Drive backup onto fresh Docker. All workflows
came back intact, credentials decrypted, and the n8n Community license **re-bound its device
fingerprint to the new host automatically** — no re-licensing, no lost state. The earlier discipline
of running everything from a Linux/WSL2 shell paid off here: the OS switch was just "install Docker,
restore from Drive, `docker compose up -d`." From there it went straight to the public HTTPS host
above. The migration playbook is what makes the next hop — laptop → always-on VPS — a restore, not a
rebuild.

---

## Monitoring — failure alerting built in

This platform isn't blind when a workflow breaks. A reusable **n8n → Slack failure alerter**
(Error Trigger → Slack webhook) is wired in as the monitoring layer: any monitored workflow that
fails in production posts the workflow name, the node that broke, and the error to a `#alerts`
channel. It's secret-safe (webhook in `.env`, never in the workflow JSON) and proven against a real
failure.

→ Full writeup: [`../slack-alerter/`](../slack-alerter/)

---

## Licensing done right

n8n **Community Edition (free)** — claimed **only after an 8/8 infrastructure checklist passed**
(clean boot, UI reachable, Postgres backend confirmed, encryption-key persistence, volume
persistence, local backup, off-site push, restore-to-twin). One license = one email = one instance.
Claiming it on a throwaway or broken stack would have burned it — so verification came first.

---

## Debugging stories (what actually went wrong)

The real failures I diagnosed building this — diagnosis, not memorized facts:

1. **`.env` CRLF bug caught *before* first boot.** A scaffolded `.env` had trailing `\r` on the
   encryption key and DB password. Pre-boot was the *only* safe window to fix it: normalizing the
   file after boot would have changed the key and made every stored credential undecryptable. Fixed,
   then booted clean.
2. **Env-access blocked by a version-default flip.** `$env.SLACK_WEBHOOK_URL` returned
   `access denied`. Traced to **n8n v2.0 flipping `N8N_BLOCK_ENV_ACCESS_IN_NODE` to default-`true`**
   (checked the docs, didn't guess) and understood the trade-off it controls. Full story in the
   [alerter writeup](../slack-alerter/).
3. **YAML indentation bug.** A Compose edit one space too deep → *"mapping values are not allowed in
   this context."* Now I validate with `docker compose config -q` *before* `up`.
4. **The restore-to-twin test itself** — proved the backups rebuild the instance, rather than just
   confirming "files exist in Drive." The difference between assuming recovery and knowing it.

---

## What I learned

- Self-hosting is an **operating** discipline, not a one-time install: persistence, secrets, backups,
  recovery, and migration are the actual job.
- An **untested backup is a guess.** The restore-to-twin is the part that makes the backup real.
- The **encryption key is the instance's identity** — protect it, never rotate it, carry it through
  every move.
- Version-default changes can silently break a working config — read the changelog before assuming
  your setup is wrong.
- **Portability built from day one paid off** — when I actually migrated the licensed instance to a
  native Linux laptop, the OS switch was a restore (Docker + restore-from-Drive + `up -d`), not a
  rebuild, and the license re-bound itself.
- **Exposing a self-hosted service safely is a direction problem, not just a TLS problem.** An
  outbound tunnel gives real public HTTPS while the firewall stays closed and without a static IP —
  the connection direction is what makes that possible.

---

## Roadmap

- ✅ **Public HTTPS deployment — done.** Live at `https://n8n.minafbk.com` via Cloudflare Tunnel
  (real TLS, no open ports) — the piece that completes the job-posting spec. *(See [above](#live-https-deployment-cloudflare-tunnel).)*
- **Always-on host** — move from the laptop to a low-cost VPS so the URL is 24/7. Same domain, same
  Compose, same encryption key, same migration runbook — a restore, not a rebuild.
- **Cloudflare Access in front of the URL** — a second auth layer (identity at the edge) on top of the
  n8n owner login.
- **Network segmentation** (`frontend` ↔ n8n, `backend`: n8n ↔ postgres) to isolate the DB further.
- **Second off-site backup target** (Backblaze B2) — two independent destinations is the production
  standard.
- **AI automation (portfolio Asset 2)** built and run on this platform — the differentiator piece.

---

## Stack

- **n8n** v2.21.7 (self-hosted, pinned)
- **PostgreSQL 16** backend (not the SQLite default)
- **Docker + Docker Compose**, named volumes, healthcheck-gated startup
- **LMDE 7 (Linux native)** host; native Docker Engine
- **Cloudflare Tunnel** (`cloudflared` as a systemd service) + **Cloudflare Registrar** domain → live
  HTTPS, no open ports
- **rclone → Google Drive** for off-site backups; **cron** for the daily run
- Secrets: `.env` + gitignore, `N8N_ENCRYPTION_KEY`, env-var injection through Compose

## Cost

$0. Runs on existing hardware; Community Edition is free; Google Drive backup uses existing storage.

---

## Files

- The **full deployable config + operator runbook** (`docker-compose.yml`, `.env.example`,
  `backup.sh`, deploy/restore runbook) lives in a separate **private** repo,
  `MinaFBK/n8n-Community-Edition` — the sanitized excerpts above show the shape. Kept private because
  it's the live deployment config; available to walk through on request.
