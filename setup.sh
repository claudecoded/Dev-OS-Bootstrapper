#!/usr/bin/env bash

# ==============================================================================
# THE DEV-OS BOOTSTRAPPER
# Automatically configures a complete, high-performance development machine.
# Supported OS: macOS, Ubuntu/Debian Linux
# ==============================================================================

set -euo pipefail

# --- Color Definitions for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- OS Detection ---
detect_os() {
    log_info "Detecting Operating System..."
    OS_TYPE="$(uname -s)"
    case "$OS_TYPE" in
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS_NAME=$ID
            else
                OS_NAME="unknown_linux"
            fi
            ;;
        Darwin*)
            OS_NAME="macos"
            ;;
        *)
            OS_NAME="unknown"
            ;;
    esac
}

# --- Prerequisites Checklist ---
check_prerequisites() {
    if [ "$OS_NAME" = "unknown" ]; then
        log_error "Unsupported Operating System. This script supports macOS and Ubuntu/Debian Linux."
        exit 1
    fi
    
    if [ "$OS_NAME" != "macos" ] && [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with sudo privileges on Linux."
        exit 1
    fi
}

# --- Package Manager Installation ---
install_package_manager() {
    if [ "$OS_NAME" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://githubusercontent.com)"
            # Add brew to path for the current session
            eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
        else
            log_success "Homebrew is already installed. Updating..."
            brew update
        fi
    elif [ "$OS_NAME" = "ubuntu" ] || [ "$OS_NAME" = "debian" ]; then
        log_info "Updating apt packages repository..."
        apt-get update -y && apt-get upgrade -y
        apt-get install -y curl wget git build-essential unzip
    fi
}

# --- Core Development Tools ---
install_dev_tools() {
    log_info "Installing core development tools (Docker, Node.js, Python, VS Code)..."
    
    if [ "$OS_NAME" = "macos" ]; then
        # CLI Tools & Runtimes
        brew install git curl coreutils node python jq fzf tldr
        
        # GUI Applications (Casks)
        log_info "Installing GUI applications via Homebrew Cask..."
        brew install --cask visual-studio-code docker insomnia
    else
        # Linux Installations
        apt-get install -y python3 python3-pip jq fzf
        
        # Install Node via NodeSource LTS
        log_info "Installing Node.js LTS..."
        curl -fsSL https://nodesource.com | bash -
        apt-get install -y nodejs

        # Install Docker
        log_info "Installing Docker..."
        curl -fsSL https://docker.com | sh
        
        # Install VS Code
        log_info "Installing VS Code..."
        wget -qO- https://microsoft.com | gpg --dearmor > packages.microsoft.gpg
        install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://microsoft.com stable main" > /etc/apt/sources.list.d/vscode.list'
        rm -f packages.microsoft.gpg
        apt-get update -y && apt-get install -y code
    fi
}

# --- VS Code Extensions Config ---
configure_vscode() {
    log_info "Configuring VS Code Extensions..."
    if command -v code &> /dev/null; then
        local extensions=(
            "dbaeumer.vscode-eslint"
            "esbenp.prettier-vscode"
            "eamodio.gitlens"
            "ms-azuretools.vscode-docker"
            "usernamehw.errorlens"
            "pkief.material-icon-theme"
        )
        for ext in "${extensions[@]}"; do
            code --install-extension "$ext" --force || log_warn "Failed to install VS Code extension: $ext"
        done
    else
        log_warn "VS Code binary not found in PATH. Skipping extensions installation."
    fi
}

# --- Performance Dotfiles Optimization ---
apply_dotfiles_optimization() {
    log_info "Applying high-performance dotfiles and shell aliases..."
    
    TARGET_RC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && TARGET_RC="$HOME/.zshrc"
    
    cat << 'EOF' >> "$TARGET_RC"

# --- DEV-OS AUTOMATIC OPTIMIZATIONS ---
export EDITOR="code --wait"
export HISTSIZE=50000
export HISTFILESIZE=100000
setopt HIST_IGNORE_DUPS 2>/dev/null || true # Ignore duplicate commands in history

# Helpful Dev Aliases
alias ll="ls -laF --color=auto"
alias g="git"
alias gst="git status"
alias gcm="git commit -m"
alias dco="docker compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias myip="curl ifconfig.me; echo"
# --------------------------------------
EOF

    log_success "Shell configurations appended to $TARGET_RC"
}

# --- Main Execution Flow ---
main() {
    echo -e "${BLUE}"
    echo "  _____  _______      __   ____   ____  "
    echo " |  __ \|  ____\ \    / /  / __ \ / ____| "
    echo " | |  | | |__   \ \  / /  | |  | | (___   "
    echo " | |  | |  __|   \ \/ /   | |  | |\___ \  "
    echo " | |__| | |____   \  /    | |__| |____) | "
    echo " |_____/|______|   \/      \____/|_____/  "
    echo -e "         BOOTSTRAPPER INITIALIZED\n${NC}"

    detect_os
    check_prerequisites
    install_package_manager
    install_dev_tools
    configure_vscode
    apply_dotfiles_optimization

    echo ""
    log_success "Dev-OS Environment bootstrapping completed successfully!"
    log_warn "Please restart your terminal or run 'source $TARGET_RC' to apply all changes."
}

main "$@"
