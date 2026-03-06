#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: hiSweid
# License: MIT
# Source: https://openthread.io/ | Github: https://github.com/openthread/otbr

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installiere Abhängigkeiten"
$STD apt-get install -y sudo git curl wget build-essential pkg-config avahi-daemon dbus iproute2 python3 python3-pip python3-venv
msg_ok "Abhängigkeiten installiert"

msg_info "Klone OTBR Repository"
$STD git clone --depth 1 https://github.com/openthread/otbr.git /opt/otbr
msg_ok "OTBR Repository geklont"

msg_info "Kompiliere OTBR Core (Das dauert kurz)"
cd /opt/otbr
export INFRA_IF_NAME=eth0
export WEB_GUI=1
export NAT64=1
export DNS64=1
export PIP_BREAK_SYSTEM_PACKAGES=1
$STD ./script/bootstrap
msg_ok "OTBR Core kompiliert"

msg_info "Richte OTBR ein"
$STD ./script/setup
msg_ok "OTBR eingerichtet"

msg_info "Konfiguriere OTBR Agent"
USER_RADIO_URL=$(cat /tmp/radio_url.txt)
cat <<EOF >/etc/default/otbr-agent
OTBR_AGENT_OPTS="-I wpan0 -B eth0 ${USER_RADIO_URL}"
EOF
rm -f /tmp/radio_url.txt
msg_ok "Agent konfiguriert: $USER_RADIO_URL"

msg_info "Aktiviere Dienste"
systemctl enable -q --now dbus avahi-daemon
systemctl enable -q --now otbr-agent
systemctl enable -q --now otbr-web
msg_ok "Dienste aktiviert"

msg_info "Erstelle Update Skript"
cat <<'EOF' >/opt/otbr/update.sh
#!/usr/bin/env bash
echo "Stoppe OTBR..."
systemctl stop otbr-agent otbr-web

echo "Lade Updates..."
cd /opt/otbr
git pull

echo "Kompiliere neu..."
export INFRA_IF_NAME=eth0 WEB_GUI=1 NAT64=1 DNS64=1 PIP_BREAK_SYSTEM_PACKAGES=1
./script/bootstrap >/dev/null 2>&1
./script/setup >/dev/null 2>&1

echo "Starte OTBR..."
systemctl start otbr-agent otbr-web
echo "Update fertig!"
EOF
chmod +x /opt/otbr/update.sh
msg_ok "Update Skript erstellt"

msg_info "Räume System auf"
$STD apt-get autoremove -y
$STD apt-get clean
msg_ok "System bereinigt"

motd_ssh
customize
cleanup_lxc
