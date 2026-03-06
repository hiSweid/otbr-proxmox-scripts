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

msg_info "Installing Dependencies"
$STD apt-get install -y sudo git curl wget build-essential pkg-config avahi-daemon dbus iproute2 python3 python3-pip python3-venv
msg_ok "Installed Dependencies"

msg_info "Cloning OTBR Repository"
# Optimierung: --depth 1 lädt nur die neueste Version, das spart Zeit und Speicher
$STD git clone --depth 1 https://github.com/openthread/otbr.git /opt/otbr
msg_ok "Cloned OTBR Repository"

msg_info "Bootstrapping OTBR (Patience)"
cd /opt/otbr
export INFRA_IF_NAME=eth0
export WEB_GUI=1
export NAT64=1
export DNS64=1
export PIP_BREAK_SYSTEM_PACKAGES=1
$STD ./script/bootstrap
msg_ok "Bootstrapped OTBR"

msg_info "Setting up OTBR (Patience)"
$STD ./script/setup
msg_ok "Set up OTBR"

msg_info "Configuring OTBR Agent"
# Lese die vom Frontend übergebene URL aus
USER_RADIO_URL=$(cat /tmp/radio_url.txt)

cat <<EOF >/etc/default/otbr-agent
# Default settings for otbr-agent
OTBR_AGENT_OPTS="-I wpan0 -B eth0 ${USER_RADIO_URL}"
EOF
rm -f /tmp/radio_url.txt
msg_ok "Configured OTBR Agent with: $USER_RADIO_URL"

msg_info "Enabling Services"
systemctl enable -q --now dbus avahi-daemon
systemctl enable -q --now otbr-agent
systemctl enable -q --now otbr-web
msg_ok "Enabled Services"

msg_info "Creating Update Script"
cat <<'EOF' >/opt/otbr/update.sh
#!/usr/bin/env bash
echo "Stoppe OTBR Services..."
systemctl stop otbr-agent otbr-web

echo "Lade Updates herunter..."
cd /opt/otbr
git pull

echo "Kompiliere OTBR neu (Das kann dauern)..."
export INFRA_IF_NAME=eth0 WEB_GUI=1 NAT64=1 DNS64=1 PIP_BREAK_SYSTEM_PACKAGES=1
./script/bootstrap >/dev/null 2>&1
./script/setup >/dev/null 2>&1

echo "Starte Services..."
systemctl start otbr-agent otbr-web
echo "Update abgeschlossen!"
EOF
chmod +x /opt/otbr/update.sh
msg_ok "Created Update Script"

msg_info "Cleaning up"
$STD apt-get autoremove -y
$STD apt-get clean
msg_ok "Cleaned up"

motd_ssh
customize
cleanup_lxc
