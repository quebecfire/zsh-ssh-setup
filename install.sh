#!/bin/bash
# ==============================================================================
# install.sh — Auto-install zsh-ssh-setup into oh-my-zsh
#
# Usage:
#   git clone <repo> ~/repos/zsh-ssh-setup
#   ~/repos/zsh-ssh-setup/install.sh
#
# What it does:
#   1. Symlinks the plugin into ~/.oh-my-zsh/custom/plugins/
#   2. Adds 'zsh-ssh-setup' to the plugins=() line in ~/.zshrc
#   3. Explains every step so you learn the commands
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

PLUGIN_NAME="zsh-ssh-setup"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMZ_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
TARGET="$OMZ_CUSTOM/plugins/$PLUGIN_NAME"
ZSHRC="$HOME/.zshrc"

echo ""
echo -e "${BOLD}zsh-ssh-setup installer${NC}"
echo -e "${BOLD}══════════════════════${NC}"
echo ""

# --- Step 1: Ensure plugin is in oh-my-zsh custom plugins ---
echo -e "${CYAN}Step 1: Link plugin into oh-my-zsh${NC}"
echo ""

if [[ "$PLUGIN_DIR" == "$TARGET" ]]; then
    # Cloned directly into custom plugins — nothing to do
    echo -e "  ${GREEN}✓${NC} Already in oh-my-zsh custom plugins (cloned directly)"
elif [[ -L "$TARGET" ]]; then
    echo -e "  ${GREEN}✓${NC} Symlink already exists: $TARGET → $(readlink "$TARGET")"
elif [[ -d "$TARGET" ]]; then
    echo -e "  ${YELLOW}!${NC} Directory already exists at $TARGET (not a symlink)"
    echo "  Remove it first if you want a symlink: rm -rf $TARGET"
    exit 1
else
    echo -e "  ${BOLD}Running:${NC}"
    echo -e "    ln -s $PLUGIN_DIR $TARGET"
    echo ""
    echo -e "  ${BOLD}What this does:${NC}"
    echo "    Creates a symbolic link so oh-my-zsh can find the plugin"
    echo "    without moving it from where you cloned it."
    echo ""
    ln -s "$PLUGIN_DIR" "$TARGET"
    echo -e "  ${GREEN}✓${NC} Symlinked: $TARGET → $PLUGIN_DIR"
fi

echo ""

# --- Step 2: Add to plugins in .zshrc ---
echo -e "${CYAN}Step 2: Add '$PLUGIN_NAME' to plugins in ~/.zshrc${NC}"
echo ""

if ! [[ -f "$ZSHRC" ]]; then
    echo -e "  ${RED}✗${NC} No ~/.zshrc found. Are you using oh-my-zsh?"
    exit 1
fi

if grep -q "^plugins=.*$PLUGIN_NAME" "$ZSHRC"; then
    echo -e "  ${GREEN}✓${NC} Already in plugins list"
else
    echo -e "  ${BOLD}Running:${NC}"
    echo -e "    sed -i '/^plugins=/ s/)/ $PLUGIN_NAME)/' ~/.zshrc"
    echo ""
    echo -e "  ${BOLD}What this does:${NC}"
    echo "    /^plugins=/    → find the line starting with plugins="
    echo "    s/)/ $PLUGIN_NAME)/  → insert '$PLUGIN_NAME' before the closing )"
    echo ""

    sed -i "/^plugins=/ s/)/ $PLUGIN_NAME)/" "$ZSHRC"

    echo -e "  ${GREEN}✓${NC} Added. Your plugins line is now:"
    echo -e "    $(grep "^plugins=" "$ZSHRC")"
fi

echo ""

# --- Step 3: Done ---
echo -e "${CYAN}Step 3: Reload your shell${NC}"
echo ""
echo "  Run:"
echo -e "    ${BOLD}source ~/.zshrc${NC}"
echo ""
echo "  Then try:"
echo -e "    ${BOLD}ssh-info${NC}        — check your current key"
echo -e "    ${BOLD}ssh-gen${NC}         — generate a new key for this machine"
echo -e "    ${BOLD}ssh-pub${NC}         — print your public key"
echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
