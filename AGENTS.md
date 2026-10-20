# stackisle: AEM local dev

Shared project rules for every coding agent. Claude reads this file through
`CLAUDE.md`; other agents read it directly.

## What this project is

A cross-platform, one-command local environment for **Adobe Experience Manager as a
Cloud Service (AEMaaCS)**. `make` sets up and starts AEM Author, AEM Publish, an AEM
Dispatcher container and an nginx SSL container that serves each domain in
`CUSTOM_DOMAINS` over https with no port:

```
Browser → https://<domain>  → nginx (Docker, owns 80/443)
  → aem-dispatcher:80 (host view: localhost:9999) → AEM Publish localhost:4503
AEM Author: localhost:4502      Default login: admin / admin
```

Ports, domains and credentials are defaults from `.env`. `make urls` prints the real ones.

## Working agreement

- **The user runs every command.** You guide one step at a time: what the step does,
  how to check it worked, how to undo it. You edit scripts and docs. You do not execute
  setup, start, test or verification commands, not even in a scratch copy, because they
  change the user's machine (Docker images, AEM repositories, hosts file, ports). When
  something needs checking, give the exact command and what to look for, then wait for
  the pasted output.
- Before a step that uses sudo, edits the hosts file, pulls or removes Docker images, or
  binds ports, say so before the user runs it.
- If `docs/session-handoff.md` exists on this machine, read it first. It is gitignored
  and holds the local state, decisions and open items.

## Hard rules

These protect data or security. Keep them even when the user asks otherwise, and
explain why.

- **Never force-kill AEM** (`kill -9`, SIGKILL, Task Manager end-task). A hard kill
  mid-shutdown can corrupt the Oak repository and its indexes. Stop is SIGTERM, then
  wait until the JVM exits: `make stop-aem`. The wait has no timeout
  (`AEM_STOP_TIMEOUT=0`) because shutdown time depends on repository size and
  reindexing. Do not add wait limits. Nothing may delete or restart a repository while
  its JVM runs.
- **Debug ports bind to `127.0.0.1` only**, never `*`. An open JDWP port allows remote
  code execution.
- **Deletions are item-specific.** Uninstall and clean remove named stackisle files,
  never a whole configurable directory, so a wrong path in `.env` cannot wipe user data.
  Process matching targets the java command line only.

## Conventions

- **Java 21+** (`JAVA_REQUIRED=21` in `.env`). The AEM SDK 2026.x quickstart refuses
  to start on Java 17. Never suggest a lower version. When the user asks about a Java
  version, name the floor and where it lives: `JAVA_REQUIRED` in `.env`. If a future SDK
  needs more, raise `JAVA_REQUIRED`; scripts and installers follow it.
- **JVM opts:** never add `-XX:MaxPermSize`. The JVM refuses to start with it.
- **Never hardcode SDK version strings.** Glob for `aem-sdk*.zip`, `aem-sdk-*/` and
  `dispatcher-sdk-*/`; `scripts/lib/common.sh` has the glob functions.
- **Nothing environment-specific is hardcoded.** Hosts, IPs, ports, domains, test paths
  and credentials come from `.env`, with defaults in `scripts/lib/common.sh`. Scripts use
  the derived `AUTHOR_URL`, `PUBLISH_URL`, `DISPATCHER_URL` and `site_url <domain>`.
  Fixed by design: container names and ports inside Docker (`aem-dispatcher:80`,
  `host.docker.internal`) and the JDWP bind `127.0.0.1`.
- **Scripts source `scripts/lib/common.sh`** for `.env` loading, defaults, globs and
  `compose()`. Do not duplicate that logic.
- **Scripts are numbered `00`–`09` and stay in order.** Never renumber.
- **`make` is the user interface.** Suggest `make <target>`, not `bash scripts/...`,
  unless no target exists.
- **Cross-platform.** A change to any script or installer considers macOS (bash 3.2),
  Linux and Windows (Git Bash, PowerShell installers in `prereq/windows/`).
- **Verify the prerequisite installers** in `prereq/<os>/` before telling the user to run `make`.
- **New stacks** go in `mk/<stack>.mk`. The Makefile auto-includes `mk/*.mk`. The `mk/`
  directory is created with the first stack; none exist yet. If the user asks for a stack
  that has no `mk/` file and no script, say it does not exist in this repo. Do not invent one.

## Configurable paths

Two paths in `.env` drive everything. `scripts/lib/common.sh` derives the rest, and
scripts use the derived variables, never literal paths. `make paths` prints the layout.

```
SDK_DIR="./sdk"       # aem-sdk*.zip, unpacked aem-sdk-*/, dispatcher-sdk-*/
INSTALL_DIR="./sdk"   # author/ publish/ dispatcher/{src,docker,logs} certs/ nginx/conf.d/
```

One optional override: **`DISPATCHER_SRC_DIR`**. Blank (default) means
`INSTALL_DIR/dispatcher/src`, seeded from the SDK. Set it to an existing checkout's
`dispatcher/src`, for example the user's own AEM project repo. That directory must
already exist: `make dispatcher` never creates or seeds it, and `make uninstall` never
deletes it. Dispatcher binaries and tools always come from `SDK_DIR`.

Nothing is created at the project root.

## Skill and references

Task detail lives in `.claude/skills/stackisle/SKILL.md`: make targets, scripts,
architecture and common tasks. Read it for any task in this repo. Read a reference only
when the task needs it:

| File | Read when |
|------|-----------|
| `.claude/skills/stackisle/references/aem-concepts.md` | AEM architecture, run modes, OSGi, Sling, HTL |
| `.claude/skills/stackisle/references/dispatcher-config.md` | Editing vhost, farm, filters, cache rules, rewrites |
| `.claude/skills/stackisle/references/troubleshooting.md` | Any error, or a service that does not start or stop |
| `.claude/skills/stackisle/references/script-guide.md` | Understanding or changing a script, `update-etc-hosts.sh` or the Makefile |
