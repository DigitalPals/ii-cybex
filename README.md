# Illogical Impulse Cybex

```
                     $$a.
                      `$$$
 .a&$$$&a, a$$a..a$$a. `$$bd$$$&a,    .a&$""$&a     .a$$a..a$$a.
d#7^' `^^' `Q$$bd$$$^   1$#7^' `^Q$, d#7@Qbd@'' d$   Q$$$$$$$$P
Y$b,. .,,.    Q$$$$'   .$$$b.. .,d7' Q$&a,..,a&$P'  .d$$$PQ$$$b
 `@Q$$$P@'    d$$$'    `^@Q$$$$$@"'   `^@Q$$$P@^'   @Q$P@  @Q$P@
             @$$P
```

## About

A post-installation setup script for **Illogical Impulse** on Arch Linux to fine-tune system settings and install personalized tools for John's workflow. This script is designed to be idempotent and safe to run multiple times.

## Features

This script automates the installation and configuration of:

- 📦 **System Packages** - Essential tools (npm, nano)
- 🤖 **Claude Code** - Anthropic's AI-powered coding assistant CLI
- 💻 **Codex CLI** - OpenAI's Codex command-line interface
- 🎨 **Custom Screensaver** - Personalized ASCII art screensaver
- 🚀 **Plymouth Theme** - Cybex boot splash theme
- ⭐ **Starship Prompt** - Modern, customized shell prompt (optional, not installed with `all`)
- ⌨️  **macOS-style Shortcuts** - keyd remaps + Kitty bindings for Super+C/V/A/Z
- 🖥️  **Hyprland Custom Settings** - All custom Hyprland configs copied to ~/.config/hypr/custom/ with automatic backup
- 🪟 **Auto-Tile Helper** - Automatically float first window per workspace, tile when second opens
- 🔑 **SSH Key** - Generate and configure SSH key for GitHub
- 🐧 **Mainline Kernel** - Latest mainline Linux kernel (Chaotic-AUR)

## Prerequisites

- **Illogical Impulse** on Arch Linux
- **sudo** privileges
- **Internet connection** (for downloading packages)
- At least **1GB free disk space** (for kernel installation)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/DigitalPals/ii-cybex.git
cd ii-cybex

# Make the script executable
chmod +x install.sh

# Install everything (except mainline kernel)
./install.sh all

# Or install specific components
./install.sh claude ssh starship
```

## Usage

```bash
./install.sh [OPTION]...
```

### Available Options

| Option | Description | Alias |
|--------|-------------|-------|
| `all` | Install all components (except mainline kernel and Starship) | - |
| `packages` | Install system packages (npm, nano) | - |
| `claude` | Install Claude Code CLI | - |
| `codex` | Install OpenAI Codex CLI | - |
| `screensaver` | Configure custom screensaver | - |
| `plymouth` | Install Cybex Plymouth boot theme | - |
| `prompt` | Configure Starship prompt (not included in `all`) | `starship` |
| `macos-keys` | Configure keyd macOS-style shortcuts and Kitty bindings | - |
| `hyprland` | Copy all Hyprland custom configs to ~/.config/hypr/custom/ | `hyprland-bindings` |
| `auto-tile` | Install Hyprland auto-tiling helper | - |
| `ssh` | Generate SSH key for GitHub | `ssh-key` |
| `mainline` | Install and configure mainline kernel | - |

### Examples

```bash
# Show help and available options
./install.sh

# Install everything except mainline kernel
./install.sh all

# Install Claude Code and generate SSH key
./install.sh claude ssh

# Configure Starship prompt and install Codex
./install.sh prompt codex

# Configure macOS-style shortcuts (keyd + Alacritty)
./install.sh macos-keys

# Install Hyprland auto-tile helper
./install.sh auto-tile

# Install multiple specific components
./install.sh packages claude codex ssh

# Install mainline kernel only
./install.sh mainline
```

## Component Details

### System Packages
Installs essential development tools:
- **npm** - Node.js package manager
- **nano** - Text editor

### Claude Code
Installs Anthropic's Claude Code CLI globally to `~/.local/bin`. Automatically adds the directory to your PATH if needed.

### Codex CLI
Installs OpenAI's Codex command-line interface for AI-assisted coding.

### Custom Screensaver
Installs a complete terminal-based screensaver system using `tte` (terminal text effects):
- ASCII art screensaver file deployed to `~/.config/cybex/branding/screensaver.txt`
- Uses Kitty terminal emulator to display screensaver
- Three helper scripts: `cybex-launch-screensaver`, `cybex-cmd-screensaver`, `cybex-toggle-screensaver`
- Animated ASCII art with random effects from the `tte` package
- Configures hypridle for automatic activation:
  - 2.5 minutes idle: Screensaver launches
  - 5 minutes idle: Screen locks (password required)
  - 5.5 minutes idle: Display turns off
- Hot corner activation via waycorner:
  - Move mouse to bottom-left corner: Launch screensaver instantly
  - Move mouse to top-right corner: Lock screen (password required)

### Plymouth Theme (Cybex)
Installs the Cybex boot splash theme and rebuilds the initramfs. **Requires reboot** to take effect.

### Starship Prompt
Configures a modern, informative shell prompt with:
- Git status indicators
- Language version detection (Node.js, Python, Java, PHP)
- Directory path display
- Custom styling

### macOS-style Shortcuts
Installs and configures keyd plus updated Kitty bindings so `SUPER+C/V/A/Z` behave like macOS while all Hyprland shortcuts keep working.

### Hyprland Custom Settings
Deploys all custom Hyprland configuration files from `config/hyprland/` to `~/.config/hypr/custom/`. This includes:
- Key bindings (keybinds.conf → custom directory)
- Input configuration (input.conf → custom directory)
- Any other custom configuration files

All existing files in `~/.config/hypr/custom/` are backed up before being overwritten, so you can safely restore them if needed.

### Auto-Tile Helper
Installs a background helper script that provides intelligent window management for Hyprland:
- **First window** on any workspace - Automatically floats and centers at 60% screen size
- **Second window opens** - Both windows automatically switch to tiled mode
- **Window closes** - Remaining single window returns to floating/centered

Dependencies (`jq`, `socat`) are installed automatically. The helper starts immediately and is added to Hyprland autostart for persistence across reboots.

### SSH Key
Generates an ED25519 SSH key pair and configures ssh-agent for automatic key loading. Provides instructions for adding the key to GitHub.

### Mainline Kernel
Installs the latest mainline Linux kernel from Chaotic-AUR. Automatically configures the bootloader to use the new kernel. **Requires reboot** to use the new kernel.

## Important Notes

- ✅ **Idempotent** - Safe to run multiple times without causing issues
- 🔒 **No root required** - Do not run with sudo; the script will request privileges when needed
- 🌐 **Internet required** - Most components require downloading packages
- 🔄 **Reboot needed** - Mainline kernel and Plymouth theme require a reboot
- 📁 **PATH updates** - After installing Claude/Codex, run `source ~/.bashrc` (or restart Fish shell) to update PATH

## macOS-style Shortcuts (keyd)

Get global macOS-style shortcuts (`SUPER+C/V/A/Z`) while keeping Hyprland bindings such as `SUPER+ENTER`:

```bash
./install.sh macos-keys
```

This target:
- Installs `keyd` if necessary and deploys `keyd/macos_shortcuts.conf` to `/etc/keyd/default.conf`
- Enables and reloads the `keyd` service so the remap is active immediately
- Installs the curated `kitty/kitty.conf`, backing up your existing file the first time so Kitty maps `CTRL+Insert`/`Shift+Insert` to copy/paste

After the script finishes:
- Reload Hyprland (`hyprctl reload`) and restart Kitty to pick up the new bindings.
- Test `SUPER+C/V/A/Z` in Chromium or another GUI app, and in Kitty to confirm copy/paste works without sending SIGINT.
- Use `sudo keyd -m` if you want to inspect the translated key events in real time.

## Post-Installation

After running the script:

1. **Update PATH** (if Claude or Codex was installed):
   ```bash
   source ~/.bashrc
   ```

2. **Add SSH key to GitHub** (if SSH key was generated):
   - Copy the displayed public key
   - Go to https://github.com/settings/ssh/new
   - Paste and save

3. **Reboot** (if mainline kernel or Plymouth theme was installed):
   ```bash
   sudo reboot
   ```

## Troubleshooting

- **Permission denied**: Ensure the script is executable with `chmod +x install.sh`
- **Command not found**: After installing CLI tools, restart your shell or run `source ~/.bashrc`
- **Boot issues**: If the mainline kernel causes problems, select the default kernel from the boot menu

## Author

**John** - Customized for personal Illogical Impulse installations

## License

This is a personal configuration repository. Feel free to fork and adapt to your needs.

---

**Illogical Impulse** - https://github.com/end-4/dots-hyprland
