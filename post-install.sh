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
      htop atool zip unzip 7zip usbutils ranger \
      usbmuxd libimobiledevice android-tools udiskie udisks2 jmtpfs \
      powertop tlp asusctl supergfxctl rog-control-center \
      fcitx5 fcitx5-unikey fcitx5-configtool fcitx5-gtk \
      obs-vaapi wlrobs obs-studio mpv ani-cli gstreamer-vaapi \
      foot nicotine+ easytag imv visual-studio-code-bin obsidian \
      gitui git-filter-repo nodejs pnpm eslint prettier terminus-font \
      python python-pip python-virtualenv zen-browser-bin \
      vesktop-bin steam mangohud ttf-liberation cmatrix-git \
      zoom pavucontrol blueman onlyoffice-bin
  else
    echo "paru not found; skipping AUR installs."
  fi

  # Enable some services
  for svc in usbmuxd supergfxd; do
    systemctl enable "$svc"
  done
fi

###############################################
# 4. NVIDIA Driver (Optional)
###############################################
read -rp "Install NVIDIA driver? [Y/N]: " install_nvidia
if [[ $install_nvidia =~ ^[Yy]$ ]]; then
  pacman -S --noconfirm --needed nvidia-open nvidia-utils libva-nvidia-driver lib32-nvidia-utils
fi

###############################################
# 5. DNS Over TLS w/ Cloudflare (Optional)
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
# 6. Power Services (Optional)
###############################################
read -rp "Enable TLP, Powertop, fstrim & disable some services? [Y/N]: " power_opt
if [[ $power_opt =~ ^[Yy]$ ]]; then
  [[ -f tlp.conf ]] && cp tlp.conf /etc/tlp.conf
  [[ -f powertop.service ]] && cp powertop.service /etc/systemd/system/
  systemctl enable tlp powertop fstrim
  # disabling unnecessary ones
  for svc in remote-fs systemd-userdbd.socket system-journal-gatewayd.socket \
             system-journal-remote.service avahi-daemon NetworkManager-wait-online \
             NetworkManager-dispatcher; do
    systemctl disable "$svc" || true
  done
fi

###############################################
# 7. ZRAM (Optional)
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
# 8. Final Step
###############################################
echo "All done. Rebooting now…"
reboot

