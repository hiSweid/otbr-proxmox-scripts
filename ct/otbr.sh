#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: hiSweid
# License: MIT
# Source: https://openthread.io/

# APP Info
APP="otbr"
var_tags="iot;smarthome;thread"
var_cpu="2"
var_ram="1024"
var_disk="4"
var_os="debian"
var_version="13"
var_unprivileged="0"

# ERZWINGE CONTAINERNAMEN (HOSTNAME)
HN="otbr"

# ERZWINGE PFADE
GITHUB_USER="hiSweid"
GITHUB_REPO="otbr-proxmox-scripts"
GITHUB_BRANCH="main"
export FUNCTIONS_FILE_PATH="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func"
export INSTALL_SCRIPT="https://raw.githubusercontent.com/hiSweid/otbr-proxmox-scripts/main/install/otbr-install.sh"

header_info "$APP"

# --- OTBR STICK MENÜ ---
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
# ------------------------

variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -f /opt/otbr/update.sh ]]; then msg_error "Keine OTBR Installation gefunden!"; exit; fi
    msg_info "Update OTBR"
    pct exec "$CTID" -- bash -c "/opt/otbr/update.sh"
    msg_ok "OTBR aktualisiert"
    exit
}

start
build_container

# Radio URL an den LXC übergeben
echo "$RADIO_URL" > /etc/pve/lxc/${CTID}-radio.tmp
pct push $CTID /etc/pve/lxc/${CTID}-radio.tmp /tmp/radio_url.txt
rm -f /etc/pve/lxc/${CTID}-radio.tmp

description

msg_ok "Installation erfolgreich\n"
if [ "$CHOICE" == "2" ]; then
  echo -e "${INFO}${BGN}  USB-Nutzer: Bitte lxc.mount.entry in die Config eintragen! ${CL}"
fi
