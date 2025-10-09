#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/community-scripts/trailarr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"

msg_info "Installing Media Tools"
# Install ffmpeg to local bin directory
FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
cd /tmp
$STD wget -O - "$FFMPEG_URL" | tar -xJ -C /usr/local/bin --strip-components=1 --wildcards '*/ffmpeg' '*/ffprobe'
$STD chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe

msg_info "Installing yt-dlp"
YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
curl -L "$YTDLP_URL" -o /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp
msg_ok "Installed yt-dlp"

msg_info "Installing Trailarr v1"
mkdir -p /var/lib/trailarr/
chmod 775 /var/lib/trailarr/
curl -fsSL "https://github.com/trailarr/trailarr/releases/download/v0.0.3/trailarr-v0.0.3-linux-x64.tar.gz" -o "trailarr.tar.gz"
tar -xzf trailarr.tar.gz
mv trailarr-v*/ /opt/trailarr/
rm -rf trailarr.tar.gz

msg_ok "Installed Trailarr v1"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/trailarr.service
[Unit]
Description=Trailarr Daemon
After=syslog.target network.target
[Service]
Type=simple
WorkingDirectory=/opt/trailarr
ExecStart=/opt/trailarr/trailarr
Environment=HOME=/var/lib/trailarr
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
