#!/usr/bin/env bash
#
# Memento-S One-Click Installer
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
NC='\033[0m' # No Color

# Config
REPO_URL="https://github.com/HuichiZhou/Memento-S.git"
INSTALL_DIR="${MEMENTO_INSTALL_DIR:-$HOME/Memento-S}"
ENV_FILE="$INSTALL_DIR/.env"

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
    echo "║                      One-Click Installer                              ║"
    echo "║                                                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Python
    if check_command python3; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        log_success "Python: $PYTHON_VERSION"
    else
        log_error "Python 3 is required. Please install Python 3.10+"
        exit 1
    fi

    # Check pip
    if check_command pip3 || check_command pip; then
        log_success "pip: installed"
    else
        log_error "pip is required. Please install pip"
        exit 1
    fi

    # Check git
    if check_command git; then
        log_success "git: installed"
    else
        log_error "git is required. Please install git"
        exit 1
    fi

    # Check cmake (needed for llvmlite/numba)
    if check_command cmake; then
        CMAKE_VERSION=$(cmake --version 2>&1 | head -n1)
        log_success "cmake: $CMAKE_VERSION"
    else
        log_warn "cmake not found. Installing (required for llvmlite)..."
        install_cmake
    fi

    # Load nvm if available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Check npm and Node.js version (need Node.js 20+)
    if check_command npm && check_command node; then
        NODE_VERSION=$(node --version 2>&1 | sed 's/v//')
        NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
        NPM_VERSION=$(npm --version 2>&1)

        if [ "$NODE_MAJOR" -ge 20 ] 2>/dev/null; then
            log_success "Node.js: v$NODE_VERSION (npm: $NPM_VERSION)"
        else
            log_warn "Node.js $NODE_VERSION found, but version 20+ is required."
            log_info "Installing Node.js 20 via nvm..."
            install_nodejs
        fi
    else
        log_warn "Node.js/npm not found. Installing Node.js 20 via nvm..."
        install_nodejs
    fi

    # Check openskills and install if needed
    if check_command openskills; then
        log_success "openskills: installed"
        HAS_OPENSKILLS=true
    else
        log_info "openskills not found. Installing..."
        install_openskills
    fi
}

# Install cmake (needed for llvmlite/numba)
install_cmake() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if check_command brew; then
            log_info "Installing cmake via Homebrew..."
            brew install cmake
        else
            log_error "Homebrew not found. Please install cmake manually:"
            log_error "  brew install cmake"
            log_error "  or visit: https://cmake.org/download/"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if check_command apt-get; then
            log_info "Installing cmake via apt..."
            sudo apt-get update && sudo apt-get install -y cmake
        elif check_command yum; then
            log_info "Installing cmake via yum..."
            sudo yum install -y cmake
        elif check_command dnf; then
            log_info "Installing cmake via dnf..."
            sudo dnf install -y cmake
        elif check_command pacman; then
            log_info "Installing cmake via pacman..."
            sudo pacman -S --noconfirm cmake
        else
            log_error "Could not detect package manager. Please install cmake manually:"
            log_error "  Visit: https://cmake.org/download/"
            exit 1
        fi
    else
        log_error "Unsupported OS. Please install cmake manually:"
        log_error "  Visit: https://cmake.org/download/"
        exit 1
    fi

    if check_command cmake; then
        log_success "cmake installed successfully"
    else
        log_error "Failed to install cmake"
        exit 1
    fi
}

# Install nvm (Node Version Manager)
install_nvm() {
    log_info "Installing nvm (Node Version Manager)..."

    # Download and install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    # Load nvm into current shell
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    if command -v nvm &> /dev/null; then
        log_success "nvm installed successfully"
        return 0
    else
        log_error "Failed to install nvm"
        return 1
    fi
}

# Install Node.js (for npm) via nvm
install_nodejs() {
    # First, try to load existing nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Check if nvm is available, install if not
    if ! command -v nvm &> /dev/null; then
        log_info "nvm not found. Installing nvm first..."
        if ! install_nvm; then
            log_error "Failed to install nvm. Please install Node.js 20 manually:"
            log_error "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
            log_error "  nvm install 20"
            HAS_OPENSKILLS=false
            return
        fi
    fi

    # Install Node.js 20 via nvm
    log_info "Installing Node.js 20 via nvm..."
    nvm install 20
    nvm use 20
    nvm alias default 20

    if check_command npm; then
        NODE_VERSION=$(node --version 2>&1)
        log_success "Node.js $NODE_VERSION installed successfully via nvm"
    else
        log_error "Failed to install Node.js"
        HAS_OPENSKILLS=false
    fi
}

# Install openskills via npm
install_openskills() {
    if ! check_command npm; then
        log_warn "npm not available. Skipping openskills installation."
        HAS_OPENSKILLS=false
        return
    fi

    log_info "Installing openskills globally via npm..."
    npm install -g openskills 2>/dev/null || {
        log_warn "Global install failed, trying with sudo..."
        sudo npm install -g openskills 2>/dev/null || {
            log_error "Failed to install openskills. You can install it manually with:"
            log_error "  npm install -g openskills"
            HAS_OPENSKILLS=false
            return
        }
    }

    if check_command openskills; then
        log_success "openskills installed successfully"
        HAS_OPENSKILLS=true
    else
        log_warn "openskills command not found after installation"
        HAS_OPENSKILLS=false
    fi
}

# Clone or update repository
setup_repository() {
    log_info "Setting up repository..."

    if [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Repository exists, updating..."
        cd "$INSTALL_DIR"
        git pull --rebase || {
            log_warn "Git pull failed, continuing with existing code"
        }
    else
        log_info "Cloning repository to $INSTALL_DIR..."
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    log_success "Repository ready at $INSTALL_DIR"
}

# Progress bar helper
# Usage: show_progress "Task name" current total
show_progress() {
    local task="$1"
    local current="$2"
    local total="$3"
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    # Print progress bar (overwrite same line)
    printf "\r  ${CYAN}[%s]${NC} %3d%% ${YELLOW}%s${NC}" "$bar" "$percent" "$task"

    # New line when complete
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Install a package with progress update
install_with_progress() {
    local pkg="$1"
    local current="$2"
    local total="$3"
    local extra_args="${4:-}"

    show_progress "$pkg" "$current" "$total"
    if [ -n "$extra_args" ]; then
        pip install $extra_args "$pkg" -q 2>/dev/null || pip install "$pkg" -q
    else
        pip install "$pkg" -q
    fi
}

# Install Python dependencies
install_dependencies() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                Installing Dependencies                        ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    cd "$INSTALL_DIR"

    # Create virtual environment if not exists
    if [ ! -d "venv" ]; then
        log_info "Creating virtual environment..."
        python3 -m venv venv
    fi

    # Activate virtual environment
    source venv/bin/activate

    # Define installation steps
    local TOTAL_STEPS=8
    local STEP=0

    # Step 1: Upgrade pip
    STEP=$((STEP + 1))
    show_progress "Upgrading pip..." "$STEP" "$TOTAL_STEPS"
    pip install --upgrade pip setuptools wheel -q

    # Step 2: Check Python version for tiktoken compatibility
    PYTHON_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
    PYTHON_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")

    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 13 ]; then
        export PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1
    fi

    # Step 3: Install tiktoken
    STEP=$((STEP + 1))
    show_progress "Installing tiktoken..." "$STEP" "$TOTAL_STEPS"
    pip install tiktoken --only-binary=:all: -q 2>/dev/null || {
        if command -v rustc &> /dev/null; then
            pip install tiktoken -q || {
                log_error "Failed to install tiktoken. Try using Python 3.12 instead."
                exit 1
            }
        else
            log_error "tiktoken requires Rust compiler for Python 3.13+"
            log_error "Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            exit 1
        fi
    }

    # Step 4: Install core dependencies
    STEP=$((STEP + 1))
    show_progress "Installing core packages..." "$STEP" "$TOTAL_STEPS"
    pip install textual typer rich pydantic pydantic-settings python-dotenv watchdog -q

    # Step 5: Install LLM packages
    STEP=$((STEP + 1))
    show_progress "Installing LLM packages..." "$STEP" "$TOTAL_STEPS"
    pip install anthropic openai litellm mcp -q

    # Step 6: Install web & async packages
    STEP=$((STEP + 1))
    show_progress "Installing web packages..." "$STEP" "$TOTAL_STEPS"
    pip install httpx aiohttp requests aiofiles anyio pyyaml google_search_results -q

    # Step 7: Install crawl4ai
    STEP=$((STEP + 1))
    show_progress "Installing crawl4ai..." "$STEP" "$TOTAL_STEPS"
    pip install crawl4ai -q

    # Step 8: Setup crawl4ai and playwright
    STEP=$((STEP + 1))
    show_progress "Setting up browser (chromium)..." "$STEP" "$TOTAL_STEPS"

    # Run crawl4ai setup
    crawl4ai-setup -q 2>/dev/null || true

    # Install playwright chromium with dependencies
    python -m playwright install --with-deps chromium 2>/dev/null || {
        log_warn "Playwright chromium installation may need manual setup"
        log_warn "Run: python -m playwright install --with-deps chromium"
    }

    echo ""
    log_success "All dependencies installed successfully!"
}

# Configure LLM settings
configure_llm() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    LLM Configuration                          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Check if .env already exists
    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}Existing configuration found at $ENV_FILE${NC}"
        read -p "Do you want to reconfigure? [y/N]: " RECONFIG
        if [[ ! "$RECONFIG" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing configuration"
            return
        fi
    fi

    # Choose LLM API
    echo ""
    echo "Select your LLM API provider:"
    echo "  1) Anthropic (Claude API)"
    echo "  2) OpenRouter"
    echo "  3) Custom OpenAI-compatible API"
    echo ""
    read -p "Enter choice [1-3]: " LLM_CHOICE

    case $LLM_CHOICE in
        1)
            LLM_API="anthropic"
            echo ""
            read -p "Enter your Anthropic API Key: " API_KEY
            read -p "Enter model name [claude-3-5-sonnet-20241022]: " MODEL_NAME
            MODEL_NAME=${MODEL_NAME:-claude-3-5-sonnet-20241022}
            BASE_URL="https://api.anthropic.com"
            ;;
        2)
            LLM_API="openrouter"
            echo ""
            read -p "Enter your OpenRouter API Key: " API_KEY
            read -p "Enter model name [anthropic/claude-3.5-sonnet]: " MODEL_NAME
            MODEL_NAME=${MODEL_NAME:-anthropic/claude-3.5-sonnet}
            BASE_URL="https://openrouter.ai/api/v1"
            ;;
        3)
            LLM_API="openai"
            echo ""
            read -p "Enter your API Key: " API_KEY
            read -p "Enter Base URL: " BASE_URL
            read -p "Enter model name: " MODEL_NAME
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac

    # Write .env file
    cat > "$ENV_FILE" << EOF
# Memento-S LLM Configuration
# Generated by install.sh

LLM_API=$LLM_API
CLAUDE_API_KEY=$API_KEY
CLAUDE_BASE_URL=$BASE_URL
CLAUDE_MODEL=$MODEL_NAME
CLAUDE_MAX_TOKENS=100000
CLAUDE_TIMEOUT=120

# Context management
CONTEXT_MAX_TOKENS=80000
CONTEXT_COMPRESS_THRESHOLD=60000
SUMMARY_MAX_TOKENS=2000

# Workspace
WORKSPACE_DIR=./workspace
SKILLS_DIR=./skills
EOF

    # Configure SERPAPI (optional)
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}              SerpAPI Configuration (Optional)                 ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "SerpAPI is used for web search functionality."
    echo "You can get an API key at: https://serpapi.com/"
    echo ""
    read -p "Enter your SerpAPI API Key (or press Enter to skip): " SERPAPI_KEY

    if [ -n "$SERPAPI_KEY" ]; then
        echo "" >> "$ENV_FILE"
        echo "# SerpAPI for web search" >> "$ENV_FILE"
        echo "SERPAPI_API_KEY=$SERPAPI_KEY" >> "$ENV_FILE"
        log_success "SerpAPI key configured"
    else
        log_info "Skipping SerpAPI configuration (web search will be disabled)"
    fi

    log_success "Configuration saved to $ENV_FILE"
}

# Install skills
install_skills() {
    if [ "$HAS_OPENSKILLS" != "true" ]; then
        log_warn "Skipping skills installation (openskills not available)"
        return
    fi

    log_info "Installing skills..."
    cd "$INSTALL_DIR"

    # Check if skills directory exists
    if [ ! -d "skills" ]; then
        log_warn "No skills directory found"
        return
    fi

    # Install each skill
    for d in skills/*; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"

        log_info "Processing skill: $name"

        if [ -d ".agent/skills/$name" ]; then
            openskills update "$name" 2>/dev/null || log_warn "Failed to update $name"
        else
            openskills install "./skills/$name" --universal --yes 2>/dev/null || log_warn "Failed to install $name"
        fi
    done

    # Sync skills
    openskills sync -y 2>/dev/null || log_warn "Failed to sync skills"

    log_success "Skills installed"
}

# Create launcher script
create_launcher() {
    log_info "Creating launcher script..."

    LAUNCHER="$INSTALL_DIR/memento"
    cat > "$LAUNCHER" << 'EOF'
#!/usr/bin/env bash
# Resolve symlinks to get the actual script location
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

cd "$SCRIPT_DIR"
source venv/bin/activate

# Default to 'run' if no arguments provided
if [ $# -eq 0 ]; then
    python tui.py run
else
    python tui.py "$@"
fi
EOF
    chmod +x "$LAUNCHER"

    # Try multiple methods to make 'memento' command available
    SYMLINK_CREATED=false

    # Method 1: Create symlink in /usr/local/bin if writable
    if [ -w "/usr/local/bin" ]; then
        ln -sf "$LAUNCHER" /usr/local/bin/memento 2>/dev/null && \
            log_success "Created symlink: /usr/local/bin/memento" && \
            SYMLINK_CREATED=true
    fi

    # Method 2: Try with sudo if /usr/local/bin exists but not writable
    if [ "$SYMLINK_CREATED" = false ] && [ -d "/usr/local/bin" ]; then
        log_info "Attempting to create symlink with sudo..."
        sudo ln -sf "$LAUNCHER" /usr/local/bin/memento 2>/dev/null && \
            log_success "Created symlink: /usr/local/bin/memento (with sudo)" && \
            SYMLINK_CREATED=true
    fi

    # Method 3: Use ~/.local/bin (user-local, no sudo needed)
    if [ "$SYMLINK_CREATED" = false ]; then
        LOCAL_BIN="$HOME/.local/bin"
        mkdir -p "$LOCAL_BIN"
        ln -sf "$LAUNCHER" "$LOCAL_BIN/memento" 2>/dev/null && \
            log_success "Created symlink: $LOCAL_BIN/memento"

        # Add to PATH if not already there
        add_to_path "$LOCAL_BIN"
    fi

    log_success "Launcher created: $LAUNCHER"
}

# Add directory to PATH in shell rc files
add_to_path() {
    local dir="$1"
    local path_export="export PATH=\"$dir:\$PATH\""

    # Check if already in PATH
    if echo "$PATH" | grep -q "$dir"; then
        return
    fi

    log_info "Adding $dir to PATH..."

    # Detect shell and update appropriate rc file
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    # Also check for .profile for login shells
    local profile_rc="$HOME/.profile"

    # Add to shell rc if it exists and doesn't already contain the path
    if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
        if ! grep -q "$dir" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# Added by Memento-S installer" >> "$shell_rc"
            echo "$path_export" >> "$shell_rc"
            log_success "Added to $shell_rc"
        fi
    fi

    # Also add to .profile for broader compatibility
    if [ -f "$profile_rc" ]; then
        if ! grep -q "$dir" "$profile_rc" 2>/dev/null; then
            echo "" >> "$profile_rc"
            echo "# Added by Memento-S installer" >> "$profile_rc"
            echo "$path_export" >> "$profile_rc"
        fi
    fi

    # Export for current session
    export PATH="$dir:$PATH"
    log_warn "Please restart your terminal or run: source $shell_rc"
}

# Print final instructions
print_success() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                 Installation Complete!                        ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Install directory:${NC} $INSTALL_DIR"
    echo -e "  ${CYAN}Configuration:${NC}     $ENV_FILE"
    echo ""
    echo -e "  ${YELLOW}To start Memento-S, simply run:${NC}"
    echo ""
    echo -e "    ${GREEN}memento${NC}"
    echo ""
    echo -e "  ${CYAN}Other commands:${NC}"
    echo -e "    memento doctor   - Check configuration"
    echo -e "    memento config   - Show current config"
    echo -e "    memento --help   - Show all commands"
    echo ""
    echo -e "  ${YELLOW}Note:${NC} If 'memento' command is not found, restart your terminal"
    echo -e "        or run: ${CYAN}source ~/.bashrc${NC} (or ~/.zshrc)"
    echo ""
}

# Main installation flow
main() {
    print_banner

    check_prerequisites
    setup_repository
    install_dependencies
    configure_llm
    install_skills
    create_launcher
    print_success
}

main "$@"
