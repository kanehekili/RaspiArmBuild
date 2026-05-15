#!/bin/bash
#setup systemd-networkd with wpa_supplicant. Not working with kernel 6.18 (32 bit!)
if ((${EUID:-0} || "$(id -u)")); then
  echo "You are not root"
  exit
fi

if ! mountpoint -q root; then
  echo "mount /dev/sdx2 root is missing"
  exit
fi

# Load credentials if not already sourced
if [ -z "$WIFI_SSID" ]; then
  if [ ! -f credentials.conf ]; then
    echo "Error: credentials.conf not found and WIFI_SSID not set"
    exit 1
  fi
  source ./credentials.conf
fi

mkdir -p root/etc/wpa_supplicant
cat > root/etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<EOF
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=wheel
update_config=1
country=$WIFI_COUNTRY
p2p_disabled=1
network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PSK"
    key_mgmt=WPA-PSK SAE
    ieee80211w=1
}
EOF

# Enable wpa_supplicant for wlan0 at boot
ln -sf /usr/lib/systemd/system/wpa_supplicant@.service root/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service

cat > root/etc/conf.d/wireless-regdom <<EOF
WIRELESS_REGDOM="$WIFI_COUNTRY"
EOF

mkdir -p root/etc/systemd/network

cat > root/etc/systemd/network/wlan0.network <<EOF
[Match]
Name=wlan0

[Network]
DHCP=yes
ConfigureWithoutCarrier=yes

[Link]
RequiredForOnline=no
EOF

cat > root/etc/systemd/network/eth0.network <<EOF
[Match]
Name=eth0

[Network]
DHCP=yes
EOF

cat > root/etc/modprobe.d/brcmfmac.conf <<EOF
options brcmfmac feature_disable=0x82000
EOF
