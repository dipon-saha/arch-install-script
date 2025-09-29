# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., use sudo)"
  exit
fi

ZRAM_SIZE="8G"  # Set the desired size for ZRAM

# Install util-linux if not already installed
echo "Installing util-linux package..."
pacman -S --needed util-linux

# Ensure zram module is loaded at boot
echo "Loading zram module at boot..."
echo "zram" > /etc/modules-load.d/zram.conf

# Create a udev rule to configure zram
echo "Creating udev rule for zram..."
cat <<EOF > /etc/udev/rules.d/99-zram.rules
ACTION=="add", KERNEL=="zram0", ATTR{comp_algorithm}="zstd", ATTR{disksize}="$ZRAM_SIZE", RUN="/usr/bin/mkswap -U clear /dev/%k", TAG+="systemd"
EOF

echo "Udev rule created at /etc/udev/rules.d/99-zram.rules"

# Add zram to /etc/fstab for automatic swap configuration
echo "Configuring /etc/fstab for zram swap..."
echo '/dev/zram0 none swap defaults,discard,pri=100 0 0' >> /etc/fstab

echo "ZRAM swap setup completed successfully!"
