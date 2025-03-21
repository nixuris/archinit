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
echo "=== Updating the system (pacman -Syu) ==="
pacman -Syu --noconfirm

###############################################
# 2. Install flatpak and paru (Optional)
###############################################
read -p "Install flatpak and paru? [Y/N]: " install_paru_choice
if [[ "$install_paru_choice" =~ ^[Yy]$ ]]; then
  echo "Installing flatpak..."
  pacman -S --noconfirm flatpak

  # Store the original working directory so we can return here later
  ORIG_PWD="$(pwd)"

  # Clone paru into /tmp/paru
  echo "Cloning paru repository into /tmp/paru..."
  rm -rf /tmp/paru 2>/dev/null || true
  git clone https://aur.archlinux.org/paru.git /tmp/paru

  # Build and install paru
  cd /tmp/paru
  echo "Building and installing paru..."
  makepkg -si --noconfirm

  # Return to original directory
  cd "$ORIG_PWD"
  rm -rf /tmp/paru

  # Check if paru is installed
  if ! command -v paru &>/dev/null; then
    echo "paru installation failed or wasn't found in PATH. Trying once more..."
    
    # Try building again
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru
    makepkg -si --noconfirm
    
    cd "$ORIG_PWD"
    rm -rf /tmp/paru

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
  if command -v paru &>/dev/null; then
    echo "Installing AUR packages with paru..."
    paru -S --noconfirm --needed \
      obs-vaapi wlrobs visual-studio-code-bin zen browser-bin cmatrix-git zoom obsidian
  else
    echo "paru not found. Skipping AUR packages..."
  fi

  echo "Installing packages with pacman..."
  pacman -S --noconfirm --needed \
    pavucontrol tlp blueman gstreamer-vaapi obs-studio
fi

###############################################
# 4. DNS Configuration with 1.1.1.1 (Optional)
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
# 5. Enable TLP and Powertop (Optional)
###############################################
read -p "Enable TLP and Powertop services? [Y/N]: " power_choice
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
fi

###############################################
# 6. Final Step: Reboot
###############################################
echo "All steps complete. Rebooting now..."
reboot

