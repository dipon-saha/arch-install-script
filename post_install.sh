#!/usr/bin/env bash

# Enable pacman parallel multilib, downloads and ILoveCandy
sudo sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
sudo sed -i '/^\[multilib\]/,/^$/s/^#Include/Include/' /etc/pacman.conf
sudo sed -i 's/^[#]*ParallelDownloads = .*/ParallelDownloads = 8/' /etc/pacman.conf
sudo sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
echo "Pacman configuration updated."

# Update system
sudo pacman -Syu --noconfirm

# Install Paru AUR helper
echo "Installing Paru AUR helper..."
git clone https://aur.archlinux.org/paru.git /tmp/paru
cd /tmp/paru
makepkg -si --noconfirm
cd -
rm -rf /tmp/paru
echo "Paru installed."

# Enable zram with zram_conf.sh
echo "Enabling ZRAM for swap..."
sudo bash ./zram_conf.sh
echo "ZRAM enabled."

# Snapper installation and configuration
echo "Installing and configuring Snapper..."
sudo pacman -S --needed snapper \
                        grub-btrfs \
                        snap-pac \
                        inotify-tools --noconfirm

paru -S --needed btrfs-assistant --noconfirm

sudo snapper -c root create-config /
sudo snapper -c home create-config /home

sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes
sudo snapper -c home set-config ALLOW_USERS="$USER" SYNC_ACL=yes

# OverlayFs hook for Snapper in /etc/mkinitcpio.conf
echo "Configuring mkinitcpio for Snapper..."
grep "HOOKS" /etc/mkinitcpio.conf | grep -q "overlayfs"
if [ $? -ne 0 ]; then
    echo "Adding overlayfs to HOOKS in /etc/mkinitcpio.conf"
    if ! grep -E '^HOOKS=.*overlayfs' /etc/mkinitcpio.conf > /dev/null; then
        sudo sed -i 's/^HOOKS=(\(.*\))/HOOKS=(\1 overlayfs)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    else
        echo "overlayfs already present in HOOKS."
    fi
fi

# Enable grub-btrfsd service
echo "Enabling grub-btrfsd service..."
sudo systemctl enable grub-btrfsd.service
echo "Snapper installation and configuration completed."

# Audio setup
sudo pacman -S --needed pipewire \
                        pipewire-alsa \
                        pipewire-jack \
                        pipewire-pulse \
                        gst-plugin-pipewire \
                        libpulse \
                        wireplumber --noconfirm
sudo systemctl enable --now pipewire pipewire-pulse wireplumber
echo "Audio setup completed."

# Bluetooth setup
sudo pacman -S --needed bluez \
                        bluez-utils \
                        blueman --noconfirm
sudo systemctl enable --now bluetooth
echo "Bluetooth setup completed."

# tools
sudo pacman -S --needed openssh \
                        htop \
                        wget \
                        curl --noconfirm

# Display Manager
sudo pacman -S --needed sddm --noconfirm
sudo systemctl enable sddm

# Hyprland and related packages
sudo pacman -S --needed hyprland \
                        dunst \
                        kitty \
                        dolphin \
                        wofi \
                        xdg-desktop-portal-hyprland \
                        qt5-wayland \
                        qt6-wayland \
                        polkit-kde-agent \
                        grim \
                        slurp \
                        networkmanager-applet --noconfirm
