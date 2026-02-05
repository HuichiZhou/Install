#!/usr/bin/env bash
#
# Memento-S One-Click Installer (uv version)
# Usage: curl -sSL https://raw.githubusercontent.com/HuichiZhou/Memento-S/main/install.sh | bash
#        or: ./install.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
REPO_URL="https://github.com/HuichiZhou/Memento-S.git"
INSTALL_DIR="${MEMENTO_INSTALL_DIR:-$HOME/Memento-S}"

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                       ║"
    echo "║   ███╗   ███╗███████╗███╗   ███╗███████╗███╗   ██╗████████╗ ██████╗    ║"
    echo "║   ████╗ ████║██╔════╝████╗ ████║██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗   ║"
    echo "║   ██╔████╔██║█████╗  ██╔████╔██║█████╗  ██╔██╗ ██║   ██║   ██║   ██║   ║"
    echo "║   ██║╚██╔╝██║██╔══╝  ██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   ██║   ██║   ║"
    echo "║   ██║ ╚═╝ ██║███████╗██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   ╚██████╔╝   ║"
    echo "║   ╚═╝     ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝    ║"
    echo "║                           Memento-S                                   ║"
    echo "║                   One-Click Installer (uv)                            ║"
    echo "║                                                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_command() { command -v "$1" &> /dev/null; }

# Install uv if not present
install_uv() {
    if check_command uv; then
        log_success "uv: $(uv --version 2>&1)"
        return 0
    fi

    log_info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    if check_command uv; then
        log_success "uv installed: $(uv --version 2>&1)"
    else
        log_error "Failed to install uv. Please install manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
}

# Check if running from local project directory
is_local_install() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -f "$script_dir/tui.py" ] && [ -d "$script_dir/skills" ]
}

# Clone or update repository
setup_repository() {
    log_info "Setting up repository..."

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if is_local_install; then
        log_info "Detected local installation from: $script_dir"
        INSTALL_DIR="$script_dir"
        cd "$INSTALL_DIR"
        log_success "Using local directory: $INSTALL_DIR"
    elif [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Repository exists, updating..."
        cd "$INSTALL_DIR"
        git pull --rebase || log_warn "Git pull failed, continuing with existing code"
        log_success "Repository updated at $INSTALL_DIR"
    else
        log_info "Cloning repository to $INSTALL_DIR..."
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        log_success "Repository cloned to $INSTALL_DIR"
    fi
}

# Install dependencies using uv sync
install_dependencies() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}            Installing Dependencies (uv sync)                  ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    cd "$INSTALL_DIR"

    # Ensure Python 3.12 and sync dependencies
    log_info "Installing Python 3.12..."
    uv python install 3.12

    log_info "Running uv sync with Python 3.12..."
    uv sync --python 3.12

    log_success "Dependencies installed!"

    # Setup playwright/crawl4ai (optional)
    log_info "Setting up crawl4ai browser support..."
    uv run crawl4ai-setup 2>&1 | tail -5 || true
    log_info "Setting up Playwright chromium..."
    uv run python -m playwright install chromium 2>&1 | tail -5 || true
    log_success "Browser support setup completed"
}

# Install openskills and skills
install_skills() {
    # Load nvm if available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! check_command npm; then
        log_warn "npm not found. Skipping skills installation."
        log_warn "To install skills later: npm install -g openskills && openskills sync -y"
        return
    fi

    if ! check_command openskills; then
        log_info "Installing openskills..."
        npm install -g openskills 2>/dev/null || sudo npm install -g openskills 2>/dev/null || {
            log_warn "Failed to install openskills. Skipping skills."
            return
        }
    fi

    log_info "Installing skills..."
    cd "$INSTALL_DIR"

    for d in skills/*; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        if [ -d ".agent/skills/$name" ]; then
            openskills update "$name" 2>/dev/null || true
        else
            openskills install "./skills/$name" --universal --yes 2>/dev/null || true
        fi
    done

    openskills sync -y 2>/dev/null || true
    log_success "Skills installed"
}

# Create launcher script
create_launcher() {
    log_info "Creating launcher script..."

    LAUNCHER="$INSTALL_DIR/memento"
    cat > "$LAUNCHER" << 'EOF'
#!/usr/bin/env bash
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

cd "$SCRIPT_DIR"

# Use uv run - it handles venv automatically
if [ $# -eq 0 ]; then
    uv run python tui.py run
else
    uv run python tui.py "$@"
fi
EOF
    chmod +x "$LAUNCHER"

    # Create symlink
    if [ -w "/usr/local/bin" ]; then
        ln -sf "$LAUNCHER" /usr/local/bin/memento 2>/dev/null && log_success "Symlink: /usr/local/bin/memento"
    elif [ -d "/usr/local/bin" ]; then
        sudo ln -sf "$LAUNCHER" /usr/local/bin/memento 2>/dev/null && log_success "Symlink: /usr/local/bin/memento (sudo)"
    else
        mkdir -p "$HOME/.local/bin"
        ln -sf "$LAUNCHER" "$HOME/.local/bin/memento"
        add_to_path "$HOME/.local/bin"
    fi

    log_success "Launcher created: $LAUNCHER"
}

# Add directory to PATH
add_to_path() {
    local dir="$1"
    echo "$PATH" | grep -q "$dir" && return

    local shell_rc="$HOME/.zshrc"
    [ -f "$HOME/.bashrc" ] && [ "$SHELL" = *bash* ] && shell_rc="$HOME/.bashrc"

    if [ -f "$shell_rc" ] && ! grep -q "$dir" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# Added by Memento-S installer" >> "$shell_rc"
        echo "export PATH=\"$dir:\$PATH\"" >> "$shell_rc"
        log_success "Added to $shell_rc"
    fi

    export PATH="$dir:$PATH"
    log_warn "Restart terminal or run: source $shell_rc"
}

print_success() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                 Installation Complete!                        ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Install directory:${NC} $INSTALL_DIR"
    echo ""
    echo -e "  ${YELLOW}To start Memento-S:${NC}"
    echo ""
    echo -e "    ${GREEN}memento${NC}                  # Start TUI"
    echo -e "    ${GREEN}cd $INSTALL_DIR && uv run python tui.py run${NC}"
    echo ""
    echo -e "  ${CYAN}Other commands:${NC}"
    echo -e "    memento doctor   - Check configuration"
    echo -e "    memento config   - Show current config"
    echo -e "    memento --help   - Show all commands"
    echo ""
    echo -e "  ${YELLOW}Note:${NC} If 'memento' not found, restart terminal or run:"
    echo -e "        ${CYAN}source ~/.zshrc${NC} (or ~/.bashrc)"
    echo ""
}

# Main
main() {
    print_banner

    # Check git
    if ! check_command git; then
        log_error "git is required. Please install git first."
        exit 1
    fi

    install_uv
    setup_repository
    install_dependencies
    install_skills
    create_launcher
    print_success
}

main "$@"
