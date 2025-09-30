# Function to configure the system in chroot environment
chroot_setup() {
    # Get system configuration interactively if not in unattended mode
    if [[ "$UNATTENDED" != "yes" ]]; then
        echo "System Configuration:"
        
        # Timezone
        if [[ -z "$TIME_ZONE" ]]; then
            echo "Available timezones (examples): America/New_York, Europe/London, Asia/Tokyo, Asia/Kuala_Lumpur"
            read -p "Enter timezone [$TIME_ZONE]: " NEW_TIMEZONE
            TIME_ZONE=${NEW_TIMEZONE:-$TIME_ZONE}
        fi
        
        # Hostname
        if [[ -z "$HOST_NAME" ]]; then
            read -p "Enter hostname [$HOST_NAME]: " NEW_HOSTNAME
            HOST_NAME=${NEW_HOSTNAME:-$HOST_NAME}
        fi
        
        # Root password
        if [[ -z "$ROOT_PASS" ]]; then
            read -s -p "Enter root password: " NEW_ROOT_PASS
            echo
            ROOT_PASS=${NEW_ROOT_PASS:-$ROOT_PASS}
        fi
        
        # Username
        if [[ -z "$USER_NAME" ]]; then
            read -p "Enter username [$USER_NAME]: " NEW_USER_NAME
            USER_NAME=${NEW_USER_NAME:-$USER_NAME}
        fi
        
        # User password
        if [[ -z "$USER_PASS" ]]; then
            read -s -p "Enter user password: " NEW_USER_PASS
            echo
            USER_PASS=${NEW_USER_PASS:-$USER_PASS}
        fi
    fi

arch-chroot /mnt /bin/bash <<EOF

# Set timezone
echo "Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
hwclock --systohc

# Localization
echo "Setting locale..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "Setting hostname..."
echo "$HOST_NAME" > /etc/hostname

# Set hosts file
echo "Configuring hosts file..."
cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST_NAME.localdomain    $HOST_NAME
EOL

# Set root password
echo "Setting root password..."
echo root:$ROOT_PASS | chpasswd

useradd -m -G wheel $USER_NAME
echo $USER_NAME:$USER_PASS | chpasswd

# create subvolumes for user cache
btrfs subvolume create /home/$USER_NAME/.cache
chown $USER_NAME:$USER_NAME /home/$USER_NAME/.cache

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers.d/$USER_NAME

# Install bootloader
echo "Installing bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

# Generate GRUB configuration
echo "Enabling os-prober in GRUB configuration..."
if grep -q '^[#]*GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
    sed -i 's/^[#]*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
    echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
fi

echo "Set GRUB_TIMEOUT to 3 seconds..."
if grep -q '^[#]*GRUB_TIMEOUT=' /etc/default/grub; then
    sed -i 's/^[#]*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
else
    echo 'GRUB_TIMEOUT=3' >> /etc/default/grub
fi

echo "Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "Enabling essential services..."
systemctl enable NetworkManager
systemctl enable pipewire pipewire-pulse wireplumber
systemctl enable --now bluetooth

# Exit chroot
exit
EOF
}