#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="otbr"
var_tags="iot;smarthome;thread"
var_cpu="2"
var_ram="4096"
var_disk="8"
var_os="debian"
var_version="12"
var_unprivileged="0"
HN="otbr"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /opt/otbr/update.sh ]]; then
    msg_error "Keine OTBR Installation gefunden!"
    exit
  fi
  msg_info "Update OTBR"
  pct exec "$CTID" -- bash /opt/otbr/update.sh
  msg_ok "OTBR aktualisiert"
  exit
}

MODE=""
RADIO_HOST=""
RADIO_PORT=""
USB_PATH="/dev/ttyACM0"

CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "OTBR Setup" --menu "Thread Radio Verbindung:" 12 60 2 \
  "1" "Netzwerk (TCP, z.B. SLZB-06 / SLZB-MR*)" \
  "2" "USB (z.B. SkyConnect / Sonoff)" 3>&1 1>&2 2>&3)

if [[ "$CHOICE" == "1" ]]; then
  MODE="network"
  NETWORK_ENDPOINT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "OTBR Netzwerk-Radio" --inputbox "IP:PORT" 10 50 "192.168.111.4:6638" 3>&1 1>&2 2>&3)
  RADIO_HOST="${NETWORK_ENDPOINT%%:*}"
  RADIO_PORT="${NETWORK_ENDPOINT##*:}"
else
  MODE="usb"
  USB_PATH=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "OTBR USB-Radio" --inputbox "USB Pfad" 10 50 "/dev/ttyACM0" 3>&1 1>&2 2>&3)
fi

start
build_container
description

msg_info "Konfiguration übertragen"
cat >/tmp/otbr.env <<EOF
MODE=${MODE}
RADIO_HOST=${RADIO_HOST}
RADIO_PORT=${RADIO_PORT}
USB_PATH=${USB_PATH}
EOF
pct push "$CTID" /tmp/otbr.env /tmp/otbr.env
rm -f /tmp/otbr.env
msg_ok "Konfiguration übertragen"

msg_info "Install-Skript holen"
TMP_INSTALL=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/hiSweid/otbr-proxmox-scripts/main/install/otbr-install.sh -o "$TMP_INSTALL"
pct push "$CTID" "$TMP_INSTALL" /root/otbr-install.sh
rm -f "$TMP_INSTALL"
pct exec "$CTID" -- chmod +x /root/otbr-install.sh
msg_ok "Install-Skript übertragen"

msg_info "Installiere OTBR im Container"
pct exec "$CTID" -- bash /root/otbr-install.sh
msg_ok "OTBR installiert"

IP=$(pct exec "$CTID" -- bash -lc "hostname -I | awk '{print \$1}'")

msg_ok "Installation erfolgreich"
echo -e "${INFO}${YW} OTBR Hostname:${CL} ${BGN}otbr${CL}"
echo -e "${INFO}${YW} OTBR Web:${CL} ${BGN}http://${IP}${CL}"

if [[ "$MODE" == "usb" ]]; then
  echo -e "${INFO}${YW} USB passthrough:${CL}"
  echo -e "${TAB}${BGN}lxc.mount.entry: ${USB_PATH} dev/ttyACM0 none bind,optional,create=file${CL}"
fi
