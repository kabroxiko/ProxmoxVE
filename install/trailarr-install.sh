#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/kabroxiko/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/nandyalu/trailarr

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
$STD git clone https://github.com/kabroxiko/trailarr.git
cd /opt/trailarr
msg_ok "Cloned Trailarr Repository"

msg_info "Creating Trailarr User"
useradd -r -d /opt/trailarr -s /bin/bash -m trailarr
msg_ok "Created Trailarr User"

msg_info "Setting up Directories"
mkdir -p /var/lib/trailarr/{logs,backups,web/images,tmp}
mkdir -p /var/log/trailarr
mkdir -p /opt/trailarr/.local/bin
chmod 755 /opt/trailarr /var/lib/trailarr /var/log/trailarr
chmod -R 755 /var/lib/trailarr/*
chown -R trailarr:trailarr /opt/trailarr
chown -R trailarr:trailarr /var/lib/trailarr
chown -R trailarr:trailarr /var/log/trailarr
msg_ok "Setup Directories"

msg_info "Installing uv Package Manager"
$STD sudo -u trailarr bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
$STD sudo -u trailarr bash -c 'echo export PATH="\$HOME/.local/bin:\$PATH" >> $HOME/.bashrc'
msg_ok "Installed uv Package Manager"

msg_info "Installing Python Dependencies"
cd /opt/trailarr/backend
$STD sudo -u trailarr bash -c '/opt/trailarr/.local/bin/uv sync --no-cache-dir'
msg_ok "Installed Python Dependencies"

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

chown -R trailarr:trailarr /opt/trailarr/.local/bin

# Symlink ffmpeg and ffprobe to /usr/local/bin for compatibility
ln -sf /opt/trailarr/.local/bin/ffmpeg /usr/local/bin/ffmpeg
ln -sf /opt/trailarr/.local/bin/ffprobe /usr/local/bin/ffprobe
msg_ok "Installed Media Tools"

# Symlink yt-dlp to /usr/local/bin for compatibility
ln -sf /opt/trailarr/backend/.venv/bin/yt-dlp /usr/local/bin/yt-dlp

msg_info "Creating Environment Configuration"
cat <<EOF >/var/lib/trailarr/.env
# Trailarr Configuration
APP_DATA_DIR=/var/lib/trailarr
APP_PORT=7889
APP_HOST=0.0.0.0
APP_LOG_LEVEL=INFO
APP_UPDATE_YTDLP=true
APP_TIMEZONE=UTC
APP_THEME=dark
FFMPEG_PATH=/opt/trailarr/.local/bin/ffmpeg
FFPROBE_PATH=/opt/trailarr/.local/bin/ffprobe
YTDLP_PATH=/opt/trailarr/backend/.venv/bin/yt-dlp
PYTHON_EXECUTABLE=/opt/trailarr/backend/.venv/bin/python
PYTHON_VENV=/opt/trailarr/backend/.venv
PYTHONPATH=/opt/trailarr/backend
EOF
chown trailarr:trailarr /var/lib/trailarr/.env
msg_ok "Created Environment Configuration"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/trailarr.service
[Unit]
Description=Trailarr - Trailer downloader for Radarr and Sonarr
Documentation=https://github.com/nandyalu/trailarr
After=network.target

[Service]
Type=simple
User=trailarr
Group=trailarr
WorkingDirectory=/opt/trailarr
Environment=PYTHONPATH=/opt/trailarr/backend
Environment=PATH=/opt/trailarr/.local/bin:/opt/trailarr/backend/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EnvironmentFile=/var/lib/trailarr/.env
ExecStartPre=+/opt/trailarr/scripts/baremetal/baremetal_pre_start.sh
ExecStart=/opt/trailarr/scripts/baremetal/baremetal_start.sh
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
