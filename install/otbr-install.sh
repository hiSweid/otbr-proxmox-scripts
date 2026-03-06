#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export CMAKE_BUILD_PARALLEL_LEVEL=1
export MAKEFLAGS="-j1"
export npm_config_jobs=1

source /tmp/otbr.env

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
  lsb-release \
  nodejs \
  npm \
  build-essential \
  cmake \
  ninja-build \
  pkg-config \
  python3 \
  socat \
  nginx

command -v lsb_release >/dev/null 2>&1 || { echo "lsb_release fehlt"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "npm fehlt"; exit 1; }

rm -rf /opt/otbr
git clone --depth=1 https://github.com/openthread/ot-br-posix /opt/otbr

cd /opt/otbr
WEB_GUI=1 ./script/bootstrap
INFRA_IF_NAME=eth0 WEB_GUI=1 NAT64=1 DNS64=1 ./script/setup

RADIO_URL=""
mkdir -p /etc/systemd/system/otbr-agent.service.d

if [[ "${MODE}" == "network" ]]; then
  cat >/etc/systemd/system/otbr-radio-bridge.service <<EOF
[Unit]
Description=OTBR TCP Radio Bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/socat PTY,link=/dev/ttyOTBR,raw,echo=0,waitslave TCP:${RADIO_HOST}:${RADIO_PORT}
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now otbr-radio-bridge

  for i in $(seq 1 30); do
    [[ -e /dev/ttyOTBR ]] && break
    sleep 1
  done

  [[ -e /dev/ttyOTBR ]] || { echo "/dev/ttyOTBR wurde nicht erstellt"; exit 1; }

  RADIO_URL="spinel+hdlc+uart:///dev/ttyOTBR?uart-baudrate=460800&uart-init-deassert"

  cat >/etc/systemd/system/otbr-agent.service.d/override.conf <<EOF
[Unit]
After=otbr-radio-bridge.service
Requires=otbr-radio-bridge.service
EOF
else
  RADIO_URL="spinel+hdlc+uart://${USB_PATH}?uart-baudrate=460800"
fi

cat >/etc/default/otbr-agent <<EOF
OTBR_AGENT_OPTS="-I wpan0 -B eth0 ${RADIO_URL}"
EOF

systemctl daemon-reload
systemctl enable --now dbus
systemctl enable --now avahi-daemon
systemctl restart otbr-agent || systemctl start otbr-agent
systemctl restart otbr-web || systemctl start otbr-web

IP="$(hostname -I | awk '{print $1}')"

rm -f /etc/nginx/sites-enabled/default
cat >/etc/nginx/sites-available/otbr <<EOF
server {
    listen ${IP}:80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/otbr /etc/nginx/sites-enabled/otbr
systemctl enable --now nginx
systemctl restart nginx

cat >/etc/default/otbr-helper <<EOF
MODE=${MODE}
RADIO_HOST=${RADIO_HOST:-}
RADIO_PORT=${RADIO_PORT:-}
USB_PATH=${USB_PATH:-/dev/ttyACM0}
EOF

cat >/opt/otbr/update.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export CMAKE_BUILD_PARALLEL_LEVEL=1
export MAKEFLAGS="-j1"
export npm_config_jobs=1

source /etc/default/otbr-helper

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
  lsb-release \
  nodejs \
  npm \
  build-essential \
  cmake \
  ninja-build \
  pkg-config \
  python3 \
  socat \
  nginx

if [[ ! -d /opt/otbr/.git ]]; then
  rm -rf /opt/otbr
  git clone --depth=1 https://github.com/openthread/ot-br-posix /opt/otbr
else
  git -C /opt/otbr fetch --depth=1 origin
  git -C /opt/otbr reset --hard FETCH_HEAD
fi

cd /opt/otbr
WEB_GUI=1 ./script/bootstrap
INFRA_IF_NAME=eth0 WEB_GUI=1 NAT64=1 DNS64=1 ./script/setup

mkdir -p /etc/systemd/system/otbr-agent.service.d

if [[ "${MODE}" == "network" ]]; then
  cat >/etc/systemd/system/otbr-radio-bridge.service <<EOF2
[Unit]
Description=OTBR TCP Radio Bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/socat PTY,link=/dev/ttyOTBR,raw,echo=0,waitslave TCP:${RADIO_HOST}:${RADIO_PORT}
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF2

  systemctl daemon-reload
  systemctl enable --now otbr-radio-bridge

  RADIO_URL="spinel+hdlc+uart:///dev/ttyOTBR?uart-baudrate=460800&uart-init-deassert"

  cat >/etc/systemd/system/otbr-agent.service.d/override.conf <<EOF2
[Unit]
After=otbr-radio-bridge.service
Requires=otbr-radio-bridge.service
EOF2
else
  RADIO_URL="spinel+hdlc+uart://${USB_PATH}?uart-baudrate=460800"
fi

cat >/etc/default/otbr-agent <<EOF2
OTBR_AGENT_OPTS="-I wpan0 -B eth0 ${RADIO_URL}"
EOF2

systemctl daemon-reload
systemctl restart otbr-agent
systemctl restart otbr-web

IP="$(hostname -I | awk '{print $1}')"

rm -f /etc/nginx/sites-enabled/default
cat >/etc/nginx/sites-available/otbr <<EOF2
server {
    listen ${IP}:80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF2

ln -sf /etc/nginx/sites-available/otbr /etc/nginx/sites-enabled/otbr
systemctl restart nginx
EOF

chmod +x /opt/otbr/update.sh
rm -f /tmp/otbr.env /root/otbr-install.sh
apt-get clean
