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
  build-essential \
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
if ! command -v go >/dev/null 2>&1; then
  $STD apt-get install -y golang
fi
export GOPATH=/opt/trailarr/.gopath
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
cd /opt/trailarr
make build
msg_ok "Built Go Backend"

msg_info "Building React Frontend"
if ! command -v npm >/dev/null 2>&1; then
  $STD apt-get install -y nodejs npm
fi
cd /opt/trailarr/web
npm install
npm run build
msg_ok "Built React Frontend"

msg_info "Setting up Directories"
mkdir -p /var/lib/trailarr/{logs,backups,web/images,tmp}
mkdir -p /var/log/trailarr
mkdir -p /opt/trailarr/.local/bin
chmod 755 /opt/trailarr /var/lib/trailarr /var/log/trailarr
chmod -R 755 /var/lib/trailarr/*
msg_ok "Setup Directories"

msg_info "Installing Media Tools"
# Install ffmpeg to local bin directory
mkdir -p /opt/trailarr/.local/bin
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
  amd64|x86_64)
    FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
    ;;
  arm64|aarch64)
    FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
    ;;
  *)
    # Fallback to system ffmpeg for unsupported architectures
    if command -v ffmpeg >/dev/null 2>&1; then
      $STD cp "$(which ffmpeg)" "/opt/trailarr/.local/bin/"
      $STD cp "$(which ffprobe)" "/opt/trailarr/.local/bin/"
    fi
    ;;
esac

if [ -n "$FFMPEG_URL" ]; then
  cd /tmp
  $STD curl -L -o ffmpeg.tar.xz "$FFMPEG_URL"
  $STD mkdir -p ffmpeg_extract
  $STD tar -xf ffmpeg.tar.xz -C ffmpeg_extract --strip-components=1
  $STD cp ffmpeg_extract/ffmpeg ffmpeg_extract/ffprobe "/opt/trailarr/.local/bin/"
  $STD rm -rf ffmpeg.tar.xz ffmpeg_extract
fi



# Symlink ffmpeg and ffprobe to /usr/local/bin for compatibility
ln -sf /opt/trailarr/.local/bin/ffmpeg /usr/local/bin/ffmpeg
ln -sf /opt/trailarr/.local/bin/ffprobe /usr/local/bin/ffprobe
msg_ok "Installed Media Tools"


# Install yt-dlp globally for compatibility
if ! command -v yt-dlp >/dev/null 2>&1; then
  pip3 install --no-cache-dir yt-dlp
fi
ln -sf $(which yt-dlp) /usr/local/bin/yt-dlp

msg_info "Creating Environment Configuration"
msg_ok "Created Environment Configuration"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/trailarr.service
[Unit]
Description=Trailarr - Trailer downloader for Radarr and Sonarr
Documentation=https://github.com/kabroxiko/trailarr
After=network.target


[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/app
ExecStart=/app/bin/trailarr
Restart=always
RestartSec=60
TimeoutStopSec=30

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/var/lib/trailarr /var/log/trailarr /opt/trailarr
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

# Make sure the scripts are executable
chmod +x /opt/trailarr/scripts/baremetal/*.sh

systemctl enable -q --now trailarr
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
