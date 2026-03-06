#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# Copyright (c) 2021-2026 community-scripts ORG
# Author: hiSweid
# License: MIT
# Source: https://openthread.io/

APP="otbr"
var_tags="iot;smarthome;thread"
var_cpu="2"
var_ram="1024"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="0"
HN="otbr"

header_info "$APP"

RADIO_URL=""
CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "OTBR Setup" --menu "Verbindungsart für den Thread-Stick:" 12 58 2 \
  "1" "Netzwerk (TCP, z.B. SLZB-06)" \
  "2" "USB (z.B. SkyConnect)" 3>&1 1>&2 2>&3)

if [ "$CHOICE" == "1" ]; then
  NETWORK_IP=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Netzwerk Stick" --inputbox "IP & Port (Format IP:PORT):" 10 50 "192.168.111.4:6638" 3>&1 1>&2 2>&3)
  RADIO_URL="spinel+hdlc+socket://${NETWORK_IP}"
else
  USB_PATH=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "USB Stick" --inputbox "Pfad zum USB-Gerät:" 10 50 "/dev/ttyACM0" 3>&1 1>&2 2>&3)
  RADIO_URL="spinel+hdlc+uart://${USB_PATH}?baudrate=460800"
fi

variables
color
catch_errors

function update_script() {
  header_info
  if [[ ! -f /opt/otbr/update.sh ]]; then
    msg_error "Keine OTBR Installation gefunden!"
    exit
  fi
  msg_info "Update OTBR"
  pct exec "$CTID" -- bash -c "/opt/otbr/update.sh"
  msg_ok "OTBR aktualisiert"
  exit
}

start
build_container
description

msg_info "Übertrage OTBR Konfiguration"
echo "$RADIO_URL" >/tmp/radio_url.txt
pct push "$CTID" /tmp/radio_url.txt /tmp/radio_url.txt
rm -f /tmp/radio_url.txt
msg_ok "Konfiguration übertragen"

msg_info "Installiere OTBR im Container"
pct exec "$CTID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/hiSweid/otbr-proxmox-scripts/main/install/otbr-install.sh)"
msg_ok "OTBR installiert"

IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')
msg_ok "Installation erfolgreich"
echo -e "${INFO}${BGN}  OTBR Web-UI: http://${IP} ${CL}"

if [ "$CHOICE" == "2" ]; then
  echo -e "${INFO}${BGN}  USB-Nutzer: Bitte USB-Gerät zusätzlich per LXC mounten. ${CL}"
fi
