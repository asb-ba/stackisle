#!/bin/bash
# ─────────────────────────────────────────────────────────────
# prereq/mac/install-prereq.sh
# Install prerequisites on macOS via Homebrew
# Order: Homebrew → Java (JAVA_REQUIRED, default 21) → Docker Desktop → mkcert (optional)
# nginx runs in a container — no host install needed.
# curl, unzip, openssl, make ship with macOS / Xcode CLT.
# ─────────────────────────────────────────────────────────────

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
PASS="${GREEN}✔${RESET}"; SKIP="${YELLOW}→${RESET}"

ask() { read -rp "  Install $1? (y/n): " ans; [[ "$ans" =~ ^[Yy]$ ]]; }

echo ""
echo -e "  ${BOLD}macOS Prerequisite Installer${RESET}"
echo ""

# ── 1. Homebrew ──────────────────────────────────────────────
echo -e "  ${BOLD}[1/4] Homebrew${RESET}"
bash "$(dirname "$0")/install-brew.sh"
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

# ── 2. Java (JAVA_REQUIRED from .env, default 21) ────────────
ENV_FILE="$(dirname "$0")/../../.env"
JREQ="$(sed -n 's/^JAVA_REQUIRED=["]*\([0-9]*\).*/\1/p' "$ENV_FILE" 2>/dev/null | tail -1)"
JREQ="${JREQ:-21}"
echo ""
echo -e "  ${BOLD}[2/4] Java ${JREQ}+${RESET}"
JV=$(java -version 2>&1 | awk -F '"' '/version/ {print $2; exit}' | sed 's/^1\.//' | cut -d. -f1)
if [[ -n "$JV" && "$JV" -ge "$JREQ" ]] 2>/dev/null; then
  echo -e "  ${SKIP} Java ${JV} already installed."
else
  [[ -n "$JV" ]] && echo -e "  ${YELLOW}! Java ${JV} found — ${JREQ}+ required.${RESET}"
  if ask "Java ${JREQ} (Temurin)"; then
    brew install --cask "temurin@${JREQ}"
    echo -e "  ${PASS} Java ${JREQ} installed."
    echo -e "  ${YELLOW}  Set in .env: JAVA_HOME=\"$(/usr/libexec/java_home -v "${JREQ}" 2>/dev/null)\"${RESET}"
  fi
fi

# ── 3. Docker Desktop ────────────────────────────────────────
echo ""
echo -e "  ${BOLD}[3/4] Docker Desktop${RESET}"
if command -v docker &>/dev/null; then
  echo -e "  ${SKIP} Docker already installed."
elif ask "Docker Desktop"; then
  brew install --cask docker
  echo -e "  ${PASS} Docker Desktop installed."
fi
if ! docker info &>/dev/null; then
  echo -e "  Starting Docker Desktop..."
  open -a Docker || true
  for _ in $(seq 1 40); do docker info &>/dev/null && break; sleep 3; done
  docker info &>/dev/null && echo -e "  ${PASS} Docker running." \
                          || echo -e "  ${RED}✘ Docker not ready yet — finish Docker Desktop setup, then re-run make.${RESET}"
fi

# ── 4. mkcert (optional) ─────────────────────────────────────
echo ""
echo -e "  ${BOLD}[4/4] mkcert (optional — browser-trusted certs)${RESET}"
if command -v mkcert &>/dev/null; then
  echo -e "  ${SKIP} mkcert already installed."
  mkcert -install
elif ask "mkcert"; then
  brew install mkcert nss
  mkcert -install
  echo -e "  ${PASS} mkcert installed and local CA trusted."
fi

echo ""
echo -e "  Versions:"
echo -e "    Java   : ${CYAN}$(java -version 2>&1 | head -1)${RESET}"
echo -e "    Docker : ${CYAN}$(docker --version 2>/dev/null)${RESET}"
echo -e "    mkcert : ${CYAN}$(mkcert -version 2>/dev/null || echo 'not installed')${RESET}"
echo ""
echo -e "  Next: ${CYAN}make${RESET}"
echo ""
