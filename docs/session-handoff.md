# Session handoff — continue on another machine

> For Claude and the user when continuing on a different machine.
> Read this and `CLAUDE.md` (especially the **Working agreement**) before doing anything.
> Last updated: 2026-09-29, after a full successful run on Linux (ARM64 / Ubuntu).

---

## Where we are

**The AEM stack is working end to end on Linux (ARM64).** `make health` is all green,
and every site domain was tested in the browser with the WKND content installed:

```
https://dev-local-www-{brand,shop.brand,b2b.brand,new.brand}.com   → aem-nginx (mkcert SSL)
  → aem-dispatcher (Adobe defaults, "*" vhost/farm)                  http://localhost:9999
    → AEM Publish :4503 (Java 21)        AEM Author :4502 (Java 21)
```

The user ran every step by hand, following `docs/setup-guide.md` (steps 1–12).
That guide is the reference for the macOS run.

**Environment used on Linux:** SDK `aem-sdk-2026.9.28386.20260923T071724Z-260800`,
dispatcher tools 2.0.275, OpenJDK 21, Docker 29 / Compose v5, mkcert via apt,
`SDK_DIR="./sdk"`, `INSTALL_DIR="./sdk"`.

---

## Decisions made (don't re-litigate)

| Topic | Decision |
|---|---|
| Who runs commands | The user. Claude guides and edits files only (see CLAUDE.md). |
| Paths | Only `SDK_DIR` and `INSTALL_DIR` in `.env`; everything else is derived. Nothing is created in the project root. |
| Java | 21+ (`JAVA_REQUIRED=21`). SDK 2026.x refuses Java 17. |
| nginx | Runs in Docker (`aem-nginx`), owns 443/80. Site URLs never carry a port. |
| nginx → dispatcher | `proxy_pass http://aem-dispatcher:80` (container name, not `localhost:9999`) |
| Dispatcher container | Mirrors Adobe's `bin/docker_run.sh` env and mounts (incl. `import_sdk_config.sh`) |
| Dispatcher domains | Keep Adobe's default `*` for now (per-domain vhosts = later, "step 10b") |
| Stopping AEM | SIGTERM only, wait until the JVM exits, **no timeout by default, never `kill -9`** |
| Debug ports | 127.0.0.1 only |
| Uninstall | `make uninstall` reverts everything; aborts if AEM is still shutting down |

---

## Open items

1. **macOS test run.** Next task; checklist below.
2. **Git restore point.** The project isn't a git repo yet. Suggested: `git init`,
   `git add .`, check `git status` (no `.env`, nothing under `sdk/` except `.gitkeep`),
   then commit.
3. **Magento: on hold.** Options discussed: Warden, DDEV, or the custom scripts in
   `scripts/magento/`. Those scripts are **untested and not wired into make**;
   the user hasn't decided whether to keep them. The key constraint: Warden's
   Traefik also wants ports 80/443. The preference is to keep `aem-nginx` as the
   single SSL entry point. Still to check: whether Warden can move Traefik's
   ports (otherwise consider DDEV).
4. **Step 10b.** Per-domain dispatcher vhost/farm config, either hand-written or
   generated from `CUSTOM_DOMAINS`.
5. **Dispatcher config location.** `sdk/dispatcher/src` is gitignored, so custom
   config there isn't versioned. Decide on a git-tracked home.
6. **Optional:** `make start-author` / `stop-publish` style targets.
7. **Not yet exercised live:** `make stop-aem` (new graceful wait), `make restart`,
   `make uninstall` end to end.
8. **Review `docs/setup-guide.md`** against what the user actually saw.

---

## macOS test checklist

On the Mac, set up from scratch; nothing from the Linux run carries over except the files.

**Copy to the Mac:** the project (git or a folder copy), plus the SDK zip placed in
`sdk/`. The zip is gitignored, so it won't come through git.
**Don't copy:** `.env` (Linux `JAVA_HOME`), `sdk/author`, `sdk/publish`,
`sdk/certs`, `sdk/dispatcher*`. Let the scripts regenerate them.

**OS handling is automatic.** `scripts/lib/common.sh` sets `OS=mac` from `$OSTYPE`
(`darwin*`). The installer, hosts/DNS flush, PID check (`ps -ww`, no `/proc`),
dispatcher arch and `JAVA_HOME` detection branch on it; there's no separate Mac command set.
Changes made for macOS after the Linux run, **not yet run anywhere**: `JAVA_HOME`
auto-detect, BSD-safe `make help` pattern, LibreSSL-safe SAN printout.

| Step | macOS specifics to watch |
|---|---|
| 1 Prereqs | `make install-prereq` → `prereq/mac/install-prereq.sh` (Homebrew, `temurin@21`, Docker Desktop, mkcert + nss). **Not yet tested on a Mac.** No docker group step needed. |
| 2 `.env` | `make env`. Leave `JAVA_HOME=""`: `common.sh` now auto-picks a JDK ≥ `JAVA_REQUIRED` via `/usr/libexec/java_home` (**new, untested on Mac**). Set it explicitly only if the wrong JDK is picked. |
| 3 prereq | macOS ships **bash 3.2** as `/bin/bash`; the scripts avoid bash-4-only features, but this is the first real run on 3.2 — watch for syntax errors. Also check that `make help` lists targets (its awk pattern was made BSD-safe; untested). |
| 5 certs | `mkcert -install` may ask for your **Mac login password** (Keychain). The CA goes into the Keychain (Safari/Chrome); Firefox needs `nss`. The "SANs in cert" printout now uses `-text`, which LibreSSL supports. |
| 6 dispatcher | Apple silicon → loads `dispatcher-publish-arm64.tar.gz`; Intel → amd64. `HOST_OS=Darwin` is passed to the container, as Adobe's script does. |
| 8 hosts | same `/etc/hosts`; DNS flush uses `dscacheutil` + `killall -HUP mDNSResponder` (sudo) |
| 9 AEM | no `/proc` on macOS → PID check uses `ps -ww`; please confirm `bash scripts/06-start-aem.sh status` shows ✔ for both |
| 10–11 | `host.docker.internal` works natively in Docker Desktop; ports 80/443 bind without extra setup. Project folder must be under a Docker Desktop shared path (`/Users/...` is shared by default). |

**Linux-only commands in `docs/setup-guide.md`**, with Mac equivalents:

| Linux | macOS |
|---|---|
| `ss -ltnp \| grep :443` | `lsof -nP -iTCP:443 -sTCP:LISTEN` |
| `getent hosts <domain>` | `dscacheutil -q host -a name <domain>` |
| `ls -l --time-style=…` | `ls -lT` |
| `ls /usr/lib/jvm/` | `/usr/libexec/java_home -V` |
| `sudo apt install …` | `brew install …` |

If something fails on the Mac, the fix goes into the scripts, and the guide gets a macOS note.

---

## How to resume with Claude on the Mac

1. Open the project folder in Claude Code on the Mac.
2. Say: *"Continue from docs/session-handoff.md — macOS test run."*
3. Claude reads `CLAUDE.md` (working agreement) and this file, then guides step 1 onwards.
