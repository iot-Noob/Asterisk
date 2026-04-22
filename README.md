# 📞 Asterisk 22 — Docker Setup
> **Written by IOT Noob Talha** — yes I'm learning, yes it took forever, yes it works now 😤

This is a fully hardened, production-ready [Asterisk 22](https://www.asterisk.org/) VoIP server running inside Docker.
Built from source. Auto-configures itself. Runs on your own machine.

---

## 🗂️ Project Structure

```
Asterisk/
├── Dockerfile          ← Recipe to build the Asterisk image from source
├── docker-compose.yaml ← How Docker should run the container
├── entrypoint.sh       ← Startup script (seeds config, fixes permissions, starts Asterisk)
├── .gitignore          ← Tells Git what NOT to save (runtime data)
├── README.md           ← This file
│
├── config/             ← 🔧 YOUR Asterisk config files live here (auto-created on first run)
├── logs/               ← 📋 Asterisk logs
├── sounds/             ← 🔊 Custom sound files
└── spool/              ← 📬 Voicemail, recordings, call data
```

> 📁 The **config, logs, sounds, spool** folders are auto-created when you first run the container.
> Your data lives on the **host PC** (not inside the container), so it survives restarts and rebuilds.

---

## ✅ Requirements

Before you start, make sure you have these installed on your Linux machine:

| Tool | How to install |
|------|----------------|
| Docker | `sudo apt install docker.io` |
| Docker Compose | `sudo apt install docker-compose` |
| 2GB+ free disk space | For building from source |
| Internet connection | For downloading Asterisk source |

---

## 🚀 First Time Setup (Build + Run)

### Step 1 — Clone / Copy the project
Put all project files in one folder (e.g. `/home/yourname/Documents/Docker Deploy/Asterisk/`).

### Step 2 — Build and start

Open a terminal **inside the project folder** and run:

```bash
docker-compose -p asterisk up -d --build
```

> ⚠️ **First build takes 15–40 minutes.** It downloads and compiles Asterisk from source.
> Grab a chai ☕ and wait patiently.

### Step 3 — Watch the logs

```bash
docker logs -f asterisk
```

You should see something like:

```
Initializing configuration directory with samples...
Ensuring file permissions...
Starting Asterisk as user 'asterisk'...
Asterisk Ready.
```

If you see that — **congratulations, it's running!** 🎉

---

## 🛑 Stop / Start / Restart

```bash
# Stop the container (data is safe, nothing is deleted)
docker-compose -p asterisk down

# Start it again (fast, no rebuild needed)
docker-compose -p asterisk up -d

# Restart it
docker-compose -p asterisk restart asterisk
```

---

## 💻 Access the Asterisk Console (CLI)

This is like "talking to Asterisk" directly. Use this to debug calls, check modules, etc.

```bash
docker exec -it asterisk asterisk -rvvvvv
```

Useful commands inside the Asterisk CLI:

```
core show status          → Show if Asterisk is alive and healthy
pjsip show endpoints      → List all SIP phones/extensions registered
core show channels        → Show active calls right now
module show               → List all loaded modules
core restart now          → Restart Asterisk (without restarting the container)
exit                      → Leave the CLI (Asterisk keeps running)
```

---

## 📱 Connecting a Phone (SIP)

Since we use **host networking**, your phone connects directly to your PC's IP address.

### Step 1 — Find your PC's IP
```bash
hostname -I
```
Example output: `192.168.1.50` — this is your "server address"

### Step 2 — Open firewall ports
```bash
sudo ufw allow 5060/udp     # SIP signaling
sudo ufw allow 10000:20000/udp  # RTP audio
```

### Step 3 — Configure an extension in `config/pjsip.conf`

Open `./config/pjsip.conf` on your host PC and add an extension like this at the **bottom of the file**:

```ini
; ---- Extension 101 ----
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0

[101]
type=endpoint
context=default
disallow=all
allow=ulaw
allow=alaw
auth=auth101
aors=aors101

[auth101]
type=auth
auth_type=userpass
password=MySecretPass123
username=101

[aors101]
type=aor
max_contacts=1
```

### Step 4 — Reload Asterisk config (no restart needed!)
```bash
docker exec -it asterisk asterisk -rx "core reload"
```

### Step 5 — Connect your softphone app

Use any SIP app (Zoiper, Linphone, MicroSIP, etc.) with these settings:

| Setting | Value |
|---------|-------|
| SIP Server / Domain | `192.168.1.50` (your PC's IP) |
| Username | `101` |
| Password | `MySecretPass123` |
| Port | `5060` (UDP) |

---

## 🔄 Upgrading to a New Asterisk Version

When a new version of Asterisk comes out (e.g. `22.6.0`), here's exactly what to do:

### Step 1 — Edit the Dockerfile

Open `Dockerfile` and find line 46:

```dockerfile
ARG ASTERISK_VERSION=22.5.0
```

Change it to the new version:

```dockerfile
ARG ASTERISK_VERSION=22.6.0
```

> ✅ That's the **only line you need to change** for a version bump within the same major version (22.x).

### Step 2 — Check the download URL exists

Before building, verify the new version actually exists. Open this URL in your browser and replace `22.6.0` with your new version:

```
https://downloads.asterisk.org/pub/telephony/asterisk/releases/
```

Make sure a file called `asterisk-22.6.0.tar.gz` is listed there.

### Step 3 — Rebuild the image

```bash
docker-compose -p asterisk up -d --build
```

> ⚠️ A version upgrade will **re-download and recompile** from scratch. This will take 15–40 minutes again.

### Step 4 — Your config is safe!

Your `./config/` folder on the host is untouched. The new container will automatically pick up your existing configuration.

---

## ⚠️ Upgrading to a MAJOR version (e.g. 22 → 24)

This is more involved. Here's what you might need to change in the `Dockerfile`:

### 1. Update the version number (same as above)
```dockerfile
ARG ASTERISK_VERSION=24.0.0
```

### 2. Check for removed/renamed modules

Asterisk sometimes removes old modules in new major versions. If the build fails with `'module_name' not found`, find and remove it from the `menuselect` section of the `Dockerfile`.

Look for the `RUN menuselect/menuselect` block (around line 61) and delete the `--enable` line for the missing module.

### 3. Check for new runtime library requirements

If the container fails to start with `error while loading shared libraries: libXXX.so`, add the missing library to the `apt-get install` block in the **Final Stage** section of the `Dockerfile` (around line 145).

Example — if `libfoo.so.2` is missing, find the Debian package name:
```bash
apt-cache search libfoo
```
Then add it to the list:
```dockerfile
    libfoo2 \
```

Then rebuild.

---

## 📝 Editing the .gitignore

The `.gitignore` is set up to **track only your project files** (Dockerfile, compose, entrypoint) and **ignore all runtime data** (configs, logs, sounds, spool).

### Current .gitignore rules:

```
*                    ← Ignore everything by default
!.gitignore          ← But keep this file
!Dockerfile          ← Keep the build recipe
!docker-compose.yaml ← Keep the compose config
!entrypoint.sh       ← Keep the startup script

config/              ← Ignore — runtime configs (your private phone settings)
sounds/              ← Ignore — audio files
logs/                ← Ignore — log files
spool/               ← Ignore — voicemail, recordings
```

### If you add a new project file (e.g. `nginx.conf`):

Add an exception line to `.gitignore`:

```
!nginx.conf
```

### If you want to track a new folder (e.g. `scripts/`):

Add this to `.gitignore`:

```
!scripts/
!scripts/**
```

---

## 🧯 Troubleshooting

### Container keeps restarting
```bash
docker logs asterisk
```
Read the error message. Common causes:
- **Missing library** → Add it to `Dockerfile` runtime deps and rebuild
- **Config file error** → Check `./config/asterisk.conf` for syntax errors
- **Port already in use** → Another service is using port 5060

### "error while loading shared libraries"
Add the missing library to the `apt-get install` block in the final stage of `Dockerfile` and rebuild.

### Can't connect phone
- Check firewall: `sudo ufw status`
- Check Asterisk is running: `docker ps`
- Check your pjsip.conf has the extension defined
- Run `docker exec -it asterisk asterisk -rx "pjsip show endpoints"` to verify the extension is loaded

### Reset everything (nuclear option)
> ⚠️ This deletes your config! Back up `./config/` first!

```bash
docker-compose -p asterisk down
docker rmi asterisk
rm -rf config/ logs/ spool/
docker-compose -p asterisk up -d --build
```

---

## 🏗️ Architecture Overview

```
Your Host PC (Linux)
│
├── ./config/  ──────────────────────┐
├── ./logs/    ──────────────────────┤  Volume Mounts
├── ./sounds/  ──────────────────────┤  (data lives on YOUR PC)
└── ./spool/   ──────────────────────┤
                                     │
         Docker Container            │
         ┌───────────────────┐       │
         │  Asterisk 22      │◄──────┘
         │  (runs as UID 1000│
         │   = asterisk user)│
         │                   │
         │  Ports exposed:   │
         │  5060 UDP/TCP SIP │
         │  5061 TLS SIP     │
         │  10000-20000 RTP  │
         │  8088 ARI HTTP    │
         │  8089 ARI HTTPS   │
         │  4569 IAX2        │
         │  5038 AMI         │
         └───────────────────┘
              │ (host network mode)
              ▼
         Your Network
         (phones connect directly)
```

---

## 📡 Port Reference

| Port | Protocol | Purpose |
|------|----------|---------|
| 5060 | UDP + TCP | SIP signaling (main port for phones) |
| 5061 | UDP + TCP | SIP over TLS (encrypted) |
| 10000–20000 | UDP | RTP audio streams (actual voice data) |
| 8088 | TCP | ARI REST API (HTTP) |
| 8089 | TCP | ARI REST API (HTTPS) |
| 4569 | UDP | IAX2 protocol (Asterisk-to-Asterisk) |
| 5038 | TCP | AMI — Asterisk Manager Interface |

---

## 👨‍💻 Author

**Talha** — IOT Noob  
Built this after way too many `error while loading shared libraries` messages.  
If it works for you, great. If not, `docker logs asterisk` is your best friend. 😂

---

*Asterisk® is a registered trademark of Sangoma Technologies.*
