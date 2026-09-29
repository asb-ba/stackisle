#!/bin/bash
# ─────────────────────────────────────────────────────────────
# 01-unpack-sdk.sh
# Extract sdk/aem-sdk*.zip into sdk/aem-sdk-<version>/
# Result always has quickstart jar + dispatcher tools at depth 1.
# ─────────────────────────────────────────────────────────────

set -e
source "$(dirname "$0")/lib/common.sh"

step "Unpacking AEM SDK"

ZIP="$(sdk_zip)"

if [[ -z "$ZIP" ]]; then
  if [[ -n "$(quickstart_jar)" ]]; then
    ok "No zip, but SDK already unpacked at ${CYAN}$(sdk_dir)${RESET}"
    exit 0
  fi
  fail "No aem-sdk*.zip in $(rel "$SDK_DIR"). Download from https://experience.adobe.com/#/downloads"
fi

TARGET="${SDK_DIR}/$(basename "$ZIP" .zip)"

if [[ -n "$(find "$TARGET" -maxdepth 1 -name 'aem-sdk-quickstart-*.jar' 2>/dev/null)" ]]; then
  ok "Already unpacked: ${CYAN}$(rel "$TARGET")${RESET} (delete it to force re-unpack)"
  exit 0
fi

info "Extracting ${CYAN}$(rel "$ZIP")${RESET} → ${CYAN}$(rel "$TARGET")${RESET}"
mkdir -p "$TARGET"
unzip -oq "$ZIP" -d "$TARGET"

# Some zips wrap everything in an inner folder — flatten it
if [[ -z "$(find "$TARGET" -maxdepth 1 -name 'aem-sdk-quickstart-*.jar')" ]]; then
  INNER="$(find "$TARGET" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -n "$INNER" ]]; then
    mv "$INNER"/* "$TARGET"/ && rmdir "$INNER"
  fi
fi

JAR="$(find "$TARGET" -maxdepth 1 -name 'aem-sdk-quickstart-*.jar' | head -n 1)"
[[ -n "$JAR" ]] || fail "aem-sdk-quickstart-*.jar not found in ${TARGET} — is the zip an AEMaaCS SDK?"

ok "Quickstart jar : ${CYAN}$(rel "$JAR")${RESET}"
DT="$(find "$TARGET" -maxdepth 1 -name 'aem-sdk-dispatcher-tools-*-unix.sh' | head -n 1)"
[[ -n "$DT" ]] && ok "Dispatcher tools: ${CYAN}$(rel "$DT")${RESET}" \
               || warn "aem-sdk-dispatcher-tools-*-unix.sh not found in the SDK."
echo ""
