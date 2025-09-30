#!/usr/bin/env bash

# Enable pacman parallel multilib, downloads and ILoveCandy
sudo sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
sudo sed -i '/^\[multilib\]/,/^$/s/^#Include/Include/' /etc/pacman.conf
sudo sed -i 's/^[#]*ParallelDownloads = .*/ParallelDownloads = 8/' /etc/pacman.conf
sudo sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
echo "Pacman configuration updated."

# Update system
sudo pacman -Syu --noconfirm
echo "System updated."

# Enable zram with zram_conf.sh
echo "Enabling ZRAM for swap..."
sudo bash ./zram_conf.sh
echo "ZRAM enabled."

# Install packages from extra_packages.list, ignoring comments and blank lines
echo "Installing additional packages..."
sudo pacman -S $(grep -vE '^\s*#|^$' extra_packages.list | awk '{print $1}') --noconfirm
if [ $? -ne 0 ]; then
    echo "Failed to install some packages. Please check the package names in extra_packages.list."
    exit 1
else
    echo "Additional packages installed."
fi

# Snapper Configuration
echo "Configuring Snapper..."
sudo snapper -c root create-config /
sudo snapper -c home create-config /home

sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes
sudo snapper -c home set-config ALLOW_USERS="$USER" SYNC_ACL=yes

# OverlayFs hook for Snapper in /etc/mkinitcpio.conf
echo "Configuring mkinitcpio for Snapper with OverlayFS..."
grep "HOOKS" /etc/mkinitcpio.conf | grep -q "grub-btrfs-overlayfs"
if [ $? -ne 0 ]; then
    echo "Adding grub-btrfs-overlayfs to HOOKS in /etc/mkinitcpio.conf"
    if ! grep -E '^HOOKS=.*grub-btrfs-overlayfs' /etc/mkinitcpio.conf > /dev/null; then
        sudo sed -i 's/^HOOKS=(\(.*\))/HOOKS=(\1 grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    else
        echo "grub-btrfs-overlayfs already present in HOOKS."
    fi
fi

# Enable grub-btrfsd service
echo "Enabling grub-btrfsd service..."
sudo systemctl enable grub-btrfsd.service
echo "Snapper installation and configuration completed."

# Install Paru AUR helper
echo "Installing Paru AUR helper..."
git clone https://aur.archlinux.org/paru.git /tmp/paru
cd /tmp/paru
makepkg -si --noconfirm
cd -
rm -rf /tmp/paru
echo "Paru installed."

# Enable essential services
sudo systemctl enable pipewire pipewire-pulse wireplumber
sudo systemctl enable --now bluetooth

# # Enable SDDM display manager
# echo "Enabling SDDM display manager..."
# sudo systemctl enable sddm