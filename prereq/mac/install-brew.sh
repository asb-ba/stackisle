#!/bin/bash
# ─────────────────────────────────────────────────────────────
# prereq/mac/install-brew.sh
# Install Homebrew on macOS if not already installed
# ─────────────────────────────────────────────────────────────

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

echo ""
echo -e "  ${BOLD}Checking Homebrew...${RESET}"

if command -v brew &>/dev/null; then
  echo -e "  ${GREEN}✔ Homebrew already installed: $(brew --version | head -1)${RESET}"
  exit 0
fi

echo -e "  ${YELLOW}! Homebrew not found.${RESET}"
read -rp "  Install Homebrew now? (y/n): " answer
if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
  echo "  Skipped. Homebrew is required to continue."
  exit 1
fi

echo "  Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH for Apple Silicon
if [[ -f /opt/homebrew/bin/brew ]]; then
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo -e "  ${GREEN}✔ Homebrew installed.${RESET}"
