#!/bin/bash
#
# Memento-S Uninstaller
# Usage: curl -sSL https://raw.githubusercontent.com/HuichiZhou/Install/main/uninstall.sh | bash
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="${MEMENTO_INSTALL_DIR:-$HOME/Memento-S}"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                 Memento-S Uninstaller                         ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Confirm uninstall
read -p "Are you sure you want to uninstall Memento-S? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Uninstall cancelled.${NC}"
    exit 0
fi

echo ""

# Remove symlinks
if [ -L "/usr/local/bin/memento" ]; then
    echo -e "${YELLOW}Removing /usr/local/bin/memento...${NC}"
    sudo rm -f /usr/local/bin/memento 2>/dev/null || rm -f /usr/local/bin/memento
fi

if [ -L "$HOME/.local/bin/memento" ]; then
    echo -e "${YELLOW}Removing ~/.local/bin/memento...${NC}"
    rm -f "$HOME/.local/bin/memento"
fi

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Removing $INSTALL_DIR...${NC}"
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}[OK]${NC} Installation directory removed"
else
    echo -e "${YELLOW}[WARN]${NC} Installation directory not found: $INSTALL_DIR"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           Memento-S uninstalled successfully!                 ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
