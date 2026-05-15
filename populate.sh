#!/bin/bash
echo "### Entering the populate script now###"
if file root/usr/bin/bash | grep -q 'aarch64'; then
    QEMU_BIN="qemu-aarch64-static"
    ARCH="aarch64"
else
    QEMU_BIN="qemu-arm-static"
    ARCH="armv7h"
fi
cp /usr/bin/$QEMU_BIN root/usr/bin/
mount --bind boot root/boot
arch-chroot root /bin/bash -c "
  sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf
  sed -i 's/^SigLevel.*/SigLevel = Never/' /etc/pacman.conf
  pacman -Sy
  if [ $ARCH = aarch64 ] && [ "${KERNEL_MODE:-rpi}" = rpi ]; then
    pacman -Rdd --noconfirm linux-aarch64 uboot-raspberrypi
    pacman -S --noconfirm linux-rpi
  fi
  pacman -Rdd --noconfirm linux-firmware
  pacman -Rns --noconfirm linux-firmware-{amdgpu,atheros,cirrus,intel,mediatek,nvidia,radeon,other,realtek}
  pacman -Syu --noconfirm --needed rng-tools bash-completion sudo wpa_supplicant less htop python
  #pacman -S --noconfirm bash-completion sudo
  systemctl enable rngd.service
  cat > /etc/systemd/system/pacman-init.service << 'EOF'
[Unit]
Description=Initialize pacman keyring
ConditionFirstBoot=yes
After=rngd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/pacman-key --init
ExecStart=/usr/bin/pacman-key --populate archlinuxarm
ExecStart=/usr/bin/sed -i 's/^SigLevel.*/SigLevel = Required DatabaseOptional/' /etc/pacman.conf

[Install]
WantedBy=first-boot-complete.target
EOF
  systemctl enable pacman-init.service
  sed -i 's/^DisableSandbox/#DisableSandbox/' /etc/pacman.conf
  truncate -s 0 /etc/machine-id
  locale-gen
  usermod -aG wheel alarm
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
"
umount root/boot
rm root/usr/bin/$QEMU_BIN
if [ $ARCH = aarch64 ]; then
    bash ./tweakAarch64.sh
fi
echo "cleaned up firmware & installed rng-tools"
