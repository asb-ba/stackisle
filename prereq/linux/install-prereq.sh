#!/bin/bash
# ─────────────────────────────────────────────────────────────
# prereq/linux/install-prereq.sh
# Install prerequisites on Linux (apt: Debian/Ubuntu, dnf: Fedora/RHEL)
# Order: base tools → Java (JAVA_REQUIRED, default 21) → Docker + compose → mkcert (optional)
# nginx runs in a container — no host install needed.
# ─────────────────────────────────────────────────────────────

set -e

# Java major version to install — follows JAVA_REQUIRED in .env (SDK 2026.x needs 21)
ENV_FILE="$(dirname "$0")/../../.env"
JREQ="$(sed -n 's/^JAVA_REQUIRED=["]*\([0-9]*\).*/\1/p' "$ENV_FILE" 2>/dev/null | tail -1)"
JREQ="${JREQ:-21}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
PASS="${GREEN}✔${RESET}"; SKIP="${YELLOW}→${RESET}"

ask() { read -rp "  Install $1? (y/n): " ans; [[ "$ans" =~ ^[Yy]$ ]]; }

if   command -v apt-get &>/dev/null; then PM=apt
elif command -v dnf     &>/dev/null; then PM=dnf
else echo -e "  ${RED}✘ Neither apt-get nor dnf found — install manually.${RESET}"; exit 1; fi

pkg_install() {
  if [[ "$PM" == apt ]]; then sudo apt-get install -y "$@"; else sudo dnf install -y "$@"; fi
}

case "$(uname -m)" in aarch64|arm64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac

echo ""
echo -e "  ${BOLD}Linux Prerequisite Installer (${PM})${RESET}"
echo ""

[[ "$PM" == apt ]] && sudo apt-get update -qq

# ── 1. Base tools ────────────────────────────────────────────
echo -e "  ${BOLD}[1/4] curl, unzip, openssl, make${RESET}"
MISSING=()
for c in curl unzip openssl make; do command -v "$c" &>/dev/null || MISSING+=("$c"); done
if (( ${#MISSING[@]} )); then
  pkg_install "${MISSING[@]}"; echo -e "  ${PASS} Installed: ${MISSING[*]}"
else
  echo -e "  ${SKIP} Already installed."
fi

# ── 2. Java 17 ───────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}[2/4] Java ${JREQ}+${RESET}"
JV=$(java -version 2>&1 | awk -F '"' '/version/ {print $2; exit}' | sed 's/^1\.//' | cut -d. -f1)
if [[ -n "$JV" && "$JV" -ge "$JREQ" ]]; then
  echo -e "  ${SKIP} Java ${JV} already installed."
else
  [[ -n "$JV" ]] && echo -e "  ${YELLOW}! Java ${JV} found — ${JREQ}+ required.${RESET}"
  if ask "Java ${JREQ} (OpenJDK)"; then
    if [[ "$PM" == apt ]]; then pkg_install "openjdk-${JREQ}-jdk"; else pkg_install "java-${JREQ}-openjdk-devel"; fi
    echo -e "  ${PASS} Java ${JREQ} installed."
    echo -e "  ${YELLOW}  Set in .env: JAVA_HOME=\"$(ls -d /usr/lib/jvm/java-${JREQ}-openjdk-* 2>/dev/null | head -1)\"${RESET}"
    echo -e "  ${YELLOW}  (or make it the default: sudo update-alternatives --config java)${RESET}"
  fi
fi

# ── 3. Docker + compose plugin ───────────────────────────────
echo ""
echo -e "  ${BOLD}[3/4] Docker + compose v2${RESET}"
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  echo -e "  ${SKIP} Docker $(docker --version | awk '{print $3}' | tr -d ,) with compose already installed."
elif ask "Docker Engine + compose plugin (get.docker.com)"; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  sudo systemctl enable --now docker
  echo -e "  ${PASS} Docker installed. Log out/in (or run 'newgrp docker') to use without sudo."
fi

# ── 4. mkcert (optional, trusted certs) ──────────────────────
echo ""
echo -e "  ${BOLD}[4/4] mkcert (optional — browser-trusted certs)${RESET}"
if command -v mkcert &>/dev/null; then
  echo -e "  ${SKIP} mkcert already installed."
  mkcert -install
elif ask "mkcert"; then
  if [[ "$PM" == apt ]]; then pkg_install libnss3-tools; else pkg_install nss-tools; fi
  curl -fsSL -o /tmp/mkcert "https://dl.filippo.io/mkcert/latest?for=linux/${ARCH}"
  sudo install -m 0755 /tmp/mkcert /usr/local/bin/mkcert && rm -f /tmp/mkcert
  mkcert -install
  echo -e "  ${PASS} mkcert installed and local CA trusted."
fi

echo ""
echo -e "  Versions:"
echo -e "    Java   : ${CYAN}$(java -version 2>&1 | head -1)${RESET}"
echo -e "    Docker : ${CYAN}$(docker --version 2>/dev/null)${RESET}"
echo -e "    Compose: ${CYAN}$(docker compose version --short 2>/dev/null)${RESET}"
echo -e "    mkcert : ${CYAN}$(mkcert -version 2>/dev/null || echo 'not installed')${RESET}"
echo ""
echo -e "  Next: ${CYAN}make${RESET}"
echo ""
