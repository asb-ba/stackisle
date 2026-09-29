#!/bin/bash
# ─────────────────────────────────────────────────────────────
# 00-check-prereq.sh
# Verify every prerequisite before anything else runs.
# Missing tools → offers to run the platform installer in prereq/<os>/.
# ─────────────────────────────────────────────────────────────

set -e
source "$(dirname "$0")/lib/common.sh"

MISSING=()

need() {  # need <label> <cmd> [version-cmd]
  if command -v "$2" &>/dev/null; then
    ok "$1 ${CYAN}$( ${3:-true} 2>&1 | head -1 )${RESET}"
  else
    echo -e "  ${RED}✘${RESET} $1 not found"
    MISSING+=("$1")
  fi
}

step "Checking prerequisites (platform: ${CYAN}${OS}${RESET}${BOLD})"

# ── Prereq installers present for this platform ──────────────
case "$OS" in
  mac)     INSTALLER="prereq/mac/install-prereq.sh" ;;
  linux)   INSTALLER="prereq/linux/install-prereq.sh" ;;
  windows) INSTALLER="prereq/windows/install-prereq.ps1" ;;
  *)       INSTALLER="" ; warn "Unknown platform '$OSTYPE' — continuing with checks only." ;;
esac
if [[ -n "$INSTALLER" ]]; then
  [[ -f "$INSTALLER" ]] && ok "Installer present: ${CYAN}${INSTALLER}${RESET}" \
                        || fail "Installer missing: ${INSTALLER}"
fi

# ── Tools ────────────────────────────────────────────────────
need "curl"    curl    "curl --version"
need "unzip"   unzip   "unzip -v"
need "openssl" openssl "openssl version"
need "Docker"  docker  "docker --version"

if command -v java &>/dev/null; then
  JV="$(java_major)"
  if [[ "$JV" -ge "$JAVA_REQUIRED" ]] 2>/dev/null; then
    ok "Java ${CYAN}$(java -version 2>&1 | head -1)${RESET}"
  else
    echo -e "  ${RED}✘${RESET} Java ${JV} found — Java ${JAVA_REQUIRED}+ is required"
    info "Set JAVA_HOME in .env to a Java ${JAVA_REQUIRED}+ install, or install one."
    MISSING+=("Java ${JAVA_REQUIRED}+")
  fi
else
  echo -e "  ${RED}✘${RESET} Java not found"
  MISSING+=("Java ${JAVA_REQUIRED}+")
fi

if command -v mkcert &>/dev/null; then
  ok "mkcert ${CYAN}$(mkcert -version 2>&1)${RESET} (browser-trusted certs)"
else
  warn "mkcert not found — certs will be self-signed via openssl (browser warning)."
fi

# ── Docker daemon + compose v2 ───────────────────────────────
if command -v docker &>/dev/null; then
  if docker info &>/dev/null; then
    ok "Docker daemon running"
  else
    echo -e "  ${RED}✘${RESET} Docker daemon not running (or no permission — add user to 'docker' group)"
    MISSING+=("Docker daemon")
  fi
  if docker compose version &>/dev/null; then
    ok "Docker Compose ${CYAN}$(docker compose version --short 2>/dev/null)${RESET}"
  else
    echo -e "  ${RED}✘${RESET} Docker Compose v2 plugin not found"
    MISSING+=("docker compose")
  fi
fi

# ── Offer platform installer ─────────────────────────────────
if (( ${#MISSING[@]} )); then
  echo ""
  warn "Missing: ${MISSING[*]}"
  if [[ -t 0 && -n "$INSTALLER" && "$OS" != "windows" ]]; then
    read -rp "  Run ${INSTALLER} now? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      bash "$INSTALLER"
      echo ""
      info "Re-run ${CYAN}make${RESET} (open a new shell if PATH/groups changed)."
    fi
  elif [[ "$OS" == "windows" ]]; then
    info "Run in an Admin PowerShell: ${CYAN}powershell -File ${INSTALLER}${RESET}"
  else
    info "Run: ${CYAN}make install-prereq${RESET}"
  fi
  exit 1
fi

# ── Project inputs ───────────────────────────────────────────
step "Checking project inputs"

if [[ -f .env ]]; then
  ok ".env present"
else
  warn ".env not found — using defaults (run ${CYAN}make env${RESET}${YELLOW} to create one)."
fi
info "Domains: ${CYAN}${CUSTOM_DOMAINS}${RESET}"

ZIP="$(sdk_zip)"
if [[ -n "$ZIP" ]]; then
  ok "AEM SDK zip: ${CYAN}${ZIP}${RESET}"
elif [[ -n "$(sdk_dir)" ]]; then
  ok "AEM SDK already unpacked: ${CYAN}$(sdk_dir)${RESET}"
else
  fail "No SDK found. Download the AEM SDK from https://experience.adobe.com/#/downloads
       and place it at: $(rel "$SDK_DIR")/aem-sdk-<version>.zip"
fi

# ── Install paths writable ──────────────────────────────────
step "Checking install paths (.env)"
for v in $INSTALL_PATH_VARS; do
  d="${!v}"; e="$d"
  while [[ ! -e "$e" ]]; do e="$(dirname "$e")"; done   # nearest existing ancestor
  if [[ -w "$e" ]]; then
    ok "$(printf '%-19s' "$v") ${CYAN}$(rel "$d")${RESET}"
  else
    echo -e "  ${RED}✘${RESET} $(printf '%-19s' "$v") ${d} — not writable"
    info "fix: ${CYAN}sudo mkdir -p ${d} && sudo chown -R \$USER ${d}${RESET}"
    MISSING+=("$v")
  fi
done
(( ${#MISSING[@]} )) && fail "Install paths not writable: ${MISSING[*]}"

echo ""
echo -e "  ${GREEN}${BOLD}All prerequisites satisfied.${RESET}"
echo ""
