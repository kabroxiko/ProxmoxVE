#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/kabroxiko/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/kabroxiko/trailarr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  wget \
  git \
  python3 \
  python3-dev \
  python3-pip \
  build-essential \
  nodejs \
  npm \
  sqlite3 \
  ffmpeg \
  ca-certificates \
  xz-utils \
  unzip \
  tar \
  pciutils \
  udev \
  usbutils \
  systemd \
  sudo \
  libffi-dev \
  libssl-dev
msg_ok "Installed Dependencies"

msg_info "Setting up Python Environment"
PYTHON_VERSION="3.13" setup_uv
msg_ok "Setup Python Environment"

msg_info "Cloning Trailarr Repository"
cd /opt
$STD git clone https://github.com/kabroxiko/trailarr.git
cd /opt/trailarr
msg_ok "Cloned Trailarr Repository"

msg_info "Building Go Backend"
cd /opt/trailarr
if ! go version | grep -q 'go1.25.1'; then
  msg_info "Installing Go 1.25.1"
  GO_VERSION=1.25.1
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64)
      GO_ARCH=amd64
      ;;
    aarch64|arm64)
      GO_ARCH=arm64
      ;;
    *)
      msg_error "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
  wget -q https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz -O /tmp/go${GO_VERSION}.tar.gz
  rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go${GO_VERSION}.tar.gz
  export PATH=/usr/local/go/bin:$PATH
  rm /tmp/go${GO_VERSION}.tar.gz
  msg_ok "Installed Go 1.25.1"
fi
export GOPATH=/opt/trailarr/.gopath
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
cd /opt/trailarr
make build
msg_ok "Built Go Backend"

msg_info "Building React Frontend"
cd /opt/trailarr/web
npm install
npm run build
msg_ok "Built React Frontend"

msg_info "Installing Media Tools"
# Install ffmpeg to local bin directory
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
  amd64|x86_64)
    FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
    ;;
  arm64|aarch64)
    FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
    ;;
  *)
    ;;
esac

if [ -n "$FFMPEG_URL" ]; then
  cd /tmp
  $STD wget -O - "$FFMPEG_URL" | tar -xJ -C /usr/local/bin --strip-components=1 --wildcards '*/ffmpeg' '*/ffprobe'
  $STD chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe
fi

# Install yt-dlp globally for compatibility
if ! command -v yt-dlp >/dev/null 2>&1; then
  pip3 install --no-cache-dir yt-dlp curl_cffi
fi
msg_ok "Installed Media Tools"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/trailarr.service
[Unit]
Description=Trailarr Daemon
After=syslog.target network.target
[Service]
Type=simple
WorkingDirectory=/opt/trailarr
ExecStart=/opt/trailarr/bin/trailarr
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now trailarr
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
