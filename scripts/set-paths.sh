#!/bin/bash
# ─────────────────────────────────────────────────────────────
# scripts/set-paths.sh <SDK_DIR> <INSTALL_DIR>      (make set-paths)
# Write SDK_DIR and/or INSTALL_DIR into .env, then show the resulting layout.
# Either value may be empty = leave that one unchanged.
#   make set-paths INSTALL_DIR=/opt/aem
#   make set-paths SDK_DIR=~/Downloads/aem-sdk INSTALL_DIR=./sdk
# Nothing is moved: an existing install stays where it is (warning shown).
# ─────────────────────────────────────────────────────────────

set -e
NEW_SDK_DIR="$1"
NEW_INSTALL_DIR="$2"

source "$(dirname "$0")/lib/common.sh"     # loads the current .env (old values)

[[ -n "$NEW_SDK_DIR" || -n "$NEW_INSTALL_DIR" ]] || fail "Nothing to set.
       Usage: make set-paths SDK_DIR=<path> INSTALL_DIR=<path>   (either or both)
       Show current layout: make paths"

ENV_FILE="$ROOT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT_DIR/.env.example" "$ENV_FILE"
  ok "Created .env from .env.example"
fi

OLD_AUTHOR_DIR="$AUTHOR_DIR"; OLD_SDK_DIR="$SDK_DIR"; OLD_INSTALL_DIR="$INSTALL_DIR"

# set_var NAME VALUE — replace the NAME= line in .env (keeps any trailing comment),
# or append it. awk + temp file instead of `sed -i` (differs between GNU and BSD/macOS).
set_var() {
  local name="$1" value="$2" tmp
  tmp="$(mktemp)"
  awk -v n="$name" -v v="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" n "=" {
      c = ""; if (match($0, /[[:space:]]+#.*$/)) c = substr($0, RSTART)
      print n "=\"" v "\"" c; done = 1; next
    }
    { print }
    END { if (!done) print n "=\"" v "\"" }
  ' "$ENV_FILE" > "$tmp"
  cat "$tmp" > "$ENV_FILE"      # keep the file's permissions/owner
  rm -f "$tmp"
  ok "${name}=\"${value}\"  → .env"
}

step "Updating paths in .env"
[[ -n "$NEW_SDK_DIR" ]]     && set_var SDK_DIR "$NEW_SDK_DIR"
[[ -n "$NEW_INSTALL_DIR" ]] && set_var INSTALL_DIR "$NEW_INSTALL_DIR"

# Show the new layout (fresh shell = re-reads .env)
echo ""
bash -c "source '$ROOT_DIR/scripts/lib/common.sh'; for v in \$INSTALL_PATH_VARS; do printf '  %-19s %s\n' \"\$v\" \"\${!v}\"; done"

# Warn about an existing install that is NOT moved
NEW_AUTHOR_DIR="$(bash -c "source '$ROOT_DIR/scripts/lib/common.sh'; echo \"\$AUTHOR_DIR\"")"
if [[ "$NEW_AUTHOR_DIR" != "$OLD_AUTHOR_DIR" && -d "$OLD_AUTHOR_DIR/crx-quickstart" ]]; then
  echo ""
  warn "An existing install is still in the old location — nothing was moved:"
  info "old INSTALL_DIR: ${OLD_INSTALL_DIR}"
  info "Either: make stop, move the folders yourself, then continue"
  info "    or: set the old path back, make uninstall, set the new path, make"
fi
NEW_SDK_ABS="$(bash -c "source '$ROOT_DIR/scripts/lib/common.sh'; echo \"\$SDK_DIR\"")"
if [[ "$NEW_SDK_ABS" != "$OLD_SDK_DIR" && -n "$(find -L "$OLD_SDK_DIR" -maxdepth 1 -name 'aem-sdk*.zip' 2>/dev/null)" ]]; then
  warn "The SDK zip is still in ${OLD_SDK_DIR} — copy it into the new SDK_DIR."
fi

echo ""
info "Next: ${CYAN}make prereq${RESET} (checks the new paths are writable)"
echo ""
