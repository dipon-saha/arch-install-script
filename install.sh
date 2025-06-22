#!/bin/bash

# This script is used to install Arch Linux with BTRFS layout.

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or switch to the root user."
    exit 1
fi

# Check if the configuration file exists
if [ ! -f ./install.conf ]; then
    echo "Configuration file 'install.conf' not found. Please create it before running this script."
    exit 1
fi
# Source configuration file
. ./install.conf

# Ask for unattended installation
if [[ -z "$UNATTENDED" ]]; then
    echo "Installation Mode:"
    echo "1) Interactive (ask for confirmation at each step)"
    echo "2) Unattended (use configuration file values)"
    read -p "Choose installation mode (1/2): " MODE_CHOICE
    
    case $MODE_CHOICE in
        1)
            UNATTENDED="no"
            ;;
        2)
            UNATTENDED="yes"
            # Check if all required variables are set
            if [[ -z "$DISK" || -z "$TIME_ZONE" || -z "$HOST_NAME" || -z "$ROOT_PASS" || -z "$USER_NAME" || -z "$USER_PASS" ]]; then
                echo "Error: Some required variables are not set in install.conf for unattended installation."
                echo "Required variables: DISK, TIME_ZONE, HOST_NAME, ROOT_PASS, USER_NAME, USER_PASS"
                exit 1
            fi
            ;;
        *)
            echo "Invalid choice. Defaulting to interactive mode."
            UNATTENDED="no"
            ;;
    esac
fi

# Main function to execute the installation steps
main() {
    echo "Starting Arch Linux Installation..."
    
    # Check Boot Mode
    echo "Checking boot mode..."
    cat /sys/firmware/efi/fw_platform_size > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "This script requires UEFI mode. Please boot the system in UEFI mode and try again."
        exit 1
    fi
    echo "UEFI mode confirmed."

    # Setting NTP for time synchronization
    echo "Setting up NTP for time synchronization..."
    timedatectl set-ntp true
    if [ $? -ne 0 ]; then
        echo "Failed to set NTP. Please check your network connection."
        exit 1
    fi
    echo "Time synchronization enabled."

    # Disk Setup
    echo "Starting disk setup..."
    disk_setup
    echo "Disk setup completed."

    # Install base system
    echo "Installing base system packages..."
    pacstrap /mnt base base-devel linux linux-firmware btrfs-progs grub efibootmgr vim networkmanager git
    if [ $? -ne 0 ]; then
        echo "Failed to install base packages."
        exit 1
    fi
    echo "Base system installed."

    # Generate fstab
    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "fstab generated."

    # Configure system in chroot
    echo "Configuring system..."
    chroot_setup
    echo "System configuration completed."

    # echo "Unmounting partitions..."
    # umount -R /mnt
    # echo "Installation completed successfully!"
    # echo "You can now reboot into your new Arch Linux system."
}

# Function to set up the disk
disk_setup() {    # Check if unattended installation is enabled and if the disk variable is set
    if [[ "$UNATTENDED" == "yes" && -z "$DISK" ]]; then
        echo "Error: DISK variable is not set in install.conf for unattended installation."
        exit 1
    fi

    # If not unattended, present a menu to select disk
    if [[ "$UNATTENDED" != "yes" ]]; then
        echo "Available disks:"
        mapfile -t DISK_LIST < <(lsblk -d -o NAME,SIZE,TYPE | grep disk | awk '{print "/dev/" $1 " (" $2 ")"}')
        for i in "${!DISK_LIST[@]}"; do
            echo "$((i+1))) ${DISK_LIST[$i]}"
        done
        echo ""
        read -p "Select the disk to use [1-${#DISK_LIST[@]}]: " DISK_CHOICE
        if [[ "$DISK_CHOICE" =~ ^[0-9]+$ ]] && (( DISK_CHOICE >= 1 && DISK_CHOICE <= ${#DISK_LIST[@]} )); then
            DISK=$(echo "${DISK_LIST[$((DISK_CHOICE-1))]}" | awk '{print $1}')
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi

    echo "Using disk: $DISK"
      # Confirm disk selection
    if [[ "$UNATTENDED" != "yes" ]]; then
        echo "WARNING: This will erase all data on $DISK"
        echo "1) Yes, continue with installation"
        echo "2) No, cancel installation"
        read -p "Choose option (1/2): " CONFIRM
        case $CONFIRM in
            1)
                echo "Proceeding with installation..."
                ;;
            2|*)
                echo "Installation cancelled."
                exit 1
                ;;
        esac
    fi    # Boot Partition
    if [[ "$UNATTENDED" != "yes" ]]; then
        # Get the current partition table and save it
        echo "Current partition table:"
        CURRENT_TABLE=$(fdisk -l $DISK)
  
        # Create a new partition
        echo "Creating new Boot partition (512M)"
        # Ask for Size confirmation
        echo "Press Enter to continue or specify a size (e.g., 512M, 1G)"
        read -r SIZE
        if [[ -z "$SIZE" ]]; then
            SIZE="512M"
        fi
        NEW_TABLE=$(create_partition "$SIZE" "n")
        # Show partitions
        echo ""
        echo "Old partitions"
        echo "$CURRENT_TABLE" | grep "$DISK"
        echo ""
        echo "New partitions"
        echo "$NEW_TABLE" | grep "$DISK"
        echo ""

        # Confirm writing changes
        echo "WARNING: This will write changes to the disk."
        echo "1) Yes, write boot partition changes"
        echo "2) No, cancel installation"
        read -p "Choose option (1/2): " CONFIRM_WRITE
        if [[ "$CONFIRM_WRITE" != "1" ]]; then
            echo "Installation cancelled."
            exit 1
        fi
    fi

    BOOT_PARTITION=$(create_partition "$SIZE" "y")
    echo "Created boot partition: $BOOT_PARTITION"
    mkfs.fat -F 32 "$BOOT_PARTITION"

    # Root Partition
    if [[ "$UNATTENDED" != "yes" ]]; then
        # Get the current partition table and save it
        echo "Current partition table:"
        CURRENT_TABLE=$(fdisk -l $DISK)

        # Create a new partition
        echo "Creating new Root partition (remaining space)"
        # Ask for Size confirmation
        echo "Press Enter to continue or specify a size (e.g., 64G, 1T)"
        read -r SIZE
        if [[ -z "$SIZE" ]]; then
            SIZE=""
        fi
        NEW_TABLE=$(create_partition "$SIZE" "n")
        # Show partitions
        echo ""
        echo "Old partitions"
        echo "$CURRENT_TABLE" | grep "$DISK"
        echo ""
        echo "New partitions"
        echo "$NEW_TABLE" | grep "$DISK"
        echo ""

        # Confirm writing changes
        echo "WARNING: This will write changes to the disk."
        echo "1) Yes, write root partition changes"
        echo "2) No, cancel installation"
        read -p "Choose option (1/2): " CONFIRM_WRITE
        if [[ "$CONFIRM_WRITE" != "1" ]]; then
            echo "Installation cancelled."
            exit 1
        fi
    fi

    ROOT_PARTITION=$(create_partition "$SIZE" "y")
    echo "Created root partition: $ROOT_PARTITION"
    mkfs.btrfs "$ROOT_PARTITION"

    mount_disk
}


# Function to create partitions
create_partition() {
    local SIZE=$1
    local CONFIRM_WRITE=$2

    FDISK_OUTPUT=$(( 
    echo n    # Add a new partition
    echo p    # Primary partition
    echo      # Default partition number
    echo      # Default first sector
    if [ -z "$SIZE" ]; then
        echo      # Use remaining space if no size is provided
    else
        echo +$SIZE  # Set partition size if provided
    fi
    if [ "$CONFIRM_WRITE" == "y" ]; then
        echo w    # Write the changes only if confirmation is provided
    else
        echo p    # Prints modified table
        echo q    # Quit without saving changes
    fi
    ) | fdisk $DISK 2>&1)

    # Step 2: Extract the partition number from the fdisk output (only if written)
    if [ "$CONFIRM_WRITE" == "y" ]; then
        PARTITION_NUMBER=$(echo "$FDISK_OUTPUT" | grep -oP '(?<=Created a new partition )[0-9]+')

        # Check if a partition number was found
        if [ -z "$PARTITION_NUMBER" ]; then
            echo "Failed to create partition."
            exit 1
        fi

        # Full partition path (e.g., /dev/sda1)
        PARTITION=${DISK}${PARTITION_NUMBER}

        partprobe $DISK
        echo $PARTITION
    else
        # Just show the fdisk output without writing changes
        echo "$FDISK_OUTPUT"
    fi
}

# Function to mount disk with BTRFS subvolumes
mount_disk() {
    mount "$ROOT_PARTITION" /mnt

    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@pkg

    umount /mnt

    mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@ "$ROOT_PARTITION" /mnt

    mkdir -p /mnt/boot/efi
    mount "$BOOT_PARTITION" /mnt/boot/efi

    mkdir -p /mnt/home
    mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@home "$ROOT_PARTITION" /mnt/home

    mkdir -p /mnt/var/log
    mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@log "$ROOT_PARTITION" /mnt/var/log

    mkdir -p /mnt/var/cache/pacman/pkg
    mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@pkg "$ROOT_PARTITION" /mnt/var/cache/pacman/pkg
}

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

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers.d/$USER_NAME

# Install bootloader
echo "Installing bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
EOF
}

# Execute the script
main "$@"
