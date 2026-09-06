# Deployment

The goal: **a reviewer installs the APK, opens it, and it works** — at no cost.

Two routes are documented. Take Option A unless you have a reason not to.

| | Option A — Render + Aiven | Option B — Oracle Cloud VM |
|---|---|---|
| Setup | ~25 minutes, all in a browser | ~90 minutes, SSH and DNS |
| Always on | No — sleeps after 15 min idle | Yes |
| Cold start | ~45–60 s (mitigated below) | none |
| HTTPS | Automatic | Caddy, automatic |
| Cost | £0 | £0 |

> **Free-tier terms move.** Everything below was checked in **September 2026** and each claim links
> to its source. Re-read the provider's own page before relying on a number.

---

## 0. Before either option

### The backend is already deployment-ready

Nothing needs changing to deploy this. For the record, here is what makes it so:

| Requirement | Where |
|---|---|
| Listens on the platform's port | `server.port=${PORT:8080}` in `application.yml`; `Dockerfile` defaults `PORT=8080` |
| Runs as a non-root user | `Dockerfile` creates and switches to `triosuite` (uid 10001) |
| Fits a 512 MB container | `JAVA_OPTS` sets `-XX:MaxRAMPercentage=75 -XX:+UseSerialGC -Xss512k -XX:TieredStopAtLevel=1` |
| Starts fast on a small box | `spring.main.lazy-initialization: true` in the `prod` profile |
| Migrates its own schema | Flyway runs `V1__schema.sql` and `V2__seed.sql` on first start; a second start is a no-op |
| Health probe for the platform | `GET /actuator/health` — anonymous, and the only actuator endpoint besides `info` |
| Trusts the proxy's HTTPS | `server.forward-headers-strategy: framework` |
| Fails fast on missing secrets | The `prod` profile has **no defaults** for `JWT_SECRET`, `DB_URL`, `DB_USERNAME` or `DB_PASSWORD` |

### Generate a JWT secret

HS256 needs at least 256 bits. Startup refuses anything shorter, so this is not optional.

```bash
openssl rand -base64 48
```

```powershell
# Windows, no openssl
[Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 }))
```

Keep it out of the repository. It goes into the platform's environment-variable settings and
nowhere else.

### The variables you will need

Straight from [`.env.example`](../.env.example):

| Variable | Value |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `DB_URL` | the JDBC URL from step 1 below |
| `DB_USERNAME` | from your database provider |
| `DB_PASSWORD` | from your database provider |
| `JWT_SECRET` | what you just generated |
| `JWT_ISSUER` | `triosuite-invoices-api` |
| `CORS_ALLOWED_ORIGINS` | leave empty — the Android app is not a browser |
| `DB_POOL_MAX` | `5` on a 1 GB database (see the note in step 1) |

---

## Option A — Render + Aiven

### 1. A managed MySQL on Aiven

Aiven's free plan is 1 GB RAM, 1 GB storage, a single node, **no credit card**, and no time limit —
though a service that goes unused is powered off, with warning by e-mail
([Aiven docs](https://aiven.io/docs/products/mysql/concepts/mysql-free-tier),
[free MySQL page](https://aiven.io/free-mysql-database)). The keep-alive in step 4 also keeps the
database busy enough to avoid that, because the health probe touches it.

1. Sign up at **[aiven.io](https://aiven.io)** and create a project.
2. **Create service → MySQL**.
3. Choose the **Free** plan, and a cloud region **geographically close to where you will put
   Render** — every query crosses that gap, and a European database behind a US web service adds
   150 ms to every request.
4. Name it `triosuite-mysql` and create it. It takes two or three minutes to come up.
5. On the service's **Overview** tab, note **Host**, **Port**, **User**, **Password** and
   **Database name** (Aiven's default database is `defaultdb`).

Build the JDBC URL — note `sslMode=REQUIRED`, which Aiven insists on:

```
jdbc:mysql://mysql-xxxxxxx-yourproject.a.aivencloud.com:12345/defaultdb?sslMode=REQUIRED&characterEncoding=utf8&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true
```

> **Set `DB_POOL_MAX=5`.** The default is 10, and a 1 GB Aiven node caps out around 20–25
> connections. One instance with 10 leaves little room for you to connect with a client at the same
> time.

### 2. The web service on Render

Render's free web services spin down after **15 minutes** of inactivity — reduced from 30 — and
take about a minute to come back. Each workspace gets **750 instance-hours per calendar month**
([Render free tier, 2026](https://render.com/articles/platforms-with-a-real-free-tier-for-developers-in-2026),
[limits summary](https://unanswered.io/guide/render-free-tier-details)). A 31-day month is 744
hours, so **one** always-on service fits inside the allowance — a second would not.

1. Push this repository to GitHub (see the root README).
2. Sign in at **[render.com](https://render.com)** and choose **New → Web Service**.
3. Connect the repository.
4. Configure it:

   | Field | Value |
   |---|---|
   | Language | **Docker** |
   | Root Directory | `backend` |
   | Dockerfile Path | `backend/Dockerfile` |
   | Region | **the same as your Aiven region** |
   | Instance Type | **Free** |
   | Health Check Path | `/actuator/health` |

5. Under **Environment**, add every variable from the table in step 0. Do not set `PORT` — Render
   injects it, and the Dockerfile already honours it.
6. **Create Web Service.** The first build takes 5–10 minutes: it downloads the Maven dependencies,
   compiles, and builds the runtime image.

Watch the logs for Flyway doing its work on first boot:

```
Migrating schema `defaultdb` to version "1 - schema"
Migrating schema `defaultdb` to version "2 - seed"
Successfully applied 2 migrations
...
Started TriosuiteInvoicesApiApplication in 12.4 seconds
```

### 3. Prove it works

```bash
curl -sS https://<your-service>.onrender.com/actuator/health
# {"status":"UP"}

backend/scripts/smoke.sh https://<your-service>.onrender.com
```

The smoke script walks the entire reviewer journey — login, list, create a tax-inclusive USD invoice
containing an item found by barcode, approve it, be refused an edit, cancel it, confirm the record
survives — and exits non-zero at the first thing that misbehaves. It waits up to two minutes for the
first response, so a cold start does not fail it.

Confirm Flyway actually created everything:

```bash
mysql -h <host> -P <port> -u <user> -p --ssl-mode=REQUIRED defaultdb \
  -e "SHOW TABLES; SELECT COUNT(*) AS items FROM items; SELECT * FROM invoice_sequences;"
# 11 tables (10 plus flyway_schema_history), 15 items, INV/2026/7
```

### 4. Stop it going to sleep

A reviewer who waits a minute on a blank screen has already formed an opinion. Ping the health
endpoint every five minutes and the service never spins down.

**UptimeRobot** — free plan, 50 monitors, a fixed 5-minute interval
([pricing](https://uptimerobot.com/pricing/),
[free-plan limits](https://stillup.org/blog/uptimerobot-free-plan-limits)):

1. Sign up at [uptimerobot.com](https://uptimerobot.com).
2. **Add New Monitor** → type **HTTP(s)**, URL `https://<your-service>.onrender.com/actuator/health`,
   interval **5 minutes**.

> Since December 2024 UptimeRobot's free plan is restricted to **personal, non-commercial** use. A
> hiring assessment qualifies; a client project would not. If in doubt use
> **[cron-job.org](https://cron-job.org)**, which is free, has no such restriction, and schedules
> down to every minute.

This also keeps the Aiven service from being powered off for inactivity, because the health check
takes a connection from the pool.

**Why this stays inside the allowance:** 750 hours covers one service running continuously for a
744-hour month. Do not point a keep-alive at a second free service.

### 5. Point the app at it

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://<your-service>.onrender.com
cp build/app/outputs/flutter-apk/app-release.apk ../release/app-release.apk
```

Then commit the APK, put the URL in the root `README.md`, and attach the APK to a GitHub Release —
the exact commands are in the README.

---

## Option B — Oracle Cloud Always Free

Always on, no cold start, and you own the whole box. It costs an evening rather than twenty minutes.

> **The allocation halved.** Always Free Ampere A1 was 4 OCPU / 24 GB; it is now **2 OCPU / 12 GB**
> ([Oracle Cloud Customer Connect](https://community.oracle.com/customerconnect/discussion/970310/oci-always-free-updated-ampere-a1-compute-allocation),
> [analysis](https://terminalbytes.com/oracle-cloud-free-tier-changes-2026/)). Still far more than
> this application needs. Capacity is the real obstacle: US regions frequently answer
> "Out of host capacity" for hours, while Frankfurt, Singapore and Tokyo usually provision at once
> — so pick your home region accordingly, since Always Free A1 only exists there.

### 1. The VM

1. Sign up at [cloud.oracle.com](https://cloud.oracle.com) — a card is required for identity
   verification; Always Free resources are not charged.
2. **Compute → Instances → Create Instance**.
3. Shape: **Ampere / VM.Standard.A1.Flex**, 2 OCPU, 12 GB. Image: **Ubuntu 22.04** (aarch64).
4. Save the SSH private key when it is offered. It is shown once.
5. After it boots, note the public IP.

### 2. Open the ports — both firewalls

This is where most people lose an hour: Oracle has a firewall at the network level *and* Ubuntu has
one on the instance. Both must allow 80 and 443.

```bash
# On the VM
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

In the OCI console: **Networking → Virtual Cloud Networks → your VCN → Security Lists → Default** →
add ingress rules for `0.0.0.0/0` on TCP 80 and 443.

### 3. A hostname

Free subdomain from **[duckdns.org](https://duckdns.org)** — sign in, claim
`triosuite-invoices.duckdns.org`, point it at the VM's public IP.

### 4. Docker, and the stack

```bash
sudo apt-get update && sudo apt-get install --yes docker.io docker-compose-v2 git
sudo usermod -aG docker $USER && newgrp docker

git clone https://github.com/<you>/triosuite-invoices.git
cd triosuite-invoices

cat > .env <<'EOF'
SPRING_PROFILES_ACTIVE=prod
MYSQL_ROOT_PASSWORD=<a long random string>
MYSQL_DATABASE=triosuite
DB_USERNAME=triosuite
DB_PASSWORD=<a long random string>
JWT_SECRET=<openssl rand -base64 48>
JWT_ISSUER=triosuite-invoices-api
CORS_ALLOWED_ORIGINS=
API_HOST_PORT=8080
EOF
chmod 600 .env

docker compose up --build --detach
docker compose ps          # both services healthy
curl -sS localhost:8080/actuator/health
```

`docker-compose.yml` already sets `restart: unless-stopped` on both services, so they come back
after a reboot.

### 5. HTTPS with Caddy

Caddy obtains and renews a Let's Encrypt certificate on its own — no certbot, no cron.

```bash
sudo apt-get install --yes debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update && sudo apt-get install --yes caddy

sudo tee /etc/caddy/Caddyfile > /dev/null <<'EOF'
triosuite-invoices.duckdns.org {
    reverse_proxy localhost:8080
}
EOF

sudo systemctl restart caddy
curl -sS https://triosuite-invoices.duckdns.org/actuator/health
```

The API already trusts `X-Forwarded-Proto` (`server.forward-headers-strategy: framework`), so it
builds correct `Location` headers behind Caddy without further configuration.

### 6. Back the database up

```bash
mkdir -p ~/backups
cat > ~/backup-triosuite.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/triosuite-invoices"
source .env
docker compose exec -T mysql mysqldump \
    -u root -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines "$MYSQL_DATABASE" \
    | gzip > "$HOME/backups/triosuite-$(date +%F-%H%M).sql.gz"
find "$HOME/backups" -name 'triosuite-*.sql.gz' -mtime +14 -delete
EOF
chmod +x ~/backup-triosuite.sh
( crontab -l 2>/dev/null; echo "0 3 * * * $HOME/backup-triosuite.sh" ) | crontab -
```

`--single-transaction` matters: it takes a consistent snapshot of InnoDB tables without locking
them, so the dump does not block invoices being created while it runs.

---

## Local versus production

Everything that differs is an environment variable. Nothing in the repository changes.

| Variable | Local | Production |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `local` | `prod` |
| `DB_URL` | `…?sslMode=DISABLED&allowPublicKeyRetrieval=true` | `…?sslMode=REQUIRED` |
| `DB_PASSWORD` | the development default | a generated secret |
| `JWT_SECRET` | a development default in `application.yml` | **required**; startup fails without it |
| `DB_POOL_MAX` | `10` | `5` on a 1 GB database |
| `LOG_LEVEL_APP` | `DEBUG` | `INFO` |

The `local` profile carries development defaults so the project runs with no setup. The `prod`
profile has none — omit a secret and the application refuses to start, rather than coming up in a
state where the first login is the thing that discovers the problem.

---

## Before anyone else uses this

The demo credentials are in a public repository. Anything beyond a review needs both of these.

### Change the demo passwords

Generate BCrypt hashes at strength 12 and update the rows:

```bash
# From the backend directory, using the project's own dependencies
cd backend && ./mvnw -q dependency:build-classpath -Dmdep.outputFile=target/cp.txt
cat > /tmp/Hash.java <<'EOF'
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
public class Hash {
    public static void main(String[] args) {
        System.out.println(new BCryptPasswordEncoder(12).encode(args[0]));
    }
}
EOF
java -cp "$(cat target/cp.txt)" /tmp/Hash.java 'your-new-password'
```

```sql
UPDATE users SET password_hash = '$2a$12$…', updated_at = UTC_TIMESTAMP(6) WHERE username = 'admin';
UPDATE users SET password_hash = '$2a$12$…', updated_at = UTC_TIMESTAMP(6) WHERE username = 'sales';
```

Do **not** edit `V2__seed.sql` to do this — Flyway records a checksum of every migration it has
applied, and changing one that has already run makes the next start fail validation. Either add a
`V3__` migration or run the `UPDATE` directly.

### Rotate `JWT_SECRET`

Change the variable and restart. Every access token signed with the old key stops verifying, so
everyone is signed out — which is the point. Refresh tokens are opaque and stored hashed, so they
are unaffected: clients recover on their next refresh without a visible interruption.

---

## Review day

Five minutes, in this order:

1. **The monitor is green.** UptimeRobot or cron-job.org shows no recent downtime.
2. `curl -sS https://<url>/actuator/health` → `{"status":"UP"}`, answering immediately rather than
   after a minute — that is how you know the keep-alive is doing its job.
3. `backend/scripts/smoke.sh https://<url>` → all checks pass.
4. Open the app on a phone, sign in as `admin`, and create one invoice with a scanned barcode.
5. Confirm the APK in `release/` was built with `--dart-define=API_BASE_URL=https://<url>`. Settings
   → **API address** shows what the app will actually call.

### If the hosted API is unreachable, the reviewer is not stuck

The app can be retargeted at runtime, and this is documented in the README so it does not have to be
discovered:

- **Settings → API address**, or the **Change API address** button on the "cannot reach the server"
  screen.
- Type a base URL, tap **Test connection** to check it before committing, then **Save**.
- **Reset to the built-in default** puts it back.

So a reviewer can run the backend themselves — `docker compose up` — and point the installed APK at
their own machine without rebuilding anything.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to configure a DataSource: 'url' attribute is not specified` | `DB_URL` missing | The `prod` profile has no default. Set all four database variables. |
| `Could not resolve placeholder 'JWT_SECRET'` | Secret missing | Set it. This failure is deliberate. |
| `must be at least 32 bytes to be a safe HS256 key` | Secret too short | `openssl rand -base64 48`. |
| `Public Key Retrieval is not allowed` | MySQL 8 `caching_sha2_password` over a plain connection | Use `sslMode=REQUIRED` (managed) or add `allowPublicKeyRetrieval=true` (local only). |
| `Access denied for user` | Wrong credentials, or the user cannot reach that database | Re-copy them; on Aiven check you used the service's own user and `defaultdb`. |
| Render build times out | First build downloads the whole Maven dependency tree | Retry; the layer is cached and the second build is minutes faster. |
| Deploy loops on "health check failed" | Startup slower than the platform's grace period | Health Check Path must be `/actuator/health`, and Render's start period must exceed a JVM cold start. |
| First request takes ~60 s | Free tier spun down after 15 min idle | Expected. Add the keep-alive monitor from step 4. |
| Container killed, exit 137 | Out of memory | The `JAVA_OPTS` in the Dockerfile already sit inside 512 MB — check you have not overridden them. |
| `Validate failed: Migration checksum mismatch` | An already-applied migration was edited | Never edit an applied migration. Add a new `V3__` file. |
| App says "Cannot reach the server" on a phone | Wrong URL baked in, or plain HTTP | Release builds are HTTPS-only by design. Use Settings → API address to confirm and correct it. |
| Barcode scanner shows "Camera access is off" | Permission denied | Android Settings → Apps → Triosuite Invoices → Permissions → Camera. The picker works regardless. |

---

## Sources

Free-tier terms verified September 2026:

- [Platforms with a real free tier for developers in 2026 — Render](https://render.com/articles/platforms-with-a-real-free-tier-for-developers-in-2026)
- [Render free tier: 750 hours, spin-down behaviour](https://unanswered.io/guide/render-free-tier-details)
- [Aiven for MySQL free tier — Aiven docs](https://aiven.io/docs/products/mysql/concepts/mysql-free-tier)
- [Always-free managed MySQL — Aiven](https://aiven.io/free-mysql-database)
- [OCI Always Free: updated Ampere A1 allocation — Oracle Cloud Customer Connect](https://community.oracle.com/customerconnect/discussion/970310/oci-always-free-updated-ampere-a1-compute-allocation)
- [Oracle Cloud free tier 2026: 4 OCPU/24 GB cut to 2 OCPU/12 GB](https://terminalbytes.com/oracle-cloud-free-tier-changes-2026/)
- [UptimeRobot plans and pricing](https://uptimerobot.com/pricing/)
- [UptimeRobot free plan limits in 2026](https://stillup.org/blog/uptimerobot-free-plan-limits)
