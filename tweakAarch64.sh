#!/bin/bash

if ((${EUID:-0} || "$(id -u)")); then
  echo "You are not root"
  exit
fi

if ! mountpoint -q boot; then
  echo "mount /dev/sdx1 boot is missing"
  exit
fi

if ! mountpoint -q root; then
  echo "mount /dev/sdx2 root is missing"
  exit
fi

BOOT_DEV=$(findmnt -n -o SOURCE boot)
ROOT_DEV=$(findmnt -n -o SOURCE root)
BOOT_PARTUUID=$(blkid -s PARTUUID -o value $BOOT_DEV)
ROOT_PARTUUID=$(blkid -s PARTUUID -o value $ROOT_DEV)

if [ "${KERNEL_MODE:-rpi}" = uboot ]; then
    cat > boot/config.txt << 'EOF'
# http://rptl.io/configtxt
kernel=u-boot.bin
arm_64bit=1

dtparam=audio=on
camera_auto_detect=1
display_auto_detect=1
hdmi_force_hotplug=1

dtoverlay=vc4-kms-v3d
max_framebuffers=2
disable_fw_kms_setup=1
disable_overscan=1
arm_boost=1

[cm4]
otg_mode=1

[all]
EOF
    echo "config.txt written (U-Boot mode), fstab updated with PARTUUIDs"
else
    cat > boot/config.txt << 'EOF'
# http://rptl.io/configtxt

#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

dtparam=audio=on
camera_auto_detect=1
display_auto_detect=1
hdmi_force_hotplug=1
initramfs initramfs-linux.img followkernel

dtoverlay=vc4-kms-v3d
max_framebuffers=2
disable_fw_kms_setup=1
arm_64bit=1
disable_overscan=1
arm_boost=1

[cm4]
otg_mode=1

[cm5]
dtoverlay=dwc2,dr_mode=host

[all]
EOF
    echo "console=serial0,115200 console=tty1 root=PARTUUID=$ROOT_PARTUUID rw rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=DE net.ifnames=0" > boot/cmdline.txt
    echo "config.txt and cmdline.txt written (linux-rpi mode), fstab updated with PARTUUIDs"
fi

sed -i "s|^/dev/mmcblk[0-9]p1|PARTUUID=$BOOT_PARTUUID|" root/etc/fstab
