#!/bin/bash
set -euo pipefail

# Ensure the script is running as root.
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

echo "=== Base Installation ==="
pacstrap -i /mnt \
  base base-devel linux linux-firmware git sudo fastfetch neovim \
  bluez bluez-utils networkmanager htop intel-ucode fish alacritty \
  ttf-font-awesome ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk \
  gcc gdb make cmake clang cargo powertop brightnessctl gvfs gvfs-mtp zip unzip wget \
  pipewire pipewire-pulse wireplumber sof-firmware feh nwg-look efibootmgr dosfstools \
  mtools grub os-prober

echo "Generating fstab..."
genfstab -U /mnt > /mnt/etc/fstab
echo "fstab generated at /mnt/etc/fstab."

echo "=== Chrooting into the System ==="
arch-chroot /mnt /bin/bash <<'EOF'
set -euo pipefail

# 1. Set root password
echo "Setting root password..."
passwd

# 2. Create a new user and set its password
read -p "Enter new username: " username
useradd -m -g users -G wheel,storage,power,video,audio -s /bin/bash "$username"
echo "Setting password for user $username..."
passwd "$username"

# 3. Configure sudoers to allow the wheel group sudo access
echo "Configuring sudoers..."
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# 4. Set timezone and hardware clock
echo "Setting timezone to Asia/Ho_Chi_Minh..."
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

# 5. Configure locale
echo "Configuring locale..."
sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 6. Set hostname and hosts file
read -p "Enter hostname (recommend same as username): " hostname
echo "$hostname" > /etc/hostname
cat <<HOSTS_EOF > /etc/hosts
127.0.0.1       localhost
::1             localhost
127.0.1.1       ${hostname}.localdomain $hostname
HOSTS_EOF

# 7. Install and configure GRUB
echo "Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# 8. Enable essential services
echo "Enabling NetworkManager and fstrim.timer..."
systemctl enable NetworkManager fstrim.timer

# 9. Install paru for AUR
echo "Installing paru for AUR..."
cd /home/"$username"
sudo -u "$username" git clone https://aur.archlinux.org/paru.git
cd paru
sudo -u "$username" makepkg -si

# 10. Set fish as default shell
echo "Setting fish as default shell for root and $username..."
chsh -s $(which fish)
chsh -s $(which fish) "$username"

EOF

echo "=== Final Steps ==="
echo "Unmounting /mnt..."
umount -lR /mnt
echo "Installation complete! Reboot to boot into your new system."

