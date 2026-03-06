#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: hiSweid
# License: MIT
# Source: https://openthread.io/

# APP Info
APP="otbr"
var_tags="iot;smarthome;thread"
var_hostname="otbr"
var_cpu="2"
var_ram="1024"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="0"

# GITHUB INFO
GITHUB_USER="hiSweid"
GITHUB_REPO="otbr-proxmox-scripts"
GITHUB_BRANCH="main"

header_info "$APP"

# --- EIGENES MENÜ FÜR DEN FUNK-STICK ---
RADIO_URL=""
CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Thread Radio Verbindung" --menu "Wie ist dein Thread-Stick verbunden?" 12 68 2 \
  "1" "Netzwerk Stick (TCP Socket, z.B. SLZB-06)" \
  "2" "Lokaler USB-Stick (z.B. SkyConnect / Sonoff)" 3>&1 1>&2 2>&3)

if [ "$CHOICE" == "1" ]; then
  NETWORK_IP=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Netzwerk Stick IP" --inputbox "Gib die IP und den Port deines Sticks ein (Format: IP:PORT):" 10 58 "192.168.111.4:6638" 3>&1 1>&2 2>&3)
  RADIO_URL="spinel+hdlc+socket://${NETWORK_IP}"
else
  USB_PATH=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "USB Pfad" --inputbox "Gib den Pfad zu deinem USB-Stick an:" 10 58 "/dev/ttyACM0" 3>&1 1>&2 2>&3)
  RADIO_URL="spinel+hdlc+uart://${USB_PATH}?baudrate=460800"
fi
# ---------------------------------------------

variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -f /opt/otbr/update.sh ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
    msg_info "Updating $APP"
    pct exec "$CTID" -- bash -c "/opt/otbr/update.sh"
    msg_ok "Updated $APP"
    exit
}

start
build_container

# Übergebe die Benutzereingabe an den Container
echo "$RADIO_URL" > /etc/pve/lxc/${CTID}-radio.tmp
pct push $CTID /etc/pve/lxc/${CTID}-radio.tmp /tmp/radio_url.txt
rm /etc/pve/lxc/${CTID}-radio.tmp

description

msg_ok "Completed Successfully\n"
if [ "$CHOICE" == "2" ]; then
  echo -e "${INFO}${BGN}  WICHTIG für USB-Nutzer: Vergiss nicht, den Stick durchzureichen! ${CL}"
  echo -e "${INFO}${BGN}  Füge lxc.mount.entry: ${USB_PATH} dev/ttyACM0 none bind,optional,create=file in die Config ein. ${CL}"
fi
