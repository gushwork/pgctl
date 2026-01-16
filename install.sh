#!/bin/bash

# =============================================================================
# pgctl Installation Script
# =============================================================================
# This script installs pgctl as a system-wide command
# Can be run locally or remotely via:
#   curl -o- https://raw.githubusercontent.com/gushwork/pgctl/main/install.sh | bash
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
PGCTL_DIR="${PGCTL_DIR:-$HOME/.pgctl}"
REPO_URL="${PGCTL_REPO_URL:-https://github.com/gushwork/pgctl.git}"
REPO_BRANCH="${PGCTL_REPO_BRANCH:-main}"

# Detect if running from local directory or piped from curl
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    # Running locally - get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    IS_LOCAL_INSTALL=true
else
    # Running from curl pipe - will clone to PGCTL_DIR
    SCRIPT_DIR=""
    IS_LOCAL_INSTALL=false
fi

# Installation target
INSTALL_DIR="/usr/local/bin"
SYMLINK_PATH="${INSTALL_DIR}/pgctl"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# =============================================================================
# Installation Functions
# =============================================================================

check_command() {
    command -v "$1" &> /dev/null
}

clone_repository() {
    log_info "Cloning pgctl repository..."
    
    # Check if git is installed
    if ! check_command git; then
        log_error "git is not installed. Please install git first."
        exit 1
    fi
    
    # Remove existing directory if it exists
    if [[ -d "$PGCTL_DIR" ]]; then
        log_warning "Directory $PGCTL_DIR already exists."
        read -p "Remove and reinstall? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing installation..."
            rm -rf "$PGCTL_DIR"
        else
            log_info "Using existing installation at $PGCTL_DIR"
            return 0
        fi
    fi
    
    # Clone the repository
    log_info "Cloning from $REPO_URL (branch: $REPO_BRANCH)..."
    if git clone --branch "$REPO_BRANCH" "$REPO_URL" "$PGCTL_DIR"; then
        log_success "Repository cloned successfully"
    else
        log_error "Failed to clone repository"
        exit 1
    fi
}

check_prerequisites() {
    local pgctl_root="$1"
    
    log_info "Checking prerequisites..."
    
    # Check if pgctl script exists
    if [[ ! -f "${pgctl_root}/pgctl" ]]; then
        log_error "pgctl script not found at: ${pgctl_root}/pgctl"
        exit 1
    fi
    
    # Check if pgctl is executable
    if [[ ! -x "${pgctl_root}/pgctl" ]]; then
        log_warning "Making pgctl executable..."
        chmod +x "${pgctl_root}/pgctl"
    fi
    
    # Check if lib directory exists
    if [[ ! -d "${pgctl_root}/lib" ]]; then
        log_error "lib directory not found at ${pgctl_root}/lib"
        exit 1
    fi
    
    # Make all lib scripts executable
    chmod +x "${pgctl_root}"/lib/*.sh 2>/dev/null || true
    
    log_success "Prerequisites checked"
}

install_global() {
    local pgctl_root="$1"
    local pgctl_script="${pgctl_root}/pgctl"
    
    log_info "Installing pgctl globally to ${INSTALL_DIR}..."
    
    # Check if /usr/local/bin exists
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_warning "${INSTALL_DIR} does not exist. Creating it..."
        sudo mkdir -p "$INSTALL_DIR"
    fi
    
    # Remove existing symlink if it exists
    if [[ -L "$SYMLINK_PATH" ]]; then
        log_warning "Removing existing pgctl symlink..."
        sudo rm "$SYMLINK_PATH"
    elif [[ -f "$SYMLINK_PATH" ]]; then
        log_error "A file named 'pgctl' already exists at ${SYMLINK_PATH}"
        log_error "Please remove it manually or choose a different installation method."
        exit 1
    fi
    
    # Create symlink
    sudo ln -s "$pgctl_script" "$SYMLINK_PATH"
    log_success "Created symlink: ${SYMLINK_PATH} -> ${pgctl_script}"
    
    # Verify installation
    if command -v pgctl &> /dev/null; then
        log_success "pgctl installed successfully!"
        echo ""
        log_info "You can now use 'pgctl' from anywhere in your terminal."
        log_info "Installed at: $pgctl_root"
    else
        log_warning "Installation completed but 'pgctl' command not found in PATH."
        log_info "You may need to restart your terminal or run: export PATH=\"${INSTALL_DIR}:\$PATH\""
    fi
}

install_user_local() {
    local pgctl_root="$1"
    local pgctl_script="${pgctl_root}/pgctl"
    local USER_BIN="${HOME}/.local/bin"
    local USER_SYMLINK="${USER_BIN}/pgctl"
    
    log_info "Installing pgctl to user directory ${USER_BIN}..."
    
    # Create user bin directory if it doesn't exist
    if [[ ! -d "$USER_BIN" ]]; then
        log_info "Creating ${USER_BIN}..."
        mkdir -p "$USER_BIN"
    fi
    
    # Remove existing symlink if it exists
    if [[ -L "$USER_SYMLINK" ]]; then
        log_warning "Removing existing pgctl symlink..."
        rm "$USER_SYMLINK"
    elif [[ -f "$USER_SYMLINK" ]]; then
        log_error "A file named 'pgctl' already exists at ${USER_SYMLINK}"
        log_error "Please remove it manually."
        exit 1
    fi
    
    # Create symlink
    ln -s "$pgctl_script" "$USER_SYMLINK"
    log_success "Created symlink: ${USER_SYMLINK} -> ${pgctl_script}"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":${USER_BIN}:"* ]]; then
        log_warning "${USER_BIN} is not in your PATH."
        echo ""
        log_info "Add the following line to your shell configuration file:"
        echo ""
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        log_info "Shell config files:"
        echo "  - Bash: ~/.bashrc or ~/.bash_profile"
        echo "  - Zsh:  ~/.zshrc"
        echo "  - Fish: ~/.config/fish/config.fish"
        echo ""
        log_info "After adding, run: source ~/.zshrc (or your shell config file)"
    else
        log_success "pgctl installed successfully!"
        echo ""
        log_info "You can now use 'pgctl' from anywhere in your terminal."
        log_info "Installed at: $pgctl_root"
    fi
}

uninstall() {
    log_info "Uninstalling pgctl..."
    
    local removed=false
    
    # Remove from /usr/local/bin
    if [[ -L "$SYMLINK_PATH" ]]; then
        sudo rm "$SYMLINK_PATH"
        log_success "Removed ${SYMLINK_PATH}"
        removed=true
    fi
    
    # Remove from ~/.local/bin
    if [[ -L "${HOME}/.local/bin/pgctl" ]]; then
        rm "${HOME}/.local/bin/pgctl"
        log_success "Removed ${HOME}/.local/bin/pgctl"
        removed=true
    fi
    
    # Ask about removing installation directory
    if [[ -d "$PGCTL_DIR" ]] && [[ "$PGCTL_DIR" != "$SCRIPT_DIR" ]]; then
        echo ""
        log_warning "Installation directory exists: $PGCTL_DIR"
        read -p "Remove installation directory? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$PGCTL_DIR"
            log_success "Removed $PGCTL_DIR"
            removed=true
        fi
    fi
    
    if [[ "$removed" == "true" ]]; then
        log_success "pgctl uninstalled successfully"
    else
        log_warning "pgctl installation not found"
    fi
}

show_usage() {
    cat << EOF
${BLUE}pgctl Installation Script${NC}

Usage: $0 [OPTIONS]

OPTIONS:
    --global, -g        Install globally to /usr/local/bin (requires sudo)
    --user, -u          Install to ~/.local/bin (user-only, no sudo required)
    --uninstall         Uninstall pgctl
    --help, -h          Show this help message

ENVIRONMENT VARIABLES:
    PGCTL_DIR           Installation directory (default: ~/.pgctl)
    PGCTL_REPO_URL      Repository URL for remote installation
    PGCTL_REPO_BRANCH   Repository branch (default: main)

EXAMPLES:
    # Remote installation (via curl)
    curl -o- https://raw.githubusercontent.com/gushwork/pgctl/main/install.sh | bash

    # Remote with specific options
    curl -o- https://raw.githubusercontent.com/gushwork/pgctl/main/install.sh | bash -s -- --global

    # Local installation (from cloned repo)
    $0 --global

    # Custom installation directory
    PGCTL_DIR=~/tools/pgctl ./install.sh --user

    # Uninstall
    $0 --uninstall

NOTES:
    - Remote installation automatically clones to ~/.pgctl
    - Local installation uses the current directory
    - Global installation makes pgctl available for all users
    - User installation only affects the current user
    - The pgctl directory must remain in its location (symlink is created)
    - Updates: cd ~/.pgctl && git pull (for remote installations)

EOF
}

# =============================================================================
# Main Installation Logic
# =============================================================================

main() {
    local install_type=""
    local pgctl_root=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global|-g)
                install_type="global"
                shift
                ;;
            --user|-u)
                install_type="user"
                shift
                ;;
            --uninstall)
                install_type="uninstall"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Handle uninstall separately (doesn't need pgctl files)
    if [[ "$install_type" == "uninstall" ]]; then
        uninstall
        echo ""
        log_info "Done!"
        exit 0
    fi
    
    # Display header
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   pgctl Installation                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    # Determine installation source
    if [[ "$IS_LOCAL_INSTALL" == true ]]; then
        # Local installation
        log_info "Running local installation from: $SCRIPT_DIR"
        pgctl_root="$SCRIPT_DIR"
    else
        # Remote installation via curl
        log_info "Running remote installation"
        log_info "Repository: $REPO_URL"
        log_info "Branch: $REPO_BRANCH"
        log_info "Install location: $PGCTL_DIR"
        echo ""
        
        clone_repository
        pgctl_root="$PGCTL_DIR"
    fi
    
    # Check prerequisites
    check_prerequisites "$pgctl_root"
    
    # If no installation method specified, show menu
    if [[ -z "$install_type" ]]; then
        echo ""
        echo "Choose installation method:"
        echo ""
        echo "  1) Global (/usr/local/bin) - requires sudo, available to all users"
        echo "  2) User (~/.local/bin) - no sudo, current user only"
        echo "  3) Cancel"
        echo ""
        read -p "Enter choice [1-3]: " choice
        
        case "$choice" in
            1)
                install_type="global"
                ;;
            2)
                install_type="user"
                ;;
            3)
                log_info "Installation cancelled"
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                exit 1
                ;;
        esac
    fi
    
    echo ""
    
    # Execute installation
    case "$install_type" in
        global)
            install_global "$pgctl_root"
            ;;
        user)
            install_user_local "$pgctl_root"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Installation Complete!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    log_info "Try running: pgctl --version"
    echo ""
}

# =============================================================================
# Entry Point
# =============================================================================

main "$@"
