#!/bin/bash

# Source configuration file
. ./install.conf

# """
# Confused between Snapper and Timeshift,
# So, can't choose BTRFS layout and the
# function disk_setup is incomplete.
# """

# create_partition() {
#     local SIZE=$1
#     local CONFIRM_WRITE=$2

#     FDISK_OUTPUT=$(( 
#     echo n    # Add a new partition
#     echo p    # Primary partition
#     echo      # Default partition number
#     echo      # Default first sector
#     if [ -z "$SIZE" ]; then
#         echo      # Use remaining space if no size is provided
#     else
#         echo +$SIZE  # Set partition size if provided
#     fi
#     if [ "$CONFIRM_WRITE" == "y" ]; then
#         echo w    # Write the changes only if confirmation is provided
#     else
#         echo p    # Prints modifid table
#         echo q    # Quit without saving changes
#     fi
#     ) | fdisk $DISK 2>&1)

#     # Step 2: Extract the partition number from the fdisk output (only if written)
#     if [ "$CONFIRM_WRITE" == "y" ]; then
#         PARTITION_NUMBER=$(echo "$FDISK_OUTPUT" | grep -oP '(?<=Created a new partition )[0-9]+')

#         # Check if a partition number was found
#         if [ -z "$PARTITION_NUMBER" ]; then
#             echo "Failed to create partition."
#             exit 1
#         fi

#         # Full partition path (e.g., /dev/sda1)
#         PARTITION=${DISK}${PARTITION_NUMBER}

#         partprobe $DISK
#         echo $PARTITION
#     else
#         # Just show the fdisk output without writing changes
#         echo "$FDISK_OUTPUT"
#     fi
# }

# mount_disk() {
#     mount "$ROOT_PARTITION" /mnt

#     btrfs subvolume create /mnt/@
#     btrfs subvolume create /mnt/@home
#     btrfs subvolume create /mnt/@log
#     btrfs subvolume create /mnt/@pkg

#     umount /mnt

#     mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@ "$ROOT_PARTITION" /mnt

#     mkdir -p /boot/efi
#     mount --mkdir "$BOOT_PARTITION" /mnt/boot/efi

#     mkdir -p /mnt/home
#     mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@home "$ROOT_PARTITION" /mnt/home

#     mkdir -p /mnt/var/log
#     mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@log "$ROOT_PARTITION" /mnt/var/log

#     mkdir -p /mnt/var/cache/pacman/pkg
#     mount -o noatime,ssd,discard=async,compress=zstd:3,space_cache=v2,subvol=@pkg "$ROOT_PARTITION" /mnt/var/cache/pacman/pkg
# }

# # Setup Disk
# disk_setup() {
    
#     # Boot Partition
#     # Dry Run
#     create_partition "512M" "n"

#     read -p "Do you want to write the changes? (y/n): " CONFIRM_WRITE
#     if [ $CONFIRM_WRITE == "n" ]
#     then
#         exit 1
#     fi

#     BOOT_PARTITION=$(create_partition "512M" "y")
#     # Format Boot Partition
#     mkfs.fat -F 32 "$BOOT_PARTITION"

#     # root
#     # Dry Run
#     create_partition "" "n"

#     read -p "Do you want to write the changes? (y/n): " CONFIRM_WRITE
#     if [ $CONFIRM_WRITE == "n" ]
#     then
#         exit 1
#     fi

#     ROOT_PARTITION=$(create_partition "" "y")
#     mkfs.btrfs "$ROOT_PARTITION"

#     mount_disk
# }

# chroot_setup() {
# arch-chroot /mnt /bin/bash <<EOF

# # Set timezone
# echo "Setting timezone..."

# ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
# hwclock --systohc

# # Localization
# echo "Setting locale..."

# echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
# locale-gen
# echo "LANG=en_US.UTF-8" > /etc/locale.conf

# # Set hostname
# echo "Setting hostname..."

# echo "$HOST_NAME" > /etc/hostname

# # Set hosts file
# echo "Configuring hosts file..."

# cat <<EOL > /etc/hosts
# 127.0.0.1   localhost
# ::1         localhost
# 127.0.1.1   $HOST_NAME.localdomain    $HOST_NAME
# EOL

# # Set root password
# echo "Setting root password..."

# echo root:$ROOT_PASS | chpasswd

# useradd -m -G wheel $USER_NAME
# echo $USER_NAME:$USER_PASS | chpasswd

# echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers.d/$USER_NAME

# # Install bootloader
# echo "Installing bootloader..."
# grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
# grub-mkconfig -o /boot/grub/grub.cfg

# systemctl enable NetworkManager
# EOF
# }

# main() {
#     # Ceacking Boot Mode
#     cat /sys/firmware/efi/fw_platform_size

#     # Time Setup
#     timedatectl set-ntp true

#     # Disk Setup
#     disk_setup

#     pacstrap /mnt base base-devel linux linux-firmware btrfs-progs grub efibootmgr vim networkmanager git
#     genfstab -U /mnt >> /mnt/etc/fstab

#     chroot_setup

#     echo "Unmounting partitions..."
#     umount -R /mnt
# }

# # Execute the script
# main "$@"
