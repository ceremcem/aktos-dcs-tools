echo_green "Formatting for Orange Pi"
# ------------------------------------------------
# See http://www.orangepi.org/Docs/Settingup.html
# ------------------------------------------------

ROOT_PART="${device}${FIRST_PARTITION}"

umount_if_mounted3 $ROOT_PART

# mountpoints
ROOT_MNT="$(mktemp -d --suffix=-root)"
echo "Using mount points: "
echo "...Root MNT: $ROOT_MNT"

if [ ! $skip_format ]; then
    echo "Creating partition table on ${device}..."
    # to create the partitions programatically (rather than manually)
    # we're going to simulate the manual input to fdisk
    # The sed script strips off all the comments so that we can
    # document what we're doing in-line with the actual commands
    # Note that a blank line (commented as "default" will send a empty
    # line terminated with a newline to take the fdisk default.
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${device}
      o # clear the in memory partition table
      n # new partition
      p # primary partition
      1 # partition number 1
      8192 # start definitely from this sector
        # default, extend partition to end of disk
      p # print the in-memory partition table
      w # write the partition table
      q # and we're done
EOF

    fstype="ext4"
    echo_green "...creating $fstype for ROOT_PART ($ROOT_PART)"
    mkfs.$fstype ${ROOT_PART}

    # Bootloader workaround
    echo_yellow "WORKAROUND: Setting the UUID of root partition to old UUID"
    old_uuid=$(cat $backup/boot/armbianEnv.txt | grep rootdev | sed "s/rootdev=UUID=//")
    echo "...changing UUID to $old_uuid"
    yes | tune2fs $ROOT_PART -U $old_uuid
fi

require_device $ROOT_PART

echo_green "Restoring files from backup to device..."
echo "...mounting partitions"
mount ${ROOT_PART} ${ROOT_MNT}

echo "...rsync from .${backup#$PWD} to ${ROOT_PART} (this may take a while...)"
rsync  -aHAXh "${backup}/" ${ROOT_MNT}

echo "...setting /etc/resolv.conf attributes to make it immutable"
chattr +i $ROOT_MNT/etc/resolv.conf

echo "...syncing"
sync

echo "...unmounting devices"
umount ${ROOT_PART}

echo "...removing mountpoints"
rmdir ${ROOT_MNT}

echo_yellow "Do not forget to check the following files on target: "
echo_yellow " * /etc/fstab"
echo_yellow " * /etc/network/interfaces"
