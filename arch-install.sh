#!/bin/bash
set -euo pipefail

# Ensure this script is run as root.
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

###############################################
# 1. Base System Installation via pacstrap
###############################################
echo "=== Starting Base Installation ==="
pacstrap -i /mnt \
  base base-devel linux linux-firmware git sudo fastfetch neovim \
  bluez bluez-utils networkmanager htop intel-ucode fish alacritty \
  ttf-font-awesome ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk \
  gcc gdb make cmake clang cargo brightnessctl zip unzip wget \
  pipewire pipewire-pulse wireplumber sof-firmware efibootmgr dosfstools \
  mtools grub os-prober gitui ranger fcitx5 fcitx5-unikey fcitx5-configtool fcitx5-gtk kwindowsystem

echo "Generating fstab..."
genfstab -U /mnt > /mnt/etc/fstab
echo "Fstab generated. You can review /mnt/etc/fstab if needed."

###############################################
# 2. Chroot and System Configuration
###############################################
echo "=== Entering Chroot Environment ==="
arch-chroot /mnt /bin/bash <<'EOF'
set -euo pipefail

echo "=== Configuring the New System ==="

###############################################
# Set Root Password
###############################################
echo "Setting root password..."
read -s -p "Enter new root password: " root_pass </dev/tty
echo
read -s -p "Re-enter new root password: " root_pass_confirm </dev/tty
echo
if [ "$root_pass" != "$root_pass_confirm" ]; then
  echo "Root passwords do not match. Exiting..."
  exit 1
fi
echo "root:$root_pass" | chpasswd
echo "Root password successfully set."

###############################################
# Create a New User and Set Its Password
###############################################
read -p "Enter new username: " username </dev/tty
useradd -m -g users -G wheel,storage,power,video,audio -s /bin/bash "$username"
echo "Setting password for user '$username'..."
read -s -p "Enter password for $username: " user_pass </dev/tty
echo
read -s -p "Re-enter password for $username: " user_pass_confirm </dev/tty
echo
if [ "$user_pass" != "$user_pass_confirm" ]; then
  echo "User passwords do not match. Exiting..."
  exit 1
fi
echo "$username:$user_pass" | chpasswd
echo "User password successfully set."

###############################################
# Configure Sudoers
###############################################
echo "Configuring sudoers to allow wheel group sudo access..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

###############################################
# Set Timezone and Hardware Clock
###############################################
echo "Setting timezone to Asia/Ho_Chi_Minh..."
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

###############################################
# Configure Locale
###############################################
echo "Configuring locale..."
sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

###############################################
# Set Hostname and Hosts File
###############################################
read -p "Enter hostname (recommended: same as username): " hostname </dev/tty
echo "$hostname" > /etc/hostname
cat <<HOSTS_EOF > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    ${hostname}.localdomain $hostname
HOSTS_EOF

###############################################
# Install and Configure GRUB Bootloader
###############################################
echo "Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

###############################################
# Enable Essential Services
###############################################
echo "Enabling essential services (NetworkManager and fstrim.timer)..."
systemctl enable NetworkManager fstrim.timer

###############################################
# Set Fish as Default Shell for Root and User
###############################################
echo "Setting fish as default shell for root and user '$username'..."
chsh -s "$(which fish)"
chsh -s "$(which fish)" "$username"

###############################################
# Fix Ownership & Permissions of User's Home
###############################################
echo "Adjusting ownership and permissions for /home/$username..."

groupadd "$username"
chown -R "$username:$username" "/home/$username"
chmod -R 777 "/home/$username"

echo "=== Chroot configuration complete! ==="
EOF

###############################################
# 3. Final Steps
###############################################
echo "=== Finalizing Installation ==="
echo "Unmounting all partitions under /mnt..."
umount -lR /mnt
echo "Installation complete! Reboot your system to boot into your new Arch installation."

