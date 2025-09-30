#!/bin/bash

# This script is used to install Arch Linux with BTRFS layout.

error() {
    echo "Error: $1"
    if [[ "$2" == "fatal" ]]; then
        echo "Exiting installation."
        exit 1
    fi
}

check_config_vars() {
    local required_vars=("DISK" "TIME_ZONE" "HOST_NAME" "ROOT_PASS" "USER_NAME" "USER_PASS")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "Configuration variable '$var' is not set. Please set it in install.conf."
            return 1
        fi
    done
    return 0
}


# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    error "Not running as root." "fatal"
fi

# Check if the configuration file exists and disk_conf.sh exists and chroot_conf.sh exists
if [ ! -f ./disk_conf.sh ]; then
    error "Missing disk configuration script (disk_conf.sh)." "fatal"
elif [ ! -f ./chroot_conf.sh ]; then
    error "Missing chroot configuration script (chroot_conf.sh)." "fatal"
elif [ ! -f ./install.conf ]; then
    error "Missing Installation configuration file (install.conf), Unattended Mode disabled."
    UNATTENDED="no"
else
    source ./disk_conf.sh
    source ./chroot_conf.sh
    source ./install.conf
    if [ $? -ne 0 ]; then
        error "Failed to source configuration files." "fatal"
    fi
fi

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
            ;;
        *)
            echo "Invalid choice. Defaulting to interactive mode."
            UNATTENDED="no"
            ;;
    esac
fi

if [[ "$UNATTENDED" == "yes" ]]; then
    check_config_vars
    if [ $? -ne 0 ]; then
        error "Missing required configuration variables for unattended installation. Please check install.conf." "fatal"
    fi
fi





# Main function to execute the installation steps
main() {
    echo "Starting Arch Linux Installation..."
    
    # Check Boot Mode
    echo "Checking boot mode..."
    cat /sys/firmware/efi/fw_platform_size > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        error "System is not booted in UEFI mode. Please boot in UEFI mode to proceed." "fatal"
    fi
    echo "UEFI mode confirmed."


    # Setting NTP for time synchronization
    echo "Setting up NTP for time synchronization..."
    timedatectl set-ntp true
    if [ $? -ne 0 ]; then
        echo "Failed to set NTP. Please check your network connection."
        error "NTP setup failed."
    fi
    echo "Time synchronization enabled."


    # Disk Setup
    echo "Starting disk setup..."
    disk_setup
    if [ $? -ne 0 ]; then
        error "Disk setup failed." "fatal"
    fi
    echo "Disk setup completed."
    # Mount Disk
    echo "Mounting disk partitions..."
    mount_disk
    if [ $? -ne 0 ]; then
        error "Failed to mount disk partitions." "fatal"
    fi

    # Enable pacman parallel downloads
    echo "Enabling parallel downloads in pacman..."
    sed -i '/^#\?ParallelDownloads *=.*/c\ParallelDownloads = 10' /etc/pacman.conf

    # Install base system
    echo "Installing base system packages..."
    
    # Install packages from packages.list, ignoring comments and blank lines
    pacstrap /mnt $(grep -vE '^\s*#|^$' packages.list | awk '{print $1}')
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
    # copy install script to new system for future reference
    mkdir -p /mnt/home/$USER_NAME/arch-install-script/
    cp ./* /mnt/home/$USER_NAME/arch-install-script/
    chown -R $USER_NAME:$USER_NAME /mnt/home/$USER_NAME/arch-install-script/
    echo "Unmounting partitions..."
    umount -R /mnt
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to unmount /mnt. Some processes may still be using the mount points."
        echo "Please check and unmount manually if needed."
    fi
    echo "Installation completed successfully!"
    echo "You can now reboot into your new Arch Linux system."
}


# Execute the script
main "$@"
