#!/bin/bash

################################################################################
# Illogical Impulse Cybex Post-Installation Setup Script
# https://github.com/DigitalPals/ii-cybex
#
# This script sets up personal preferences after installing Illogical Impulse.
# It is designed to be idempotent - safe to run multiple times.
#
# Usage:
#   ./install.sh                - Show help and available options
#   ./install.sh all            - Install everything except mainline kernel
#   ./install.sh claude ssh     - Install specific components
#   ./install.sh mainline       - Install mainline kernel only
#
# Run without arguments to see all available options.
################################################################################

set -e  # Exit on error

# Trap handler for cleanup on failure
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n${RED}✗${NC} Installation failed with exit code $exit_code"
        echo -e "${YELLOW}Some changes may have been made. Please review and potentially rollback manually.${NC}"
    fi
}
trap cleanup EXIT

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${MAGENTA}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_skip() {
    echo -e "${YELLOW}⊙${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

# Create a timestamped backup of a file
create_backup() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        echo "$backup"
        return 0
    fi
    return 1
}

# Remove lines added by this script from a file
remove_script_lines() {
    local file="$1"
    local marker="$2"  # Comment marker to identify our additions (e.g., "Added by Omarchy")

    if [ ! -f "$file" ]; then
        return 0
    fi

    # Create temp file without our additions
    local temp_file=$(mktemp)
    local skip_next_non_empty=false

    while IFS= read -r line; do
        # If we found the marker in the previous iteration, skip non-empty lines
        if [ "$skip_next_non_empty" = true ]; then
            if [ -n "$line" ]; then
                # Skip this non-empty line (the actual command/export)
                skip_next_non_empty=false
                continue
            else
                # Skip empty lines between marker and command
                continue
            fi
        fi

        # Check if this line contains our marker
        if echo "$line" | grep -q "$marker"; then
            # Skip the marker line and set flag to skip next non-empty line
            skip_next_non_empty=true
            continue
        fi

        # Keep this line
        echo "$line" >> "$temp_file"
    done < "$file"

    # Replace original with cleaned version
    mv "$temp_file" "$file"
}

# Add ~/.local/bin to PATH for both Bash and Fish shells
add_local_bin_to_path() {
    local updated_bash=false
    local updated_fish=false

    # Add to Bash config if not already present
    if ! grep -qE '(\.local/bin|HOME/.local/bin)' "$HOME/.bashrc" 2>/dev/null; then
        print_step "Adding ~/.local/bin to PATH in .bashrc..."
        echo '' >> "$HOME/.bashrc"
        echo '# Added by Illogical Impulse post-install script' >> "$HOME/.bashrc"
        echo 'export PATH=$HOME/.local/bin:$PATH' >> "$HOME/.bashrc"
        updated_bash=true
        print_success "PATH updated in .bashrc"

        # Update current PATH if not already present
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            export PATH="$HOME/.local/bin:$PATH"
            print_step "PATH updated for current session"
        fi
    else
        print_skip "PATH already configured in .bashrc"
    fi

    # Add to Fish config if Fish is installed
    if command_exists fish; then
        local fish_config="$HOME/.config/fish/config.fish"
        if [ ! -f "$fish_config" ]; then
            mkdir -p "$HOME/.config/fish"
            touch "$fish_config"
        fi

        if ! grep -q "fish_add_path.*\.local/bin" "$fish_config" 2>/dev/null && \
           ! grep -q "set.*PATH.*\.local/bin" "$fish_config" 2>/dev/null; then
            print_step "Adding ~/.local/bin to PATH in Fish config..."
            echo '' >> "$fish_config"
            echo '# Added by Illogical Impulse post-install script' >> "$fish_config"
            echo 'fish_add_path ~/.local/bin' >> "$fish_config"
            updated_fish=true
            print_success "PATH updated in Fish config"
        else
            print_skip "PATH already configured in Fish config"
        fi
    fi

    # Always return success - if PATH is already configured, that's a successful state
    return 0
}

show_usage() {
    echo -e "${BOLD}${CYAN}Illogical Impulse Cybex Post-Installation Setup Script${NC}"
    echo -e "${CYAN}https://github.com/DigitalPals/ii-cybex${NC}"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo -e "  $0 [OPTION]..."
    echo -e "  $0 uninstall [OPTION]..."
    echo ""
    echo -e "${BOLD}DESCRIPTION:${NC}"
    echo -e "  Configure and install various components for your Illogical Impulse system."
    echo -e "  This script is idempotent - safe to run multiple times."
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo -e "  ${GREEN}all${NC}              Install all components (except mainline kernel)"
    echo -e "  ${GREEN}packages${NC}         Install system packages (npm, nano)"
    echo -e "  ${GREEN}claude${NC}           Install Claude Code CLI"
    echo -e "  ${GREEN}codex${NC}            Install OpenAI Codex CLI"
    echo -e "  ${GREEN}screensaver${NC}      Configure custom screensaver"
    echo -e "  ${GREEN}plymouth${NC}         Install Cybex Plymouth boot theme"
    echo -e "  ${GREEN}prompt${NC}           Configure Starship prompt (alias: starship)"
    echo -e "  ${GREEN}macos-keys${NC}       Configure macOS-style shortcuts (keyd + Kitty)"
    echo -e "  ${GREEN}hyprland${NC}         Copy all Hyprland custom configs + install Cybex apps to /usr/local/bin (alias: hyprland-bindings)"
    echo -e "  ${GREEN}auto-tile${NC}        Install Hyprland auto-tiling helper"
    echo -e "  ${GREEN}ssh${NC}              Generate SSH key for GitHub (alias: ssh-key)"
    echo -e "  ${GREEN}mainline${NC}         Install and configure mainline kernel (Chaotic-AUR)"
    echo ""
    echo -e "${BOLD}UNINSTALL:${NC}"
    echo -e "  ${YELLOW}uninstall${NC} all              Remove all installed components"
    echo -e "  ${YELLOW}uninstall${NC} [option]         Remove specific component (e.g., auto-tile)"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo -e "  $0 all                    # Install everything except mainline kernel"
    echo -e "  $0 claude ssh             # Install Claude Code and generate SSH key"
    echo -e "  $0 mainline               # Only configure mainline kernel"
    echo -e "  $0 prompt codex           # Configure Starship prompt and install Codex CLI"
    echo -e "  $0 uninstall auto-tile    # Remove auto-tile helper"
    echo -e "  $0 uninstall all          # Remove all installed components"
    echo ""
    echo -e "${BOLD}NOTES:${NC}"
    echo -e "  • Multiple options can be combined in a single command"
    echo -e "  • The script will request sudo privileges when needed"
    echo -e "  • Some components require a reboot to take effect (kernel, Plymouth theme)"
    echo -e "  • Uninstall creates backups and restores original configurations when possible"
    echo -e "  • SSH keys cannot be uninstalled for safety reasons"
    echo -e "  • Run without arguments to show this help message"
    echo ""
}

################################################################################
# Command Line Arguments
################################################################################

# Initialize mode and flags
UNINSTALL_MODE=false
INSTALL_ALL=false
INSTALL_PACKAGES=false
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_SCREENSAVER=false
INSTALL_PLYMOUTH=false
INSTALL_PROMPT=false
INSTALL_MACOS_KEYS=false
INSTALL_HYPRLAND_BINDINGS=false
INSTALL_AUTO_TILE=false
INSTALL_SSH=false
INSTALL_MAINLINE=false

# Show help if no arguments provided
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# Check if first argument is "uninstall"
if [ "$1" = "uninstall" ]; then
    UNINSTALL_MODE=true
    shift  # Remove "uninstall" from arguments

    # Show help if no uninstall target specified
    if [ $# -eq 0 ]; then
        print_error "Please specify what to uninstall (e.g., 'uninstall all' or 'uninstall auto-tile')"
        echo ""
        show_usage
        exit 1
    fi
fi

# Parse all command line arguments
for arg in "$@"; do
    case "$arg" in
        all)
            INSTALL_ALL=true
            ;;
        packages)
            INSTALL_PACKAGES=true
            ;;
        claude)
            INSTALL_CLAUDE=true
            ;;
        codex)
            INSTALL_CODEX=true
            ;;
        screensaver)
            INSTALL_SCREENSAVER=true
            ;;
        plymouth)
            INSTALL_PLYMOUTH=true
            ;;
        prompt|starship)
            INSTALL_PROMPT=true
            ;;
        macos-keys)
            INSTALL_MACOS_KEYS=true
            ;;
        hyprland|hyprland-bindings)
            INSTALL_HYPRLAND_BINDINGS=true
            ;;
        auto-tile)
            INSTALL_AUTO_TILE=true
            ;;
        ssh|ssh-key)
            if [ "$UNINSTALL_MODE" = true ]; then
                print_error "SSH keys cannot be uninstalled for safety reasons"
                exit 1
            fi
            INSTALL_SSH=true
            ;;
        mainline)
            INSTALL_MAINLINE=true
            ;;
        *)
            print_error "Unknown parameter: $arg"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# If 'all' is specified, enable everything except mainline
if [ "$INSTALL_ALL" = true ]; then
    INSTALL_PACKAGES=true
    INSTALL_CLAUDE=true
    INSTALL_CODEX=true
    INSTALL_SCREENSAVER=true
    INSTALL_PLYMOUTH=true
    # INSTALL_PROMPT=true  # Illogical Impulse already has Starship, so don't auto-install
    # INSTALL_MACOS_KEYS=true  # Omarchy now includes macOS-key functionality by default
    INSTALL_HYPRLAND_BINDINGS=true
    INSTALL_AUTO_TILE=true
    INSTALL_SSH=true
fi

################################################################################
# Uninstall Functions
################################################################################

if [ "$UNINSTALL_MODE" = true ]; then
    print_header "Starting Illogical Impulse Component Uninstall"

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root or with sudo."
        print_error "The script will request sudo when needed."
        exit 1
    fi

    # Uninstall packages
    if [ "$INSTALL_PACKAGES" = true ]; then
        print_header "Uninstalling System Packages"

        PACKAGES=("npm" "nano")

        echo -e "${YELLOW}Warning: This will remove npm and nano packages.${NC}"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for pkg in "${PACKAGES[@]}"; do
                if package_installed "$pkg"; then
                    print_step "Removing $pkg..."
                    sudo pacman -R --noconfirm "$pkg"
                    print_success "$pkg removed"
                else
                    print_skip "$pkg is not installed"
                fi
            done
        else
            print_skip "Skipping package removal"
        fi
    fi

    # Uninstall Claude Code
    if [ "$INSTALL_CLAUDE" = true ]; then
        print_header "Uninstalling Claude Code"

        if command_exists claude; then
            print_step "Removing Claude Code..."
            npm uninstall -g @anthropic-ai/claude-code --prefix "$HOME/.local"
            print_success "Claude Code removed"
        else
            print_skip "Claude Code is not installed"
        fi

        # Remove PATH entry from shell configs only if Codex is also not installed
        if ! command_exists codex; then
            if [ -f "$HOME/.bashrc" ]; then
                print_step "Cleaning PATH from .bashrc..."
                remove_script_lines "$HOME/.bashrc" "Added by Illogical Impulse"
                print_success "PATH entries cleaned from .bashrc"
            fi
            if [ -f "$HOME/.config/fish/config.fish" ]; then
                print_step "Cleaning PATH from Fish config..."
                remove_script_lines "$HOME/.config/fish/config.fish" "Added by Illogical Impulse"
                print_success "PATH entries cleaned from Fish config"
            fi
        else
            print_skip "Keeping PATH entry (Codex is still installed)"
        fi
    fi

    # Uninstall Codex CLI
    if [ "$INSTALL_CODEX" = true ]; then
        print_header "Uninstalling Codex CLI"

        if command_exists codex; then
            print_step "Removing Codex CLI..."
            npm uninstall -g @openai/codex --prefix "$HOME/.local"
            print_success "Codex CLI removed"
        else
            print_skip "Codex CLI is not installed"
        fi

        # Remove PATH entry from shell configs only if Claude is also not installed
        if ! command_exists claude; then
            if [ -f "$HOME/.bashrc" ]; then
                print_step "Cleaning PATH from .bashrc..."
                remove_script_lines "$HOME/.bashrc" "Added by Illogical Impulse"
                print_success "PATH entries cleaned from .bashrc"
            fi
            if [ -f "$HOME/.config/fish/config.fish" ]; then
                print_step "Cleaning PATH from Fish config..."
                remove_script_lines "$HOME/.config/fish/config.fish" "Added by Illogical Impulse"
                print_success "PATH entries cleaned from Fish config"
            fi
        else
            print_skip "Keeping PATH entry (Claude Code is still installed)"
        fi
    fi

    # Uninstall screensaver
    if [ "$INSTALL_SCREENSAVER" = true ]; then
        print_header "Removing Custom Screensaver"

        SCREENSAVER_DEST="$HOME/.config/omarchy/branding/screensaver.txt"

        if [ -f "$SCREENSAVER_DEST" ]; then
            # Find most recent backup
            BACKUP=$(ls -t "${SCREENSAVER_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring backup from $BACKUP..."
                cp "$BACKUP" "$SCREENSAVER_DEST"
                print_success "Screensaver backup restored"
            else
                print_step "Removing custom screensaver..."
                rm "$SCREENSAVER_DEST"
                print_success "Custom screensaver removed"
            fi
        else
            print_skip "Custom screensaver not found"
        fi
    fi

    # Uninstall Plymouth theme
    if [ "$INSTALL_PLYMOUTH" = true ]; then
        print_header "Uninstalling Plymouth Theme"

        if command_exists plymouth-set-default-theme; then
            CURRENT_THEME=$(sudo plymouth-set-default-theme)

            if [ "$CURRENT_THEME" = "cybex" ]; then
                print_step "Resetting Plymouth theme to default..."
                sudo plymouth-set-default-theme -R spinner
                print_success "Plymouth theme reset to spinner"

                print_step "Rebuilding initramfs..."
                sudo mkinitcpio -P
                print_success "Initramfs rebuilt"
            else
                print_skip "Plymouth theme is not set to cybex"
            fi

            # Remove theme directory
            if sudo test -d "/usr/share/plymouth/themes/cybex"; then
                print_step "Removing cybex theme directory..."
                sudo rm -rf "/usr/share/plymouth/themes/cybex"
                print_success "Cybex theme directory removed"
            fi
        else
            print_skip "Plymouth not installed"
        fi
    fi

    # Uninstall Starship prompt
    if [ "$INSTALL_PROMPT" = true ]; then
        print_header "Removing Starship Configuration"

        STARSHIP_DEST="$HOME/.config/starship.toml"

        if [ -f "$STARSHIP_DEST" ]; then
            # Find most recent backup
            BACKUP=$(ls -t "${STARSHIP_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring backup from $BACKUP..."
                cp "$BACKUP" "$STARSHIP_DEST"
                print_success "Starship configuration backup restored"
            else
                print_step "Removing Starship configuration..."
                rm "$STARSHIP_DEST"
                print_success "Starship configuration removed"
            fi
        else
            print_skip "Starship configuration not found"
        fi
    fi

    # Uninstall macOS-style shortcuts
    if [ "$INSTALL_MACOS_KEYS" = true ]; then
        print_header "Removing macOS-style Shortcuts"

        # Stop and disable keyd service
        if sudo systemctl is-active --quiet keyd; then
            print_step "Stopping keyd service..."
            sudo systemctl stop keyd
            print_success "keyd service stopped"
        fi

        if sudo systemctl is-enabled --quiet keyd 2>/dev/null; then
            print_step "Disabling keyd service..."
            sudo systemctl disable keyd
            print_success "keyd service disabled"
        fi

        # Remove keyd configuration
        if sudo test -f "/etc/keyd/default.conf"; then
            print_step "Removing keyd configuration..."
            sudo rm "/etc/keyd/default.conf"
            print_success "keyd configuration removed"
        fi

        # Restore Kitty configuration
        KITTY_DEST="$HOME/.config/kitty/kitty.conf"
        if [ -f "$KITTY_DEST" ]; then
            BACKUP=$(ls -t "${KITTY_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring Kitty backup from $BACKUP..."
                cp "$BACKUP" "$KITTY_DEST"
                print_success "Kitty configuration restored"
            else
                print_skip "No Kitty backup found"
            fi
        fi
    fi

    # Uninstall Hyprland custom settings
    if [ "$INSTALL_HYPRLAND_BINDINGS" = true ]; then
        print_header "Removing Hyprland Custom Configuration"

        HYPRLAND_DEST_DIR="$HOME/.config/hypr/custom"

        # Find most recent backup directory
        BACKUP_DIR=$(ls -dt "${HYPRLAND_DEST_DIR}.bak."* 2>/dev/null | head -1)

        if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
            print_step "Restoring Hyprland custom configs from $BACKUP_DIR..."
            # Remove current custom directory
            rm -rf "$HYPRLAND_DEST_DIR"
            # Restore from backup
            cp -r "$BACKUP_DIR" "$HYPRLAND_DEST_DIR"
            print_success "Hyprland custom configuration restored from backup"
        else
            if [ -d "$HYPRLAND_DEST_DIR" ]; then
                print_step "Removing Hyprland custom configuration directory..."
                rm -rf "$HYPRLAND_DEST_DIR"
                print_success "Hyprland custom configuration removed"
            else
                print_skip "No Hyprland custom configuration found"
            fi
        fi

        # Uninstall Cybex app launcher scripts
        print_step "Removing Cybex app launcher scripts from /usr/local/bin..."
        CYBEX_SCRIPTS=(
            "cybex-cmd-screenshot"
            "cybex-cmd-terminal-cwd"
            "cybex-launch-browser"
            "cybex-launch-editor"
            "cybex-launch-or-focus"
            "cybex-launch-or-focus-webapp"
            "cybex-launch-webapp"
        )

        for script in "${CYBEX_SCRIPTS[@]}"; do
            if [ -f "/usr/local/bin/$script" ]; then
                sudo rm "/usr/local/bin/$script"
                echo "  • Removed $script"
            fi
        done

        print_success "Cybex app launcher scripts removed"
    fi

    # Uninstall auto-tile
    if [ "$INSTALL_AUTO_TILE" = true ]; then
        print_header "Uninstalling Auto-Tile Helper"

        AUTO_TILE_DEST="$HOME/.local/bin/auto-tile"

        # Kill running process
        if pgrep -f "$AUTO_TILE_DEST" >/dev/null 2>&1; then
            print_step "Stopping auto-tile helper..."
            pkill -f "$AUTO_TILE_DEST"
            print_success "auto-tile helper stopped"
        fi

        # Remove script
        if [ -f "$AUTO_TILE_DEST" ]; then
            print_step "Removing auto-tile script..."
            rm "$AUTO_TILE_DEST"
            print_success "auto-tile script removed"
        fi

        # Remove from execs.conf
        HYPRLAND_EXECS="$HOME/.config/hypr/custom/execs.conf"
        if [ -f "$HYPRLAND_EXECS" ]; then
            print_step "Removing auto-tile from Hyprland execs..."
            remove_script_lines "$HYPRLAND_EXECS" "Auto-tile first window"
            print_success "auto-tile removed from execs"
        fi
    fi

    # Uninstall mainline kernel
    if [ "$INSTALL_MAINLINE" = true ]; then
        print_header "Uninstalling Mainline Kernel"

        echo -e "${YELLOW}Warning: This will remove the mainline kernel and reset bootloader.${NC}"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if package_installed "linux-mainline"; then
                print_step "Removing linux-mainline kernel..."
                sudo pacman -R --noconfirm linux-mainline
                print_success "linux-mainline kernel removed"

                # Reset bootloader to default kernel
                print_step "Resetting bootloader to default kernel..."
                if [ -f /boot/limine.conf ]; then
                    sudo sed -i 's/^default_entry:.*/default_entry: 0/' /boot/limine.conf
                    print_success "Limine bootloader reset to first entry"
                elif command_exists grub-mkconfig; then
                    sudo grub-mkconfig -o /boot/grub/grub.cfg
                    print_success "GRUB configuration updated"
                elif command_exists bootctl; then
                    # Reset to first available entry
                    FIRST_ENTRY=$(ls /boot/loader/entries/*.conf 2>/dev/null | head -1 | xargs basename 2>/dev/null)
                    if [ -n "$FIRST_ENTRY" ]; then
                        echo "default $FIRST_ENTRY" | sudo tee /boot/loader/loader.conf >/dev/null
                        print_success "systemd-boot reset to $FIRST_ENTRY"
                    fi
                fi
            else
                print_skip "linux-mainline kernel is not installed"
            fi
        else
            print_skip "Skipping mainline kernel removal"
        fi
    fi

    print_header "Uninstall Complete!"
    echo -e "${GREEN}Selected components have been uninstalled.${NC}\n"

    exit 0
fi

################################################################################
# Main Installation Steps
################################################################################

print_header "Starting Illogical Impulse Post-Installation Setup"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root or with sudo."
    print_error "The script will request sudo when needed."
    exit 1
fi

################################################################################
# System Validation Checks
################################################################################

# Determine what validation checks are needed based on selected components
NEED_SUDO=false
NEED_INTERNET=false
NEED_DISK_SPACE=false

# Components that require sudo
if [ "$INSTALL_PACKAGES" = true ] || [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PLYMOUTH" = true ] || [ "$INSTALL_MACOS_KEYS" = true ] || [ "$INSTALL_AUTO_TILE" = true ]; then
    NEED_SUDO=true
fi

# Components that require internet
if [ "$INSTALL_PACKAGES" = true ] || [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ] || [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_MACOS_KEYS" = true ] || [ "$INSTALL_AUTO_TILE" = true ] || [ "$INSTALL_WAYCORNER" = true ]; then
    NEED_INTERNET=true
fi

# Components that require significant disk space
if [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PLYMOUTH" = true ]; then
    NEED_DISK_SPACE=true
fi

# Only run validation checks if needed
if [ "$NEED_SUDO" = true ] || [ "$NEED_INTERNET" = true ] || [ "$NEED_DISK_SPACE" = true ]; then
    print_header "System Validation Checks"

    # Check for sudo availability (if needed)
    if [ "$NEED_SUDO" = true ]; then
        print_step "Checking sudo availability..."
        if ! command_exists sudo; then
            print_error "sudo is not installed. Please install sudo first: pacman -S sudo"
            exit 1
        fi

        if ! sudo -v &>/dev/null; then
            print_error "You don't have sudo privileges. Please ensure you're in the sudoers group."
            exit 1
        fi
        print_success "sudo is available and configured"
    fi

    # Check internet connectivity (if needed)
    if [ "$NEED_INTERNET" = true ]; then
        print_step "Checking internet connectivity..."
        if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null && ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
            print_error "No internet connection detected. This script requires internet access."
            print_error "Please check your network connection and try again."
            exit 1
        fi
        print_success "Internet connection verified"
    fi

    # Check disk space (if needed)
    if [ "$NEED_DISK_SPACE" = true ]; then
        print_step "Checking available disk space..."
        AVAILABLE_ROOT=$(df / | awk 'NR==2 {print int($4/1024)}')  # Available space in MB
        if [ "$AVAILABLE_ROOT" -lt 1024 ]; then
            print_error "Insufficient disk space. At least 1GB free space is required."
            print_error "Available: ${AVAILABLE_ROOT}MB"
            exit 1
        fi

        # Check /boot separately if it's a separate partition
        if mountpoint -q /boot; then
            AVAILABLE_BOOT=$(df /boot | awk 'NR==2 {print int($4/1024)}')  # Available space in MB
            if [ "$AVAILABLE_BOOT" -lt 100 ]; then
                print_error "Insufficient disk space in /boot. At least 100MB free space is required."
                print_error "Available: ${AVAILABLE_BOOT}MB"
                exit 1
            fi
        fi
        print_success "Sufficient disk space available (${AVAILABLE_ROOT}MB on /)"
    fi
fi

################################################################################
# 0. Install Mainline Kernel (Optional)
################################################################################

if [ "$INSTALL_MAINLINE" = true ]; then
    print_header "Installing Mainline Kernel"

    # Check if Chaotic-AUR is already fully configured
    CHAOTIC_CONFIGURED=false
    if grep -q "\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null && \
       grep -q "Include = /etc/pacman.d/chaotic-mirrorlist" /etc/pacman.conf 2>/dev/null; then
        CHAOTIC_CONFIGURED=true
        print_skip "Chaotic-AUR repository already fully configured"
    fi

    if [ "$CHAOTIC_CONFIGURED" = false ]; then
        # Import GPG key
        print_step "Importing Chaotic-AUR GPG key..."
        if sudo pacman-key --list-keys 3056513887B78AEB &>/dev/null; then
            print_skip "Chaotic-AUR GPG key already imported"
        else
            sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
            sudo pacman-key --lsign-key 3056513887B78AEB
            print_success "Chaotic-AUR GPG key imported"
        fi

        # Install mirrorlist
        if ! package_installed "chaotic-mirrorlist"; then
            print_step "Installing Chaotic-AUR mirrorlist..."
            sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst --noconfirm
            print_success "Chaotic-AUR mirrorlist installed"
        else
            print_skip "Chaotic-AUR mirrorlist already installed"
        fi

        # Install keyring (contains all trusted keys for Chaotic-AUR packages)
        if ! package_installed "chaotic-keyring"; then
            print_step "Installing Chaotic-AUR keyring..."
            sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst --noconfirm
            print_success "Chaotic-AUR keyring installed"
        else
            print_skip "Chaotic-AUR keyring already installed"
        fi

        # Add repository to pacman.conf if not already present
        if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null; then
            print_step "Adding Chaotic-AUR repository to pacman.conf..."
            echo '
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf >/dev/null
            print_success "Chaotic-AUR repository added"
        else
            # Header exists but maybe not the Include line
            if ! grep -q "Include = /etc/pacman.d/chaotic-mirrorlist" /etc/pacman.conf 2>/dev/null; then
                print_error "Chaotic-AUR header found but Include line missing in pacman.conf"
                print_error "Please manually fix /etc/pacman.conf"
                exit 1
            fi
        fi
    fi

    print_step "Updating package database..."
    sudo pacman -Syy --noconfirm
    print_success "Package database updated"

    # Refresh keyring to ensure all package signing keys are trusted
    print_step "Refreshing package signing keys..."
    sudo pacman -S --noconfirm chaotic-keyring
    print_success "Package signing keys refreshed"

    if package_installed "linux-mainline"; then
        print_skip "linux-mainline kernel already installed"
    else
        print_step "Installing linux-mainline kernel..."
        sudo pacman -S --noconfirm linux-mainline
        print_success "linux-mainline kernel installed"
    fi

    # Update bootloader configuration
    print_step "Updating bootloader configuration..."
    if [ -f /boot/limine.conf ]; then
        print_step "Setting mainline kernel as default for Limine..."
        # Find the index of the linux-mainline entry
        MAINLINE_INDEX=$(grep -n "//linux-mainline" /boot/limine.conf | head -1 | cut -d: -f1)
        if [ -n "$MAINLINE_INDEX" ]; then
            # Count how many boot entries exist before the mainline entry
            # Entries start with "//" (2 slashes) but not "///" (3 slashes which are submenus)
            ENTRY_INDEX=$(awk -v line="$MAINLINE_INDEX" 'NR < line && /^  \/\/[^\/]/ {count++} END {print count}' /boot/limine.conf)

            # Update default_entry in limine.conf
            sudo sed -i "s/^default_entry:.*/default_entry: $ENTRY_INDEX/" /boot/limine.conf
            print_success "Mainline kernel (entry $ENTRY_INDEX) set as default in Limine"
        else
            print_error "Could not find linux-mainline entry in limine.conf"
        fi
    elif command_exists grub-mkconfig; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        print_success "GRUB configuration updated"

        # Set mainline as default in GRUB
        print_step "Setting mainline kernel as default..."
        sudo grub-set-default "Advanced options for Arch Linux>Arch Linux, with Linux linux-mainline" 2>/dev/null || \
        print_error "Could not set default - please set manually in GRUB menu"
    elif command_exists bootctl; then
        print_step "Setting mainline kernel as default for systemd-boot..."
        # Find the mainline boot entry
        MAINLINE_ENTRY=$(ls /boot/loader/entries/*linux-mainline.conf 2>/dev/null | head -1 | xargs basename 2>/dev/null)
        if [ -n "$MAINLINE_ENTRY" ]; then
            echo "default $MAINLINE_ENTRY" | sudo tee /boot/loader/loader.conf >/dev/null
            print_success "Mainline kernel set as default"
        else
            print_error "Could not find mainline boot entry - please set manually"
        fi
    else
        print_error "Unknown bootloader - please update manually"
    fi

    echo -e "${YELLOW}⚠${NC}  ${BOLD}Reboot required to use the mainline kernel${NC}\n"
fi

################################################################################
# 1. Install System Packages
################################################################################

if [ "$INSTALL_PACKAGES" = true ]; then
    print_header "Installing System Packages"

    PACKAGES=("npm" "nano" "micro" "nautilus" "uwsm" "docker")

    for pkg in "${PACKAGES[@]}"; do
        if package_installed "$pkg"; then
            print_skip "$pkg is already installed"
        else
            print_step "Installing $pkg..."
            sudo pacman -S --noconfirm "$pkg"
            print_success "$pkg installed"
        fi
    done

    # Configure Docker
    if package_installed "docker"; then
        # Enable and start Docker service
        if systemctl is-enabled docker.service &>/dev/null; then
            print_skip "Docker service is already enabled"
        else
            print_step "Enabling Docker service..."
            sudo systemctl enable docker.service
            print_success "Docker service enabled"
        fi

        if systemctl is-active docker.service &>/dev/null; then
            print_skip "Docker service is already running"
        else
            print_step "Starting Docker service..."
            sudo systemctl start docker.service
            print_success "Docker service started"
        fi

        # Add current user to docker group
        if groups "$USER" | grep -q "\bdocker\b"; then
            print_skip "User $USER is already in docker group"
        else
            print_step "Adding user $USER to docker group..."
            sudo usermod -aG docker "$USER"
            print_success "User $USER added to docker group"
            echo ""
            echo -e "${YELLOW}⚠  To use docker immediately, run:${NC} ${CYAN}newgrp docker${NC}"
            echo -e "${YELLOW}⚠  Or log out and log back in for permanent effect${NC}"
            echo ""
        fi
    fi

    # Install AUR packages via yay
    if command_exists yay; then
        AUR_PACKAGES=("1password-beta" "lazydocker")

        for aur_pkg in "${AUR_PACKAGES[@]}"; do
            print_step "Installing $aur_pkg from AUR..."
            if yay -Q "$aur_pkg" &>/dev/null; then
                print_skip "$aur_pkg is already installed"
            else
                yay -S --noconfirm "$aur_pkg"
                print_success "$aur_pkg installed"
            fi
        done
    else
        print_error "yay is not installed, skipping AUR packages (1password-beta, lazydocker)"
        print_error "Install yay first to install AUR packages"
    fi
fi

################################################################################
# 2. Install Claude Code
################################################################################

if [ "$INSTALL_CLAUDE" = true ]; then
    print_header "Installing Claude Code"

    # Check Node.js is available and version
    print_step "Checking Node.js version..."
    if ! command_exists node; then
        print_error "Node.js is not installed but should be available with npm package"
        print_error "Please ensure Node.js is installed"
        exit 1
    fi

    NODE_VERSION=$(node --version 2>/dev/null | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -lt 14 ]; then
        print_error "Node.js version $NODE_VERSION is too old. Minimum required: v14.0.0"
        exit 1
    fi
    print_success "Node.js $NODE_VERSION detected"

    # Ensure ~/.local/bin exists
    mkdir -p "$HOME/.local/bin"

    if command_exists claude; then
        print_step "Updating Claude Code to latest version..."
        npm install -g @anthropic-ai/claude-code --prefix "$HOME/.local"
        print_success "Claude Code updated"
    else
        print_step "Installing Claude Code globally..."
        npm install -g @anthropic-ai/claude-code --prefix "$HOME/.local"
        print_success "Claude Code installed"
    fi

    # Add ~/.local/bin to PATH for both Bash and Fish
    add_local_bin_to_path
fi

################################################################################
# 3. Install Codex CLI
################################################################################

if [ "$INSTALL_CODEX" = true ]; then
    print_header "Installing Codex CLI"

    # Check Node.js is available and version
    print_step "Checking Node.js version..."
    if ! command_exists node; then
        print_error "Node.js is not installed but should be available with npm package"
        print_error "Please ensure Node.js is installed or run: ./install.sh packages codex"
        exit 1
    fi

    NODE_VERSION=$(node --version 2>/dev/null | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -lt 14 ]; then
        print_error "Node.js version $NODE_VERSION is too old. Minimum required: v14.0.0"
        exit 1
    fi
    print_success "Node.js $NODE_VERSION detected"

    # Ensure ~/.local/bin exists
    mkdir -p "$HOME/.local/bin"

    if command_exists codex; then
        print_step "Updating Codex CLI to latest version..."
        npm install -g @openai/codex --prefix "$HOME/.local"
        print_success "Codex CLI updated"
    else
        print_step "Installing Codex CLI globally..."
        npm install -g @openai/codex --prefix "$HOME/.local"
        print_success "Codex CLI installed"
    fi

    # Add ~/.local/bin to PATH for both Bash and Fish
    add_local_bin_to_path
fi

################################################################################
# 4. Configure Screensaver
################################################################################

if [ "$INSTALL_SCREENSAVER" = true ]; then
    print_header "Configuring Screensaver"

    SCREENSAVER_SRC="$SCRIPT_DIR/config/screensaver/screensaver.txt"
    SCREENSAVER_DEST="$HOME/.config/omarchy/branding/screensaver.txt"

    if [ ! -f "$SCREENSAVER_SRC" ]; then
        print_error "Source screensaver.txt not found at $SCREENSAVER_SRC"
        print_error "Skipping screensaver configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$SCREENSAVER_DEST")"

        if [ -f "$SCREENSAVER_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"; then
                    print_skip "Screensaver is already up to date"
                else
                    print_step "Backing up existing screensaver.txt..."
                    BACKUP_FILE=$(create_backup "$SCREENSAVER_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating screensaver.txt..."
                    cp "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"
                    print_success "Screensaver updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$SCREENSAVER_SRC" "$SCREENSAVER_DEST" >/dev/null 2>&1; then
                    print_skip "Screensaver is already up to date"
                else
                    print_step "Backing up existing screensaver.txt..."
                    BACKUP_FILE=$(create_backup "$SCREENSAVER_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating screensaver.txt..."
                    cp "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"
                    print_success "Screensaver updated"
                fi
            fi
        else
            print_step "Copying screensaver.txt to $SCREENSAVER_DEST..."
            cp "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"
            print_success "Screensaver configured"
        fi
    fi
fi

################################################################################
# 5. Install Plymouth Theme
################################################################################

if [ "$INSTALL_PLYMOUTH" = true ]; then
    print_header "Installing Plymouth Theme (Cybex)"

    PLYMOUTH_SRC="$SCRIPT_DIR/config/plymouth/themes/cybex"
    PLYMOUTH_DEST="/usr/share/plymouth/themes/cybex"

    if [ ! -d "$PLYMOUTH_SRC" ]; then
        print_error "Source Plymouth theme not found at $PLYMOUTH_SRC"
        print_error "Skipping Plymouth theme installation..."
    else
        # Install theme files (excluding .claude directory)
        if [ ! -d "$PLYMOUTH_DEST" ]; then
            print_step "Installing Plymouth theme to $PLYMOUTH_DEST..."
            sudo mkdir -p "$PLYMOUTH_DEST"
            # Copy all files except hidden directories like .claude
            (cd "$PLYMOUTH_SRC" && sudo find . -type f ! -path '*/\.*' -exec cp --parents {} "$PLYMOUTH_DEST/" \;)
            print_success "Plymouth theme files installed"
        else
            print_skip "Plymouth theme directory already exists"
            print_step "Updating Plymouth theme files..."
            # Copy all files except hidden directories like .claude
            (cd "$PLYMOUTH_SRC" && sudo find . -type f ! -path '*/\.*' -exec cp --parents {} "$PLYMOUTH_DEST/" \;)
            print_success "Plymouth theme files updated"
        fi

        # Check if plymouth-set-default-theme command exists
        if ! command_exists plymouth-set-default-theme; then
            print_error "plymouth-set-default-theme command not found"
            print_error "Install Plymouth first: sudo pacman -S plymouth"
        else
            # Check if theme is already set
            CURRENT_THEME=$(sudo plymouth-set-default-theme)
            if [ "$CURRENT_THEME" = "cybex" ]; then
                print_skip "Plymouth theme 'cybex' is already active"
            else
                print_step "Setting Plymouth theme to 'cybex'..."
                sudo plymouth-set-default-theme -R cybex
                print_success "Plymouth theme 'cybex' enabled"
                print_step "Rebuilding initramfs (this may take a moment)..."
                if ! sudo mkinitcpio -P; then
                    print_error "CRITICAL: Failed to rebuild initramfs!"
                    print_error "Your system may not boot properly with the new theme."
                    print_error "Please try running 'sudo mkinitcpio -P' manually and check for errors."
                    print_error "Common issues: insufficient /boot space, missing kernel modules, or hook errors."
                    exit 1
                fi
                print_success "Initramfs rebuilt successfully"
            fi
        fi
    fi
fi

################################################################################
# 6. Configure Starship Prompt
################################################################################

if [ "$INSTALL_PROMPT" = true ]; then
    print_header "Configuring Starship Prompt"

    STARSHIP_SRC="$SCRIPT_DIR/config/starship/starship.toml"
    STARSHIP_DEST="$HOME/.config/starship.toml"

    if [ ! -f "$STARSHIP_SRC" ]; then
        print_error "Source starship.toml not found at $STARSHIP_SRC"
        print_error "Skipping Starship configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$STARSHIP_DEST")"

        if [ -f "$STARSHIP_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$STARSHIP_SRC" "$STARSHIP_DEST"; then
                    print_skip "Starship configuration is already up to date"
                else
                    print_step "Backing up existing starship.toml..."
                    BACKUP_FILE=$(create_backup "$STARSHIP_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating starship.toml..."
                    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
                    print_success "Starship configuration updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$STARSHIP_SRC" "$STARSHIP_DEST" >/dev/null 2>&1; then
                    print_skip "Starship configuration is already up to date"
                else
                    print_step "Backing up existing starship.toml..."
                    BACKUP_FILE=$(create_backup "$STARSHIP_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating starship.toml..."
                    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
                    print_success "Starship configuration updated"
                fi
            fi
        else
            print_step "Copying starship.toml to $STARSHIP_DEST..."
            cp "$STARSHIP_SRC" "$STARSHIP_DEST"
            print_success "Starship prompt configured"
        fi
    fi
fi

################################################################################
# 7. Configure macOS-style Shortcuts
################################################################################

if [ "$INSTALL_MACOS_KEYS" = true ]; then
    print_header "Configuring macOS-style Shortcuts"

    # Ensure keyd package is installed
    if package_installed "keyd"; then
        print_skip "keyd package already installed"
    else
        print_step "Installing keyd..."
        sudo pacman -S --noconfirm keyd
        print_success "keyd installed"
    fi

    KEYD_CONFIG_SRC="$SCRIPT_DIR/config/keyd/macos_shortcuts.conf"
    KEYD_CONFIG_DEST="/etc/keyd/default.conf"

    if [ ! -f "$KEYD_CONFIG_SRC" ]; then
        print_error "keyd config not found at $KEYD_CONFIG_SRC"
    else
        if sudo test -f "$KEYD_CONFIG_DEST"; then
            if command_exists cmp; then
                if sudo cmp -s "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"; then
                    print_skip "keyd configuration already up to date"
                else
                    print_step "Updating keyd configuration..."
                    sudo install -D "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"
                    print_success "keyd configuration updated"
                fi
            else
                if sudo diff -q "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST" >/dev/null 2>&1; then
                    print_skip "keyd configuration already up to date"
                else
                    print_step "Updating keyd configuration..."
                    sudo install -D "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"
                    print_success "keyd configuration updated"
                fi
            fi
        else
            print_step "Installing keyd configuration..."
            sudo install -D "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"
            print_success "keyd configuration installed"
        fi
    fi

    # Enable and start keyd service
    print_step "Enabling and starting keyd service..."
    if sudo systemctl enable --now keyd >/dev/null 2>&1; then
        print_success "keyd service enabled and running"
    else
        print_error "Failed to enable/start keyd - please verify 'sudo systemctl status keyd'"
    fi

    if sudo systemctl is-active --quiet keyd; then
        print_step "Reloading keyd to apply configuration..."
        if sudo keyd reload >/dev/null 2>&1; then
            print_success "keyd reloaded"
        else
            print_error "Failed to reload keyd - run 'sudo keyd reload' manually"
        fi
    fi

    # Ensure Kitty bindings are present
    KITTY_SRC="$SCRIPT_DIR/config/kitty/kitty.conf"
    KITTY_DEST="$HOME/.config/kitty/kitty.conf"

    if [ ! -f "$KITTY_SRC" ]; then
        print_error "Kitty config not found at $KITTY_SRC"
    else
        mkdir -p "$(dirname "$KITTY_DEST")"

        if [ -f "$KITTY_DEST" ]; then
            if command_exists cmp; then
                if cmp -s "$KITTY_SRC" "$KITTY_DEST"; then
                    print_skip "Kitty configuration already up to date"
                else
                    BACKUP_PATH="${KITTY_DEST}.bak.$(date +%Y%m%d%H%M%S)"
                    print_step "Backing up existing Kitty config to $BACKUP_PATH..."
                    cp "$KITTY_DEST" "$BACKUP_PATH"
                    print_step "Updating Kitty configuration..."
                    cp "$KITTY_SRC" "$KITTY_DEST"
                    print_success "Kitty configuration updated"
                fi
            else
                if diff -q "$KITTY_SRC" "$KITTY_DEST" >/dev/null 2>&1; then
                    print_skip "Kitty configuration already up to date"
                else
                    BACKUP_PATH="${KITTY_DEST}.bak.$(date +%Y%m%d%H%M%S)"
                    print_step "Backing up existing Kitty config to $BACKUP_PATH..."
                    cp "$KITTY_DEST" "$BACKUP_PATH"
                    print_step "Updating Kitty configuration..."
                    cp "$KITTY_SRC" "$KITTY_DEST"
                    print_success "Kitty configuration updated"
                fi
            fi
        else
            print_step "Installing Kitty configuration..."
            cp "$KITTY_SRC" "$KITTY_DEST"
            print_success "Kitty configuration installed"
        fi
    fi
fi

################################################################################
# 8. Generate SSH Key for GitHub
################################################################################

if [ "$INSTALL_SSH" = true ]; then
    print_header "Generating SSH Key for GitHub"

    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    SSH_PUB_KEY="$SSH_KEY_PATH.pub"

    # Ensure .ssh directory exists with correct permissions
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ -f "$SSH_KEY_PATH" ]; then
        print_skip "SSH key already exists at $SSH_KEY_PATH"
    else
        print_step "Generating new ED25519 SSH key..."
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$SSH_KEY_PATH" -N ""
        print_success "SSH key generated"
    fi

    # Check for ssh-agent configuration
    print_step "Checking SSH agent configuration..."

    # Check if ssh-agent is already configured to start automatically
    SSH_AGENT_CONFIGURED=false
    if grep -q "SSH_AUTH_SOCK" "$HOME/.bashrc" 2>/dev/null || grep -q "ssh-agent" "$HOME/.bashrc" 2>/dev/null; then
        SSH_AGENT_CONFIGURED=true
        print_skip "SSH agent startup already configured in .bashrc"
    fi

    # If not configured, add ssh-agent startup to .bashrc
    if [ "$SSH_AGENT_CONFIGURED" = false ]; then
        print_step "Adding SSH agent configuration to .bashrc..."
        cat >> "$HOME/.bashrc" << 'EOF'

# SSH Agent configuration (added by Omarchy post-install script)
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
fi
EOF
        print_success "SSH agent configuration added to .bashrc"
    fi

    # Try to add key to current agent if running, or start a new one
    set +e  # Temporarily disable exit on error
    ssh-add -l &>/dev/null
    SSH_AGENT_STATUS=$?

    if [ "$SSH_AGENT_STATUS" -eq 0 ] || [ "$SSH_AGENT_STATUS" -eq 1 ]; then
        # Agent is running (0 = has keys, 1 = no keys)
        if ssh-add -l 2>/dev/null | grep -q "$SSH_KEY_PATH"; then
            print_skip "SSH key already loaded in current ssh-agent"
        else
            print_step "Adding SSH key to current ssh-agent..."
            ssh-add "$SSH_KEY_PATH" 2>/dev/null
            if [ $? -eq 0 ]; then
                print_success "SSH key added to ssh-agent"
            else
                print_error "Failed to add key to ssh-agent (may need manual 'ssh-add ~/.ssh/id_ed25519')"
            fi
        fi
    elif [ "$SSH_AGENT_STATUS" -eq 2 ]; then
        # No agent running, start one for this session
        print_step "Starting ssh-agent for current session..."
        eval "$(ssh-agent -s)" >/dev/null 2>&1
        ssh-add "$SSH_KEY_PATH" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_success "SSH agent started and key added for current session"
            print_skip "Note: This agent is temporary. A persistent one will start on next login."
        else
            print_error "Failed to add key to ssh-agent (may need manual 'ssh-add ~/.ssh/id_ed25519')"
        fi
    fi
    set -e  # Re-enable exit on error
fi

################################################################################
# 9. Configure Hyprland Custom Settings
################################################################################

if [ "$INSTALL_HYPRLAND_BINDINGS" = true ]; then
    print_header "Configuring Hyprland Custom Settings"

    HYPRLAND_SRC_DIR="$SCRIPT_DIR/config/hyprland"
    HYPRLAND_DEST_DIR="$HOME/.config/hypr/custom"

    if [ ! -d "$HYPRLAND_SRC_DIR" ]; then
        print_error "Source hyprland directory not found at $HYPRLAND_SRC_DIR"
        print_error "Skipping Hyprland configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$HYPRLAND_DEST_DIR"

        # Backup existing files
        print_step "Backing up existing Hyprland custom configs..."
        BACKUP_DIR="$HYPRLAND_DEST_DIR.bak.$(date +%Y%m%d%H%M%S)"
        if [ "$(ls -A $HYPRLAND_DEST_DIR 2>/dev/null)" ]; then
            cp -r "$HYPRLAND_DEST_DIR" "$BACKUP_DIR"
            print_success "Backup created at $BACKUP_DIR"
        else
            print_skip "No existing files to backup"
        fi

        # Copy all files from source to destination, overwriting existing files
        print_step "Copying Hyprland configuration files to $HYPRLAND_DEST_DIR..."
        cp -r "$HYPRLAND_SRC_DIR/"* "$HYPRLAND_DEST_DIR/"
        print_success "Hyprland custom configuration installed"

        # Show which files were installed
        print_step "Installed configuration files:"
        for file in "$HYPRLAND_DEST_DIR"/*; do
            if [ -f "$file" ]; then
                echo "  • $(basename "$file")"
            fi
        done
    fi

    # Install Cybex app launcher scripts
    CYBEX_APPS_SRC="$SCRIPT_DIR/config/apps"
    CYBEX_APPS_DEST="/usr/local/bin"

    if [ ! -d "$CYBEX_APPS_SRC" ]; then
        print_error "Cybex apps directory not found at $CYBEX_APPS_SRC"
        print_error "Skipping Cybex apps installation..."
    else
        print_step "Installing Cybex app launcher scripts to $CYBEX_APPS_DEST..."

        for script in "$CYBEX_APPS_SRC"/*; do
            if [ -f "$script" ]; then
                script_name=$(basename "$script")
                sudo cp "$script" "$CYBEX_APPS_DEST/"
                sudo chmod +x "$CYBEX_APPS_DEST/$script_name"
                echo "  • $script_name"
            fi
        done

        print_success "Cybex app launcher scripts installed"
    fi
fi

################################################################################
# 10. Install Hyprland Auto-Tile Helper
################################################################################

if [ "$INSTALL_AUTO_TILE" = true ]; then
    print_header "Installing Hyprland Auto-Tile Helper"

    AUTO_TILE_SRC="$SCRIPT_DIR/scripts/auto-tile"
    AUTO_TILE_DEST="$HOME/.local/bin/auto-tile"

    AUTO_TILE_DEPS=(jq socat)
    AUTO_TILE_MISSING_PACKAGES=()

    for dep in "${AUTO_TILE_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            AUTO_TILE_MISSING_PACKAGES+=("$dep")
        fi
    done

    if [ ${#AUTO_TILE_MISSING_PACKAGES[@]} -gt 0 ]; then
        print_step "Installing auto-tile dependencies: ${AUTO_TILE_MISSING_PACKAGES[*]}..."
        sudo pacman -S --needed --noconfirm "${AUTO_TILE_MISSING_PACKAGES[@]}"
        print_success "auto-tile dependencies installed"
    fi

    AUTO_TILE_DEP_FAILURE=false
    for dep in "${AUTO_TILE_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            print_error "Dependency '$dep' is required for auto-tile but is still missing."
            AUTO_TILE_DEP_FAILURE=true
        fi
    done

    if [ "$AUTO_TILE_DEP_FAILURE" = true ]; then
        print_error "Skipping auto-tile installation until dependencies are resolved."
    elif [ ! -f "$AUTO_TILE_SRC" ]; then
        print_error "Source auto-tile script not found at $AUTO_TILE_SRC"
    else
        mkdir -p "$HOME/.local/bin"

        AUTO_TILE_UPDATED=false
        if [ -f "$AUTO_TILE_DEST" ] && command_exists cmp && cmp -s "$AUTO_TILE_SRC" "$AUTO_TILE_DEST"; then
            print_skip "auto-tile script already up to date"
        else
            print_step "Installing auto-tile helper to $AUTO_TILE_DEST..."
            cp "$AUTO_TILE_SRC" "$AUTO_TILE_DEST"
            chmod +x "$AUTO_TILE_DEST"
            AUTO_TILE_UPDATED=true
            print_success "auto-tile helper installed"
        fi

        HYPRLAND_EXECS="$HOME/.config/hypr/custom/execs.conf"

        if [ -f "$HYPRLAND_EXECS" ]; then
            if grep -q "exec-once = ~/.local/bin/auto-tile" "$HYPRLAND_EXECS"; then
                print_skip "auto-tile already in Hyprland execs"
            else
                print_step "Adding auto-tile to Hyprland execs..."
                echo "" >> "$HYPRLAND_EXECS"
                echo "# Auto-tile first window per workspace" >> "$HYPRLAND_EXECS"
                echo "exec-once = ~/.local/bin/auto-tile" >> "$HYPRLAND_EXECS"
                print_success "auto-tile added to Hyprland execs"
            fi
        else
            print_error "Hyprland execs.conf not found at $HYPRLAND_EXECS"
            print_error "Add 'exec-once = ~/.local/bin/auto-tile' manually to enable the helper"
        fi

        if [ -f "$AUTO_TILE_DEST" ]; then
            print_step "Starting auto-tile helper for current session..."
            if pgrep -f "$AUTO_TILE_DEST" >/dev/null 2>&1; then
                if [ "$AUTO_TILE_UPDATED" = true ]; then
                    print_step "Restarting auto-tile helper with updated script..."
                    pkill -f "$AUTO_TILE_DEST" || true
                    sleep 0.5
                    "$AUTO_TILE_DEST" >/dev/null 2>&1 &
                    print_success "auto-tile helper restarted"
                else
                    print_skip "auto-tile helper is already running"
                fi
            else
                "$AUTO_TILE_DEST" >/dev/null 2>&1 &
                print_success "auto-tile helper started"
            fi
        fi
    fi
fi

################################################################################
# Installation Complete
################################################################################

print_header "Installation Complete!"

echo -e "${GREEN}All tasks completed successfully!${NC}\n"

# Only show installed components summary if something was actually installed
if [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PACKAGES" = true ] || \
   [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ] || \
   [ "$INSTALL_SCREENSAVER" = true ] || [ "$INSTALL_PLYMOUTH" = true ] || \
   [ "$INSTALL_PROMPT" = true ] || [ "$INSTALL_MACOS_KEYS" = true ] || \
   [ "$INSTALL_HYPRLAND_BINDINGS" = true ] || [ "$INSTALL_AUTO_TILE" = true ] || \
   [ "$INSTALL_SSH" = true ]; then

    echo -e "${BOLD}Installed/configured components:${NC}"

    if [ "$INSTALL_MAINLINE" = true ]; then
        echo -e "  • ${CYAN}linux-mainline${NC} kernel (Chaotic-AUR)"
    fi

    if [ "$INSTALL_PACKAGES" = true ]; then
        echo -e "  • System packages (npm, nano)"
    fi

    if [ "$INSTALL_CLAUDE" = true ]; then
        echo -e "  • Claude Code (${CYAN}claude${NC} command)"
    fi

    if [ "$INSTALL_CODEX" = true ]; then
        echo -e "  • Codex CLI (${CYAN}codex${NC} command)"
    fi

    if [ "$INSTALL_SCREENSAVER" = true ]; then
        echo -e "  • Custom screensaver"
    fi

    if [ "$INSTALL_PLYMOUTH" = true ]; then
        echo -e "  • Cybex Plymouth theme"
    fi

    if [ "$INSTALL_PROMPT" = true ]; then
        echo -e "  • Starship prompt configuration"
    fi

    if [ "$INSTALL_MACOS_KEYS" = true ]; then
        echo -e "  • macOS-style shortcuts (keyd + Kitty)"
    fi

    if [ "$INSTALL_HYPRLAND_BINDINGS" = true ]; then
        echo -e "  • Hyprland custom settings"
    fi

    if [ "$INSTALL_AUTO_TILE" = true ]; then
        echo -e "  • Hyprland auto-tile helper"
    fi

    if [ "$INSTALL_SSH" = true ]; then
        echo -e "  • SSH key for GitHub"
    fi

    echo ""
fi

# Show SSH setup instructions only if SSH key was configured
if [ "$INSTALL_SSH" = true ]; then
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${MAGENTA}  GitHub SSH Setup${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        echo -e "${BOLD}Your SSH public key:${NC}\n"
        cat "$HOME/.ssh/id_ed25519.pub"
        echo -e "\n${BOLD}To add this key to GitHub:${NC}"
    else
        echo -e "${RED}SSH public key not found!${NC}\n"
        echo -e "${BOLD}To add your key to GitHub:${NC}"
    fi
    echo -e "  1. Copy the key above (entire line)"
    echo -e "  2. Go to ${CYAN}https://github.com/settings/ssh/new${NC}"
    echo -e "  3. Paste the key and give it a title (e.g., 'Omarchy Linux')"
    echo -e "  4. Click 'Add SSH key'\n"

    echo -e "${BOLD}To test the connection:${NC}"
    echo -e "  ${CYAN}ssh -T git@github.com${NC}\n"
fi

# Next steps section - only show if there are actual next steps
if [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ] || \
   [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PLYMOUTH" = true ] || \
   [ "$INSTALL_MACOS_KEYS" = true ] || [ "$INSTALL_AUTO_TILE" = true ]; then

    echo -e "${BOLD}Next steps:${NC}"

    # PATH update reminder - show only if Claude or Codex were installed
    if [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ]; then
        echo -e "  • Run ${CYAN}source ~/.bashrc${NC} or restart your shell to update PATH"
    fi

    # Mainline kernel reboot reminder
    if [ "$INSTALL_MAINLINE" = true ]; then
        echo -e "  • ${BOLD}${YELLOW}Reboot to use the mainline kernel${NC}"
    fi

    # Plymouth theme reboot reminder
    if [ "$INSTALL_PLYMOUTH" = true ]; then
        echo -e "  • Reboot to see the new Plymouth boot splash"
    fi

    if [ "$INSTALL_MACOS_KEYS" = true ]; then
        echo -e "  • Reload Hyprland (${CYAN}hyprctl reload${NC}) and restart Alacritty to pick up the new shortcuts"
    fi

    if [ "$INSTALL_AUTO_TILE" = true ]; then
        echo -e "  • Reload Hyprland (${CYAN}hyprctl reload${NC}) if the auto-tile helper does not engage immediately"
    fi

    echo ""
fi
