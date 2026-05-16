#!/bin/bash

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 <source_image> <target_device>

Arguments:
    source_image    Path to Arch ARM tarball (e.g., ArchLinuxARM-rpi-aarch64-latest.tar.gz)
    target_device   Target SD card device (e.g., /dev/sdb)

Example:
    $0 ArchLinuxARM-rpi-aarch64-latest.tar.gz /dev/sdb

Options:
    --help, -h      Show this help message
EOF
    exit 1
}

# Check for help flag
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_usage
fi

# Check if both parameters are provided
if [ $# -ne 2 ]; then
    echo "Error: Expected 2 parameters, got $#"
    echo ""
    show_usage
fi


SRC=$1
DEVICE=$2

# NOTE: U-Boot (linux-aarch64 + uboot-raspberrypi) tested on Zero 2W (rainbow screen)
# and Pi5 (no boot). Root cause unknown. Using linux-rpi for all boards until resolved.
# The uboot path is preserved in populate.sh/tweakAarch64.sh for future reference.
#if [[ "$SRC" == *aarch64* ]]; then
#    echo ""
#    echo "aarch64 image detected. Keep original kernel?:"
#    echo "  1) U-Boot + linux-aarch64 (standard Arch ARM) (Pi2/Pi3/Pi4/Zero 2W)"
#    echo "  2) linux-rpi kernel, no U-Boot                (Pi2/Pi3/Pi4/Zero 2W/Pi5)"
#    read -rp "Choice [1/2, default 2]: " _choice
#    case "$_choice" in
#        1) export KERNEL_MODE=uboot ;;
#        *) export KERNEL_MODE=rpi ;;
#    esac
#    echo "Using KERNEL_MODE=$KERNEL_MODE"
#    echo ""
#fi
export KERNEL_MODE=rpi

if ((${EUID:-0} || "$(id -u)")); then
  echo "You are not root"
  exit
fi

if [ ! -f credentials.conf ]; then
  echo "Error: credentials.conf not found. Fill in your values first."
  exit 1
fi
source ./credentials.conf

echo "umount ${DEVICE}"
umount $DEVICE*
#builds 400 Mib fat:
#Sector size = 512 bytes
#400 MiB = 400 × 1024 × 1024 = 419 430 400 bytes
#419 430 400 / 512 = 819 200 sectors

sfdisk "$DEVICE" <<EOF
label: dos
unit: sectors
${DEVICE}1 : start=2048, size=819200, type=c, bootable
${DEVICE}2 : start=821248, type=83
EOF

echo "Format and mount"
mkfs.vfat -F32 -n ${PREFIX}boot ${DEVICE}1
mount ${DEVICE}1 boot

mkfs.ext4 -F -L ${PREFIX}root ${DEVICE}2
mount ${DEVICE}2 root
echo "Unpack ${SRC}"
bsdtar -xpf $SRC -C root
echo "Wait for sync - Takes minutes. Check with watchSync.sh"
sync

echo "Moving boot to root"
mv root/boot/* boot
#sed -i 's/mmcblk0/mmcblk1/g' root/etc/fstab only pi 4 aarch64
cat << EOF >> root/boot/config.txt
dtoverlay=vc4-kms-v3d
initramfs initramfs-linux.img followkernel
display_auto_detect=1
dtparam=spi=on
dtoverlay=spi0-1cs
dtoverlay=disable-bt
camera_auto_detect=1
[cm4]
otg_mode=1
[pi4]
arm_boost=1
EOF

echo "Credentials and region"
# 2. Generate SHA-512 password hashes
ROOT_HASH=$(openssl passwd -6 "$ROOT_PWD")
ALARM_HASH=$(openssl passwd -6 "$ALARM_PWD")
SHADOW_FILE="root/etc/shadow"
echo "en_DK.UTF-8 UTF-8" >> root/etc/locale.gen 2>/dev/null
echo "KEYMAP=de-latin1" > root/etc/vconsole.conf 2>/dev/null
echo "LANG=en_DK.UTF-8" > root/etc/locale.conf 2>/dev/null
rm -f root/etc/localtime
ln -s /usr/share/zoneinfo/Europe/Berlin root/etc/localtime
echo "Europe/Berlin" > root/etc/timezone

# Root password
sed -i "s|^root:[^:]*:|root:$ROOT_HASH:|" "$SHADOW_FILE"
# Alarm user password
sed -i "s|^alarm:[^:]*:|alarm:$ALARM_HASH:|" "$SHADOW_FILE"
echo $HOSTNAME > root/etc/hostname
#create bash 
rm root/home/alarm/.bashrc
cat bash-template.txt >> root/etc/bash.bashrc
#populate and install rng-tools (faster ssh)
source ./populate.sh
source ./configWlan.sh
echo "Done. Host is $HOSTNAME User pwd is $ALARM_PWD, root pwd is $ROOT_PWD"
