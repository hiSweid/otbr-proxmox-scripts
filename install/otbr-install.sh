#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  git \
  sudo \
  nano \
  wget \
  dbus \
  avahi-daemon \
  lsb-release

rm -rf /opt/otbr
git clone --depth=1 https://github.com/openthread/ot-br-posix /opt/otbr

cd /opt/otbr
./script/bootstrap
INFRA_IF_NAME=eth0 WEB_GUI=1 NAT64=1 DNS64=1 ./script/setup

RADIO_URL="spinel+hdlc+uart:///dev/ttyACM0?baudrate=460800"
if [[ -s /tmp/radio_url.txt ]]; then
  RADIO_URL="$(cat /tmp/radio_url.txt)"
fi

if [[ -f /etc/default/otbr-agent ]]; then
  cat >/etc/default/otbr-agent <<EOF
OTBR_AGENT_OPTS="-I wpan0 -B eth0 ${RADIO_URL}"
EOF
else
  OTBR_AGENT_BIN="$(command -v otbr-agent || echo /usr/sbin/otbr-agent)"
  mkdir -p /etc/systemd/system/otbr-agent.service.d
  cat >/etc/systemd/system/otbr-agent.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=${OTBR_AGENT_BIN} -I wpan0 -B eth0 ${RADIO_URL}
EOF
fi

systemctl daemon-reload
systemctl enable --now dbus
systemctl enable --now avahi-daemon
systemctl restart otbr-agent || systemctl start otbr-agent

if systemctl list-unit-files | grep -q '^otbr-web.service'; then
  systemctl enable --now otbr-web
fi

cat >/opt/otbr/update.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl git sudo nano wget dbus avahi-daemon lsb-release

if [[ ! -d /opt/otbr/.git ]]; then
  rm -rf /opt/otbr
  git clone --depth=1 https://github.com/openthread/ot-br-posix /opt/otbr
else
  git -C /opt/otbr fetch --depth=1 origin
  git -C /opt/otbr reset --hard FETCH_HEAD
fi

cd /opt/otbr
./script/bootstrap
INFRA_IF_NAME=eth0 WEB_GUI=1 NAT64=1 DNS64=1 ./script/setup

systemctl daemon-reload
systemctl restart otbr-agent

if systemctl list-unit-files | grep -q '^otbr-web.service'; then
  systemctl enable --now otbr-web
fi
EOF

chmod +x /opt/otbr/update.sh
rm -f /tmp/radio_url.txt /root/otbr-install.sh
apt-get clean
