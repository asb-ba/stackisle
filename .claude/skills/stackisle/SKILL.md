---
name: stackisle
description: >
  Local AEMaaCS dev environment in this repo (stackisle). Use for make targets, scripts
  00-09, starting, stopping or debugging AEM Author/Publish, Dispatcher, the nginx SSL
  proxy, certs, custom domains, hosts file, SDK_DIR/INSTALL_DIR/DISPATCHER_SRC_DIR,
  Java 21, prereq installers, or adding a stack to make. Also AEM questions: run modes,
  OSGi, Sling models, HTL, dispatcher vhost/farm/filter/cache config.
---

# stackisle

The always-on rules (working agreement, hard rules, conventions, configurable paths)
are in the repo root `AGENTS.md`. Follow them here. The core one: the user runs every
command, and you hand over the exact command and what to look for.

Done means the user has the next command to run, knows what success looks like, and
knows how to undo it. Stop and wait for pasted output before the step after.

## Make targets

`make help` lists every target. `make` alone runs the full flow:
`env → prereq(00) → setup(01-05 + hosts) → start(06-08) → wait(09)`.

| Group | Targets |
|-------|---------|
| Setup | `env` (create `.env`), `install-prereq` (platform installer), `prereq` (00), `setup` (01-05 + hosts), `sdk` (01+02 = `sdk-unpack` + `instances`), `certs` (03, `FORCE=1` regenerates), `dispatcher` (04), `dispatcher-validate`, `nginx` (05) |
| Name resolution | `hosts` / `hosts-remove` (sudo, edits the hosts file), `browser-no-admin` (no sudo, see below) |
| Run | `start` (06-08), `start-aem` (`WKND=1` also installs WKND), `start-dispatcher`, `start-nginx`, `stop`, `stop-aem`, `stop-dispatcher`, `stop-nginx`, `restart`, `restart-aem`, `reload-nginx`, `wknd` |
| Paths | `paths` (read-only layout), `set-paths SDK_DIR=… INSTALL_DIR=…` (either or both, rewrites `.env`) |
| Observe | `health` (= `status`, 09 once), `wait` (09 polls until healthy), `urls`, `smoke` (curls `SMOKE_PATH` on every hop, prints each curl), `logs` (= `logs-author`), `logs-author`, `logs-publish`, `logs-dispatcher`, `logs-nginx` |
| Cleanup | `clean` (certs, nginx conf, image ref; keeps AEM and SDK), `uninstall` (asks; keeps the SDK zip and `.env`) |

`stop` order is nginx → dispatcher → AEM. `logs-author` and `logs-publish` find the
running instance from its PID (`instance_live_dir`), so they tail the right log even when
AEM was started from another directory.

## First diagnosis

Before diagnosing anything, ask for:

```bash
make health                           # every hop: AEM, containers, dispatcher, https domains, hosts, cert SANs
bash scripts/06-start-aem.sh status   # real java PIDs, adopts instances started by hand
make paths                            # where SDK_DIR / INSTALL_DIR resolve
java -version                         # must be >= JAVA_REQUIRED (21)
```

Then `make smoke` to see which hop fails. For errors, read `references/troubleshooting.md`.

## Scripts

| Script | Role |
|--------|------|
| `00-check-prereq.sh` | Java ≥ `JAVA_REQUIRED`, Docker + compose, tools, SDK zip, writable paths |
| `01-unpack-sdk.sh` | Newest `SDK_DIR/aem-sdk*.zip` → `SDK_DIR/aem-sdk-<ver>/` |
| `02-create-author-publish.sh` | Quickstart jar → `INSTALL_DIR/author`, `INSTALL_DIR/publish`, unpack |
| `03-create-cert.sh` | `INSTALL_DIR/certs/server.crt` + `.key`, SANs = `CUSTOM_DOMAINS` (mkcert, else openssl) |
| `04-install-dispatcher.sh` | Dispatcher tools → `SDK_DIR/dispatcher-sdk-X.Y.Z/`, seeds `DISPATCHER_SRC_DIR` (default only), loads image |
| `05-create-nginx-config.sh` | `INSTALL_DIR/nginx/conf.d/<domain>.conf` per domain |
| `06-start-aem.sh` | `start\|stop\|status [author\|publish]`, PID-checked, graceful stop |
| `07-start-dispatcher.sh` | `start\|stop` dispatcher container |
| `08-start-nginx.sh` | `start\|stop\|reload` nginx container |
| `09-health-check.sh` | Checks every hop; `--wait` polls until healthy or `HEALTH_TIMEOUT` |
| `lib/common.sh` | Sourced by all: `.env`, defaults, derived paths and URLs, SDK globs, `compose()` |
| `install-wknd.sh` | Optional WKND sample site (`make wknd`) |
| `urls.sh` | `make urls`, `make smoke` |
| `set-paths.sh` | `make set-paths` |
| `open-browser-no-admin.sh` | `make browser-no-admin` |
| `uninstall.sh` | `make uninstall` |

`update-etc-hosts.sh` (repo root) backs `make hosts` / `make hosts-remove`. Per-script
detail, and the rules for changing a script or the Makefile, are in `references/script-guide.md`.

## Architecture

```
Browser → https://<domain>
  [aem-nginx container]   cert INSTALL_DIR/certs → /etc/nginx/certs
                          conf INSTALL_DIR/nginx/conf.d → /etc/nginx/conf.d
  → http://aem-dispatcher:80          (host view: http://localhost:9999)
    [aem-dispatcher container]  config DISPATCHER_SRC_DIR → /mnt/dev/src,
                                applied by Adobe's import_sdk_config.sh hook
    → http://host.docker.internal:4503 → AEM Publish (local Java process)
```

Both containers are in `docker-compose.yml` on network `aem-local-net`. Inside the nginx
container `localhost` is nginx itself, so nginx reaches the dispatcher by service name.

| Instance | Jar | Flags |
|----------|-----|-------|
| Author | `INSTALL_DIR/author/aem-author-p4502.jar` | `-r author,local -p 4502` |
| Publish | `INSTALL_DIR/publish/aem-publish-p4503.jar` | `-r publish,local -p 4503` |

Run modes, ports and JVM opts come from `.env` (`AUTHOR_RUNMODE`, `PUBLISH_RUNMODE`,
`AEM_JVM_OPTS`). For AEM concepts, read `references/aem-concepts.md`. For dispatcher
config edits, read `references/dispatcher-config.md`.

## Common tasks

**Add or change a domain.** Edit `CUSTOM_DOMAINS` in `.env` (space-separated). Then
`make certs FORCE=1`, `make nginx`, `make hosts` (or `make browser-no-admin`), and
`make reload-nginx`. No script changes: scripts read the domains from `.env`.

**No sudo for the hosts file.** `make browser-no-admin` opens the sites in a throwaway
Chrome or Edge window that maps each domain with `--host-resolver-rules`. Only that window
sees the mapping. Safari has no equivalent, and curl and other browsers still need
`make hosts`.

**Use the user's own dispatcher config.** Set `DISPATCHER_SRC_DIR` in `.env` to an
existing `dispatcher/src` (rules in `AGENTS.md`), then `make dispatcher-validate` and
`make stop-dispatcher start-dispatcher`.

**AEM will not stop.** `make stop-aem` waits until the JVM exits, with no timeout. Watch
`make logs-author` (or `logs-publish`). Ctrl+C stops only the waiting. Never offer a force kill.

**Add a stack to make.** Create `mk/<stack>.mk` with `## ` comments on its targets so
they show in `make help`. Put logic in a script under `scripts/` that sources
`scripts/lib/common.sh`, and cover macOS, Linux and Windows. Hook it into the main flow
only when the user asks, for example `all: <stack>-start`.

## Platform prereqs

```bash
bash prereq/mac/install-prereq.sh                     # macOS (Homebrew)
bash prereq/linux/install-prereq.sh                   # Linux (apt or dnf)
powershell -File prereq/windows/install-prereq.ps1    # Windows (Chocolatey, as Admin)
```

`make install-prereq` picks the mac or linux installer.
