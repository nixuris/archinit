#!/usr/bin/env bash
set -euo pipefail

###############################################
# 0. Root Check + Real User Detection
###############################################
if (( EUID != 0 )); then
  echo "Please run this script as root (e.g. via sudo)." >&2
  exit 1
fi

# the user who called sudo, or $USER if not using sudo
real_user="${SUDO_USER:-$USER}"

###############################################
# 1. System Update
###############################################
echo "=== Enabling multilib & updating system ==="
sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
pacman -Syu --noconfirm

###############################################
# 2. Install paru (Optional)
###############################################
read -rp "Install paru? [Y/N]: " install_paru
if [[ $install_paru =~ ^[Yy]$ ]]; then
	build_dir=/tmp/paru-build
	rm -rf "$build_dir"
	echo "Cloning paru ..."
	sudo -u "$real_user" git clone https://aur.archlinux.org/paru.git "$build_dir"
	pushd "$build_dir" >/dev/null
		echo "Building & installing paru ..."
		sudo -u "$real_user" makepkg -si --noconfirm
	popd >/dev/null
	rm -rf "$build_dir"
  # double-check
  if ! command -v paru &>/dev/null; then
    echo "paru install failed. Exiting." >&2
    exit 1
  fi
fi

###############################################
# 3. Install Additional Packages (Optional)
###############################################
read -rp "Install additional AUR & community packages? [Y/N]: " install_pkgs
if [[ $install_pkgs =~ ^[Yy]$ ]]; then
  if command -v paru &>/dev/null; then
    echo "Installing additional packages with paru..."
    sudo -u "$real_user" paru -S --noconfirm --needed \
      btop htop atool zip unzip 7zip usbutils ranger \
      usbmuxd libimobiledevice android-tools udiskie udisks2 jmtpfs \
      powertop tlp asusctl supergfxctl rog-control-center \
      fcitx5 fcitx5-unikey fcitx5-configtool fcitx5-gtk \
      obs-vaapi wlrobs obs-studio mpv ani-cli gstreamer-vaapi \
      foot nicotine+ easytag imv visual-studio-code-bin obsidian \
      vesktop-bin steam mangohud ttf-liberation cmatrix-git \
      zoom pavucontrol blueman onlyoffice-bin zen-browser-bin
  else
    echo "paru not found; skipping AUR installs."
  fi

  # Enable some services
  for svc in usbmuxd supergfxd; do
    systemctl enable "$svc"
  done
fi

###############################################
# 4. Dev (Optional)
###############################################
read -rp "Install some dev tools that I personally use? Uses fish as shell (git, gitui, python, nodejs, npm) [Y/N]: " install_dev
if [[ $install_dev =~ ^[Yy]$ ]]; then
  sudo -u "$real_user" paru -S --noconfirm --needed gitui git-filter-repo nodejs npm python python-pip python-virtualenv
  read -rp "Set global installation as user wide for npm? (require fish shell) [Y/N]: " npm_user
    if [[ $npm_user =~ ^[Yy]$ ]]; then
      sudo -u "$real_user" bash <<'EONPM'
# --- Configuration for User-Wide npm Setup ---
NPM_GLOBAL_PREFIX="$HOME/.local"
NPM_BIN_PATH="$NPM_GLOBAL_PREFIX/bin"
NPM_LIB_PATH="$NPM_GLOBAL_PREFIX/lib/node_modules"
FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONF_D_DIR="$FISH_CONFIG_DIR/conf.d"
NPM_FISH_CONFIG_FILE="$FISH_CONF_D_DIR/npm.fish"
# --------------------------------------------

echo "Starting user-wide npm setup for Fish shell..."

# Configure npm to use the user's local directory as prefix
echo "Setting npm global prefix to '$NPM_GLOBAL_PREFIX'..."
npm config set prefix "$NPM_GLOBAL_PREFIX"
if [ $? -ne 0 ]; then
    echo "Failed to set npm prefix. Aborting."
    exit 1
fi
echo "npm prefix set successfully."

# Create necessary directories
echo "Creating necessary directories: $NPM_BIN_PATH and $NPM_LIB_PATH..."
mkdir -p "$NPM_BIN_PATH" "$NPM_LIB_PATH"
if [ $? -ne 0 ]; then
    echo "Failed to create directories. Aborting."
    exit 1
fi
echo "Directories created/ensured."

# Create or update the npm.fish configuration for Fish shell
echo "Creating/updating Fish shell config file: $NPM_FISH_CONFIG_FILE..."
mkdir -p "$FISH_CONF_D_DIR"
cat << EOF > "$NPM_FISH_CONFIG_FILE"
# ~/.config/fish/conf.d/npm.fish

# NPM User-Wide Global Package Configuration
# This ensures global npm packages installed to ~/.local/bin are found.

set -gx NPM_GLOBAL_BIN "$HOME/.local/bin"

if not string match -q -- $NPM_GLOBAL_BIN $PATH
  set -gx PATH "$NPM_GLOBAL_BIN" $PATH
end
EOF

if [ $? -ne 0 ]; then
    echo "❌ Failed to create npm.fish configuration. Aborting."
    exit 1
fi
echo "npm.fish configuration created successfully."

echo "--- Setup Complete! ---"
echo "To activate the changes, please do ONE of the following:"
echo "1. Open a new Fish shell terminal."
echo "2. Run: 'source $FISH_CONFIG_DIR/config.fish' in your current Fish session."
echo ""
echo "--- Verification Steps ---"
echo "After activating the changes, run these commands to verify:"
echo "1. Verify npm prefix:         npm config get prefix"
echo "   (Should show: '$NPM_GLOBAL_PREFIX')"
echo "2. Install a global package:  npm install -g npm-check-updates"
echo "3. Verify package executable: which ncu"
echo "   (Should show: '$NPM_BIN_PATH/ncu')"
echo ""
EONPM
    fi
fi
###############################################
# 5. NVIDIA Driver (Optional)
###############################################
read -rp "Install NVIDIA driver? [Y/N]: " install_nvidia
if [[ $install_nvidia =~ ^[Yy]$ ]]; then
  pacman -S --noconfirm --needed nvidia-open nvidia-utils libva-nvidia-driver lib32-nvidia-utils
fi
###############################################
# 6. DNS Over TLS w/ Cloudflare (Optional)
###############################################
read -rp "Use Cloudflare DNS (1.1.1.1#one.one.one.one) with DNSOverTLS? [Y/N]: " dns_tls
if [[ $dns_tls =~ ^[Yy]$ ]]; then
  if ! grep -q 'DNS=1.1.1.1#one.one.one.one' /etc/systemd/resolved.conf; then
    cat <<'EOF' >> /etc/systemd/resolved.conf

DNS=1.1.1.1#one.one.one.one
DNSOverTLS=yes
EOF
  fi
  systemctl enable --now systemd-resolved
fi

###############################################
# 7. Power Services (Optional)
###############################################
read -rp "Enable TLP, Powertop, fstrim & disable some services? [Y/N]: " power_opt
if [[ $power_opt =~ ^[Yy]$ ]]; then
  cat <<'EOF' > /etc/tlp.conf
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_performance
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0
CPU_MAX_PERF_ON_AC=100
CPU_MAX_PERF_ON_BAT=70
CPU_MIN_PERF_ON_AC=0
CPU_MIN_PERF_ON_BAT=0
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
DISK_IDLE_SECS_ON_AC=30
DISK_IDLE_SECS_ON_BAT=30
PCIE_ASPM_ON_AC=powersupersave
PCIE_ASPM_ON_BAT=powersupersave
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=balanced
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=10
START_CHARGE_THRESH_BAT0=85
STOP_CHARGE_THRESH_BAT0=90
USB_AUTOSUSPEND=1
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
EOF
  cat <<'EOF' > /etc/systemd/system/powertop.service
[Unit]
Description=Powertop auto-tune
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable tlp powertop fstrim
  # disabling unnecessary ones
  for svc in remote-fs systemd-userdbd.socket system-journal-gatewayd.socket \
             system-journal-remote.service avahi-daemon NetworkManager-wait-online \
             NetworkManager-dispatcher; do
    systemctl disable "$svc" || true
  done
fi

###############################################
# 8. ZRAM (Optional)
###############################################
read -rp "Enable ZRAM swap? [Y/N]: " zram_opt
if [[ $zram_opt =~ ^[Yy]$ ]]; then
  pacman -Sy --noconfirm zram-generator
  cat <<'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
  systemctl daemon-reload
  systemctl enable --now systemd-zram-setup@zram0
fi

###############################################
# 9. Final Step
###############################################
echo "All done."
read -rp "Rebooting now? [Y/N]: " reboot_opt
if [[ $reboot_opt =~ ^[Yy]$ ]]; then
reboot
else
  echo "Remember to reboot to apply some changes!"
fi
