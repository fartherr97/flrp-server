# FLRP :: OVH VPS Setup + git-pull Deploy Runbook

Moving FLRP from a managed host (Nodecraft) to a self-managed **OVH VPS** so
the server can `git pull` its own code — turning "manually upload files" into
"push to the repo, server updates itself."

This is a checklist to follow **with guidance**. Do the phases in order. Every
command is meant to be pasted into the VPS's SSH terminal unless noted.

> **What stays true from Nodecraft:** the resources are in git, the whole DB is
> one file (`database/flrp_schema_full.sql`), and `secrets.cfg` is host-only and
> never committed. Migration = clone + import + copy assets, not "redo it all."

---

## Phase 0 — Buy + provision

- **OVH → VPS**, **8 GB RAM** to start (resize up later), **Ubuntu 24.04 LTS**,
  a **US datacenter** (Vint Hill VA / Hillsboro OR).
- OVH emails the **server IP** + **root** login. Save them.
- Anti-DDoS is included on OVH ranges; we still open only the ports we need.

Have ready: the **IP**, and a terminal. Windows: `ssh` in PowerShell, or PuTTY.

---

## Phase 1 — First login + lock it down (one time)

```bash
# from your PC:
ssh root@YOUR_SERVER_IP

# create a non-root admin user (replace 'flrp')
adduser flrp
usermod -aG sudo flrp

# (recommended) set up SSH key auth for that user, then:
# disable root SSH + password login in /etc/ssh/sshd_config:
#   PermitRootLogin no
#   PasswordAuthentication no        # only after your key works!
systemctl restart ssh

# firewall: allow SSH + the FiveM port only
apt update && apt install -y ufw
ufw allow OpenSSH
ufw allow 30120/tcp
ufw allow 30120/udp
ufw allow 40120/tcp        # txAdmin web panel (lock to your IP if you can)
ufw enable
```

From here on, log in as `flrp` (`ssh flrp@YOUR_SERVER_IP`) and prefix admin
commands with `sudo`.

---

## Phase 2 — Install the stack

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git git-lfs curl xz-utils unzip mariadb-server
git lfs install
```

Secure MariaDB and make the FLRP database + user:

```bash
sudo mysql_secure_installation        # set a root password, answer Y to the rest

sudo mysql -u root -p <<'SQL'
CREATE DATABASE flrp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'flrp'@'localhost' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON flrp.* TO 'flrp'@'localhost';
FLUSH PRIVILEGES;
SQL
```

---

## Phase 3 — Install FXServer + txAdmin

```bash
sudo mkdir -p /opt/fivem/server /opt/fivem/txData
sudo chown -R flrp:flrp /opt/fivem
cd /opt/fivem/server

# Grab the latest RECOMMENDED linux artifact URL from:
#   https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/
# (copy the fx.tar.xz link for the recommended build), then:
curl -sLo fx.tar.xz "PASTE_RECOMMENDED_ARTIFACT_URL"
tar xf fx.tar.xz && rm fx.tar.xz
```

Run it once to start txAdmin (bundled). We'll keep it alive with systemd in
Phase 6:

```bash
cd /opt/fivem/server
./run.sh          # prints a txAdmin URL on :40120 — open http://YOUR_SERVER_IP:40120
```

In txAdmin: create the admin account, then set up the server pointing its data
folder at `/opt/fivem/txData`. Stop it (Ctrl+C) once configured.

---

## Phase 4 — Clone the repo (real LFS assets, no pointer mess)

```bash
cd /opt/fivem/txData
# clone the server repo's resources into place (adjust URL/branch)
git clone https://github.com/fartherr97/flrp-server.git repo
git -C repo lfs pull

# link/copy the server-data into txData (resources + config)
cp -r repo/server-data/resources ./resources
cp -r repo/server-data/config ./config
```

Vehicle/map content repos (LFS) clone the same way — `git clone` + `git lfs
pull` fetches the **real** model files directly on the box.

---

## Phase 5 — Config + database import

```bash
# create the host-only secrets file from the example (NEVER commit this)
cp config/secrets.example.cfg config/secrets.cfg
nano config/secrets.cfg
#   set mysql_connection_string "mysql://flrp:STRONG_PASSWORD@localhost:3306/flrp"
#   fill Discord token/guild/role IDs, flrp_api_shared_secret, etc.
#   (NO sv_licenseKey here if you set it in server.cfg; keep it in ONE place)

# import the whole schema in one shot
mysql -u flrp -p flrp < repo/database/flrp_schema_full.sql
```

Point `server.cfg` at the config chain + resources (same structure the repo
already uses). Add your `sv_licenseKey` (from keymaster) once.

---

## Phase 6 — Keep it running (systemd) + open to players

Create `/etc/systemd/system/fivem.service`:

```ini
[Unit]
Description=FLRP FXServer
After=network.target mariadb.service

[Service]
User=flrp
WorkingDirectory=/opt/fivem/server
ExecStart=/opt/fivem/server/run.sh +exec /opt/fivem/txData/server.cfg
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fivem
sudo systemctl status fivem      # confirm it's running
```

Players connect to `YOUR_SERVER_IP:30120` (or the cfx.re join link txAdmin
shows). txAdmin panel: `http://YOUR_SERVER_IP:40120`.

---

## Phase 7 — git-pull deploy (the payoff)

Now the server updates itself. Simplest version — a deploy script:

`/opt/fivem/deploy.sh`
```bash
#!/usr/bin/env bash
set -e
cd /opt/fivem/txData/repo
git pull --ff-only
git lfs pull
# sync changed resources/config into the live tree
rsync -a --delete server-data/resources/ /opt/fivem/txData/resources/
rsync -a          server-data/config/    /opt/fivem/txData/config/
echo "Pulled $(git rev-parse --short HEAD). Now: in txAdmin console run 'refresh' then 'restart <resource>'."
```

```bash
chmod +x /opt/fivem/deploy.sh
```

Deploy loop becomes: **merge in the repo → `/opt/fivem/deploy.sh` → `restart
<resource>` in txAdmin.** No file uploads, ever.

**Full automation (optional next step):** a Gitea/GitHub **webhook** or CI hits
the box on merge and runs `deploy.sh` automatically — then even the `git pull`
is hands-off. Wire this up once the manual script is proven.

> `secrets.cfg` lives only on the server and is git-ignored, so `git pull`
> never touches it. Resources and tracked configs come from the repo; secrets
> stay put.

---

## Migration cut-over (from Nodecraft)

1. Stand the VPS up fully and test-connect (Phases 1–6).
2. Import the DB (Phase 5) — same schema file you already used.
3. Copy over the large asset resources (vehicles/maps) via `git clone`+`lfs pull`.
4. When solid, point people at the new IP / join link and retire Nodecraft.
   No rush — run both in parallel until you're confident.
