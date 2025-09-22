# Function to set up the disk
disk_setup() {    # Check if unattended installation is enabled and if the disk variable is set

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
            error "Invalid disk selection." "fatal"
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
                error "Installation cancelled by user." "fatal"
                ;;
        esac
    fi    # Boot Partition
    if [[ "$UNATTENDED" != "yes" ]]; then
        # Get the current partition table and save it
        echo "Current partition table:"
        CURRENT_TABLE=$(fdisk -l $DISK)
  
        # Create a new partition
        echo "Creating new Boot partition of 512M"
        # Ask for Size confirmation
        echo "Press Enter to continue or specify a size (e.g., 512M, 1G)"
        read -r BOOT_SIZE
        if [[ -z "$BOOT_SIZE" ]]; then
            BOOT_SIZE="512M"
        fi
        NEW_TABLE=$(create_partition "$BOOT_SIZE" "n")
        # Show partitions
        echo "+++++++++++++++++++++++++++++++++++"
        echo "Old partitions"
        echo "$CURRENT_TABLE" | grep "$DISK"
        echo "+++++++++++++++++++++++++++++++++++"
        echo "New partitions"
        echo "$NEW_TABLE" | grep "$DISK"
        echo "+++++++++++++++++++++++++++++++++++"

        # Confirm writing changes
        echo "WARNING: This will write changes to the disk."
        echo "1) Yes, write boot partition changes"
        echo "2) No, cancel installation"
        read -p "Choose option (1/2): " CONFIRM_WRITE
        if [[ "$CONFIRM_WRITE" != "1" ]]; then
            error "Installation cancelled by user." "fatal"
        fi
    fi

    BOOT_PARTITION=$(create_partition "$BOOT_SIZE" "y")
    echo "Created boot partition: $BOOT_PARTITION"
    mkfs.fat -F 32 "$BOOT_PARTITION"
    if [ $? -ne 0 ]; then
        error "Failed to format boot partition." "fatal"
    fi

    # Root Partition
    if [[ "$UNATTENDED" != "yes" ]]; then
        # Get the current partition table and save it
        echo "Current partition table:"
        CURRENT_TABLE=$(fdisk -l $DISK)

        # Create a new partition
        echo "Creating new Root partition (remaining space)"
        # Ask for Size confirmation
        echo "Press Enter to continue or specify a size (e.g., 64G, 1T)"
        read -r ROOT_SIZE
        if [[ -z "$ROOT_SIZE" ]]; then
            ROOT_SIZE=""
        fi
        NEW_TABLE=$(create_partition "$ROOT_SIZE" "n")
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
            error "Installation cancelled by user." "fatal"
        fi
    fi

    ROOT_PARTITION=$(create_partition "$ROOT_SIZE" "y")
    echo "Created root partition: $ROOT_PARTITION"
    mkfs.btrfs "$ROOT_PARTITION"
    if [ $? -ne 0 ]; then
        error "Failed to format root partition." "fatal"
    fi
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