#!/usr/bin/env bash

set -e

apt-get update
apt-get install -y \
  sudo \
  git \
  curl \
  wget \
  build-essential \
  pkg-config \
  avahi-daemon \
  dbus \
  iproute2 \
  python3 \
  python3-pip \
  python3-venv

git clone --depth 1 https://github.com/openthread/otbr.git /opt/otbr
cd /opt/otbr

export INFRA_IF_NAME=eth0
export WEB_GUI=1
export NAT64=1
export DNS64=1
export PIP_BREAK_SYSTEM_PACKAGES=1

./script/bootstrap
./script/setup

USER_RADIO_URL=$(cat /tmp/radio_url.txt)

cat <<EOF >/etc/default/otbr-agent
OTBR_AGENT_OPTS="-I wpan0 -B eth0 ${USER_RADIO_URL}"
EOF
rm -f /tmp/radio_url.txt

systemctl daemon-reload
systemctl enable --now dbus
systemctl enable --now avahi-daemon
systemctl enable --now otbr-agent
systemctl enable --now otbr-web

cat <<'EOF' >/opt/otbr/update.sh
#!/usr/bin/env bash
set -e
systemctl stop otbr-agent otbr-web || true
cd /opt/otbr
git pull
export INFRA_IF_NAME=eth0
export WEB_GUI=1
export NAT64=1
export DNS64=1
export PIP_BREAK_SYSTEM_PACKAGES=1
./script/bootstrap
./script/setup
systemctl start otbr-agent otbr-web
EOF
chmod +x /opt/otbr/update.sh

apt-get autoremove -y
apt-get clean
