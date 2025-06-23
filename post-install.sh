#!/bin/bash
set -euo pipefail

###############################################
# 0. Root Check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

###############################################
# 1. System Update
###############################################
echo "=== Enable multilib repo and updating the system (pacman -Syu) ==="
sed -i '/^\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
pacman -Syu --noconfirm

###############################################
# 2. Install paru (Optional)
###############################################
read -p "Install paru? (required unless you already have paru) [Y/N]: " install_paru_choice
if [[ "$install_paru_choice" =~ ^[Yy]$ ]]; then
  read -p "Enter username: " username </dev/tty
  # Store the original working directory
  ORIG_PWD="$(pwd)"

  # Clone paru into ~/paru
  echo "Cloning paru repository into ~/paru..."
  rm -rf /home/"$username"/paru 2>/dev/null || true
  sudo -u "$username" git clone https://aur.archlinux.org/paru.git /home/"$username"/paru

  # Build and install paru
  cd /home/"$username"/paru
  echo "Building and installing paru..."
  sudo -u "$username" makepkg -si --noconfirm
  # Return to original directory
  cd "$ORIG_PWD"
  rm -rf /home/"$username"/paru

  # Check if paru is installed
  if ! command -v paru &>/dev/null; then
    echo "paru installation failed or wasn't found in PATH. Trying once more..."
    
    # Try building again
    sudo -u "$username" git clone https://aur.archlinux.org/paru.git /home/"$username"/paru
    cd /home/"$username"/paru
    sudo -u "$username" makepkg -si --noconfirm
    
    cd "$ORIG_PWD"
    rm -rf /home/"$username"/paru

    # Final check
    if ! command -v paru &>/dev/null; then
      echo "Failed to install paru after second attempt. Exiting..."
      exit 1
    fi
  fi
fi

###############################################
# 3. Install Additional Packages (Optional)
###############################################
read -p "Install additional packages? [Y/N]: " install_additional_choice
if [[ "$install_additional_choice" =~ ^[Yy]$ ]]; then
  read -p "Enter username: " username </dev/tty
  if command -v paru &>/dev/null; then
    echo "Installing AUR packages with paru..."
    sudo -u "$username" paru -S --noconfirm --needed \
      htop atool zip unzip 7zip usbutils ranger \
      usbmuxd libimobiledevice android-tools udiskie udisks2 jmtpfs \
      powertop tlp \
      asusctl supergfxctl rog-control-center \
      fcitx5 fcitx5-unikey fcitx5-configtool fcitx5-gtk kwindowsystem \
      obs-vaapi wlrobs obs-studio \
      mpv ani-cli gstreamer-vaapi kew foot nicotine+ easytag imv \
      visual-studio-code-bin obsidian gitui git-filter-repo nodejs pnpm eslint prettier python python-pip python-virtualenv \
      zen-browser-bin vesktop-bin \
      steam mangohud ttf-liberation \
      cmatrix-git zoom pavucontrol blueman onlyoffice-bin
  else
    echo "paru not found. Skipping AUR packages..."
  fi
  systemctl enable usbmuxd
  systemctl enable supergfxd
fi

###############################################
# 4. Installing NVIDIA driver (Optional)
###############################################

read -p "Install NVIDIA driver? [Y/N]: " install_driver
if [[ "$install_driver" =~ ^[Yy]$ ]]; then
    echo "Installing NVIDIA driver..."
    pacman -S --noconfirm --needed nvidia nvidia-utils
fi

###############################################
# 5. DNS Configuration with 1.1.1.1 (Optional)
###############################################
read -p "Use 1.1.1.1 DNS (DNSOverTLS)? [Y/N]: " dns_choice
if [[ "$dns_choice" =~ ^[Yy]$ ]]; then
  # Only append if we don't find the lines already
  if ! grep -q "DNS=1.1.1.1#one.one.one.one" /etc/systemd/resolved.conf 2>/dev/null; then
    echo "Adding Cloudflare DNS to /etc/systemd/resolved.conf..."
    cat <<EOF >> /etc/systemd/resolved.conf

DNS=1.1.1.1#one.one.one.one
DNSOverTLS=yes
EOF
  else
    echo "DNS lines already present in /etc/systemd/resolved.conf. Skipping append."
  fi

  echo "Enabling and starting systemd-resolved.service..."
  systemctl enable systemd-resolved.service
  systemctl start systemd-resolved.service
fi

###############################################
# 6. Enable TLP and Powertop (Optional)
###############################################
read -p "Enable TLP, Powertop services, Fstrim and disable some ? [Y/N]: " power_choice
if [[ "$power_choice" =~ ^[Yy]$ ]]; then
  # Check if tlp.conf is present in current directory
  if [ -f tlp.conf ]; then
    echo "Copying tlp.conf to /etc/"
    cp tlp.conf /etc/tlp.conf
  else
    echo "tlp.conf not found in the current directory. Skipping copy..."
  fi

  # Check if powertop.service is present in current directory
  if [ -f powertop.service ]; then
    echo "Copying powertop.service to /etc/systemd/system/"
    cp powertop.service /etc/systemd/system/powertop.service
  else
    echo "powertop.service not found in the current directory. Skipping copy..."
  fi

  echo "Enabling tlp and powertop..."
  systemctl enable tlp
  systemctl enable powertop
  systemctl enable fstrim
  systemctl disable remote-fs.service
  systemctl disable systemd-userdbd.socket
  systemctl disable system-journal-gatewayd.socket
  systemctl disable system-journal-remote.service
  systemctl disable avahi-daemon.service
  systemctl disable NetworkManager-wait-online.service
  systemctl disable NetworkManager-dispatcher.service
fi

###############################################
# 7. Set up ZRAM (Optional)
###############################################

read -p "Enable ZRAM? [Y/N]: " zram_choice
if [[ "$zram_choice" =~ ^[Yy]$ ]]; then
  echo "=== Installing zram-generator ==="
  pacman -Sy --noconfirm zram-generator

  echo "=== Writing /etc/systemd/zram-generator.conf ==="
  cat <<'EOF' > /etc/systemd/zram-generator.conf
[zram0]
# allocate up to 50% of RAM, capped at 4 GiB
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF

  echo "=== Reloading systemd & enabling ZRAM swap service ==="
  systemctl daemon-reload
  systemctl enable --now systemd-zram-setup@zram0.service

  echo "ZRAM swap is now enabled, dawg!"
fi

###############################################
# 8. Final Step: Reboot
###############################################

echo "All steps complete. Rebooting now..."
reboot
