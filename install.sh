#!/bin/bash

# This script is used to install Arch Linux with BTRFS layout.

error() {
    echo "Error: $1"
    if [[ "$2" == "fatal" ]]; then
        echo "Exiting installation."
        exit 1
    fi
}

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or switch to the root user."
    error "Not running as root." "fatal"
fi

# Check if the configuration file exists
if [ ! -f ./install.conf ]; then
    echo "Configuration file 'install.conf' not found. Please create it before running this script."
    error "Missing configuration file."
else
    # Load configuration
    . ./install.conf
    if [ $? -ne 0 ]; then
        echo "Failed to load configuration file. Please check its contents."
        error "Failed to load configuration."
    fi
fi

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
        error "Missing required configuration variables for unattended installation." "fatal"
    fi
fi



# Source disk configuration script
. ./disk_conf.sh
if [ $? -ne 0 ]; then
    error "Failed to load disk configuration script." "fatal"
fi
# Source chroot configuration script
. ./chroot_conf.sh
if [ $? -ne 0 ]; then
    error "Failed to load chroot configuration script." "fatal"
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

    cp ./* /mnt/root/arch-install-script/

    # Configure system in chroot
    echo "Configuring system..."
    chroot_setup
    echo "System configuration completed."

    # echo "Unmounting partitions..."
    # umount -R /mnt
    # echo "Installation completed successfully!"
    # echo "You can now reboot into your new Arch Linux system."
}


# Execute the script
main "$@"
