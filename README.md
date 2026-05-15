# Arch Linux ARM SD Card Builder

Automated SD card builder for Raspberry Pi using Arch Linux ARM tarballs.

**Supports:**
- `armv7h` (32-bit) — Pi2, Pi3, Pi4, Zero 2W
- `aarch64` (64-bit) — Pi3, Pi4, Pi5, Zero 2W

---

## Host Prerequisites

```
sudo pacman -S qemu-user-static qemu-user-static-binfmt arch-install-scripts
```

## Download Tarballs

```bash
# 32-bit
wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-armv7-latest.tar.gz

# 64-bit
wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
```

---

## Workflow

1. Copy the template and fill in your values:
   ```
   cp credentials.conf.template credentials.conf
   ```
2. Ensure `boot/` and `root/` directories exist in the working directory (used as mountpoints)
3. Run the builder:
   ```
   sudo ./makeIso.sh <tarball> /dev/sdX
   ```
4. When done:
   ```
   sudo umount root boot
   ```

---

## What makeIso Does Automatically

- Partitions and formats the SD card (400 MB FAT boot + ext4 root)
- Unpacks the tarball
- Calls `populate.sh` (arch-aware chroot setup)
- Calls `configWlan.sh` if `WIFI_SSID` is set in `credentials.conf`
- For aarch64: calls `tweakAarch64.sh` (writes `config.txt`, `cmdline.txt`, updates fstab via PARTUUID)

---

## Scripts

| Script | Description |
|---|---|
| `makeIso.sh` | Main script. Reads `credentials.conf` for all settings. |
| `populate.sh` | Chroot setup: auto-detects arch, installs linux-rpi (aarch64), removes linux-firmware bloat, installs rng-tools/wpa_supplicant/sudo, sets up pacman-init.service. |
| `tweakAarch64.sh` | Writes `config.txt` + `cmdline.txt` to boot/, updates fstab with PARTUUIDs. Called automatically for aarch64. Can also be run standalone on a mounted SD card. |
| `configWlan.sh` | Sets up wpa_supplicant + systemd-networkd for wlan0/eth0. Called automatically if WIFI_SSID is set. Can also be run standalone on a mounted root/. |
| `copyKernel.sh` | Manual kernel downgrade for armv7 if needed. |
| `watchSync.sh` | Monitor sync progress while waiting for bsdtar to finish. |

---

## First Boot

- `pacman-init.service` runs once: initializes the pacman keyring via rngd entropy, then restores `SigLevel = Required DatabaseOptional`
- `machine-id` is generated uniquely per device on first boot
- After first boot, `pacman -Syu` works normally

---

## Architecture Notes

### armv7h (32-bit) — Pi2, Pi3, Pi4

- SD card appears as `mmcblk0`, fstab correct out of the box
- wpa_supplicant included in the tarball by default

### aarch64 (64-bit) — Pi3, Pi4, Pi5, Zero 2W

- `linux-aarch64` + `uboot-raspberrypi` replaced by `linux-rpi` (direct boot, no U-Boot)
- `tweakAarch64.sh` writes `config.txt`/`cmdline.txt` (missing from the aarch64 tarball)
- fstab and `cmdline.txt` use PARTUUID (works across all Pi models)
- `net.ifnames=0` ensures `eth0`/`wlan0` naming (Pi5 has PCIe ethernet)
- `tweakPi4.sh` is obsolete — `tweakAarch64.sh` handles everything

---

## Known Issues

### U-Boot (aarch64)

The original `linux-aarch64` + `uboot-raspberrypi` boot path does **not** work:

- **Zero 2W:** rainbow screen, ARM never starts
- **Pi5:** no boot

Root cause unknown. `linux-rpi` (direct boot, no U-Boot) is used for all boards as a result.
The U-Boot code path is preserved in `populate.sh` and `tweakAarch64.sh` but disabled.

### WiFi (brcmfmac — all Pi models)

`configWlan.sh` writes `/etc/modprobe.d/brcmfmac.conf`:

```
options brcmfmac feature_disable=0x82000
```
