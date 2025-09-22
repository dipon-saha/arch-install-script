#!/bin/bash

# Set the variables appropriately
# Don't forget to set the variable PASS for admin and user password
TIME_ZONE="Asia/Kuala_Lumpur"
HOST_NAME="archlinux"
USER_PASS="pass"

# Timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

hwclock --systohc
hwclock -w

# Set the locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set the hostname
echo "$HOST_NAME" > /etc/hostname

# Set the hosts file
echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOST_NAME.localdomain	$HOST_NAME" >> /etc/hosts

# Set the root password
echo "root:$USER_PASS" | chpasswd

# Install and configure grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install necessary packages (customize as needed)
pacman -Sy networkmanager # Add other packages as required

# Enable NetworkManager
systemctl enable NetworkManager

# Adding User
useradd -m -G wheel black
echo "black:$USER_PASS" | chpasswd

# # Set up sudo for the user
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/black
