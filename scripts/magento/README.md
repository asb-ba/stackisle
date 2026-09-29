# Magento test stack

Magento (Open Source or Adobe Commerce) installed with Composer, served at
**https://dev-local-mc.brand.com** through the shared `aem-nginx` SSL proxy.

> **Test stack.** It isn't wired into the Makefile or `make` yet. It uses its own
> config file, compose project, cert, nginx file and hosts tag, so the AEM
> scripts never touch it. Once tested, it moves to `mk/magento.mk`.

```
Browser → https://dev-local-mc.brand.com
  [aem-nginx]  (shared, SSL, INSTALL_DIR/certs/magento.crt)
    → http://magento-web:80          (Docker network aem-local-net)
      [magento-web]  nginx + Magento's nginx.conf.sample
        → magento-php:9000   PHP-FPM + Composer (runs as your UID)
            → magento-db (MariaDB) · magento-search (OpenSearch) · magento-cache (Redis)
```

No Magento port is published on the host. The only way in is https through `aem-nginx`.

## Files

| File | Purpose |
|---|---|
| `magento.sh` | the script: `check build up create install ssl status` … |
| `magento.env.example` | config template → copy to `magento.env` (gitignored, holds keys) |
| `docker-compose.yml` | compose project `stackisle-magento` |
| `php/Dockerfile`, `php/zz-magento.ini` | PHP-FPM image with Magento's extensions + Composer |
| `web/default.conf` | Magento web server (includes Magento's `nginx.conf.sample`) |

What it creates:

| Where | What |
|---|---|
| `INSTALL_DIR/magento/src/` | Magento code (owned by you) |
| `INSTALL_DIR/magento/admin-credentials.txt` | admin URL/user/password (mode 600) |
| `INSTALL_DIR/certs/magento.crt` / `.key` | cert for the domain (`server.crt` untouched) |
| `INSTALL_DIR/nginx/conf.d/zz-magento-<domain>.conf` | server block loaded by `aem-nginx` |
| hosts file | `127.0.0.1 dev-local-mc.brand.com # stackisle-magento` |
| Docker | containers `magento-*`, volumes `stackisle-magento-*`, network `stackisle-magento`, image `stackisle/magento-php:<php>` |

## Before you start

- The AEM stack's `aem-nginx` and `aem-dispatcher` are running (they provide network `aem-local-net` and port 443).
- **repo.magento.com access keys:** https://commercemarketplace.adobe.com → My Profile → Access Keys.
- Disk: about 3–4 GB (code, images, database, search index).

## Step by step

All commands run from the project root.

```bash
# M1 — config
cp scripts/magento/magento.env.example scripts/magento/magento.env
#      edit: MAGENTO_PUBLIC_KEY, MAGENTO_PRIVATE_KEY (and edition/version if needed)

bash scripts/magento/magento.sh check     # M2 — prerequisites (changes nothing)
bash scripts/magento/magento.sh build     # M3 — build PHP image (few minutes)
bash scripts/magento/magento.sh up        # M4 — db, search, cache, php (waits until healthy)
bash scripts/magento/magento.sh create    # M5 — composer create-project (several minutes)
bash scripts/magento/magento.sh install   # M6 — setup:install, dev mode, 2FA off, start web
bash scripts/magento/magento.sh ssl       # M7 — cert + aem-nginx block + hosts (sudo)
bash scripts/magento/magento.sh status    # M8 — containers + HTTPS check
```

Or run everything at once: `bash scripts/magento/magento.sh all`

Each step is safe to re-run. `create` skips if the code exists, `install`
skips if `app/etc/env.php` exists, and `ssl` keeps a cert that already matches.

**Check after M8:**
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://dev-local-mc.brand.com/      # 200
cat sdk/magento/admin-credentials.txt                                        # admin login
make health                                                                  # AEM stack still all green
```
Then open https://dev-local-mc.brand.com/ and https://dev-local-mc.brand.com/admin.

## Day to day

```bash
bash scripts/magento/magento.sh start | stop          # stop is graceful (db/search: 2 min grace)
bash scripts/magento/magento.sh logs [db|search|cache|php|web]
bash scripts/magento/magento.sh shell                 # bash as www-data in /var/www/html
bash scripts/magento/magento.sh magento cache:flush   # any bin/magento command
bash scripts/magento/magento.sh composer require vendor/module   # keys passed automatically
```

## How it stays out of the AEM stack's way

- **aem-nginx** resolves `magento-web` per request (Docker DNS resolver), so it
  still starts and serves the AEM sites when Magento is stopped. Magento requests
  then return 502.
- **If `aem-nginx` rejects the Magento config**, `ssl` removes it again, so the AEM sites are unaffected.
- **Separate markers and tags:** `make nginx`, `make hosts-remove`, `make clean`
  and `make uninstall` only touch AEM-tagged files, never Magento's.

## Undo

```bash
bash scripts/magento/magento.sh uninstall
```

It asks for `yes`, stops gracefully, then removes the containers, volumes, PHP
image, nginx block (and reloads `aem-nginx`), cert and hosts entry (backup
`/etc/hosts.stackisle-magento.bak`). It asks separately before deleting the code
in `src/`. Pulled images (MariaDB, OpenSearch, Redis) are kept; remove them with `docker rmi` if you want.

## To verify on first run

These were set from Adobe's published requirements for 2.4.8 without a test run
here. Adjust `magento.env` if Composer or `setup:install` complains:
- PHP 8.3, MariaDB 11.4, OpenSearch 2.19, Redis 7.2 and Composer 2.8 for Magento 2.4.8
- `--opensearch-*` and `--*-redis-*` options of `setup:install`
- OpenSearch memory: raise `MAGENTO_OPENSEARCH_HEAP` if the `search` container restarts
