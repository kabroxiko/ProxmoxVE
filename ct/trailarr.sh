#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/community-scripts/trailarr

APP="Trailarr"
var_tags="${var_tags:-arr}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /var/lib/trailarr/ ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping Service"
  systemctl stop trailarr
  msg_ok "Stopped Service"

  msg_info "Updating Trailarr"
  cd /opt/trailarr
  $STD git fetch --all
  $STD git reset --hard origin/main
  $STD git pull

  # Ensure scripts are executable
  chmod +x /opt/trailarr/scripts/baremetal/*.sh

  msg_info "Updating Python Dependencies"
  cd /opt/trailarr/backend
  $STD sudo -u trailarr /opt/trailarr/.local/bin/uv sync --no-cache-dir
  msg_ok "Updated Python Dependencies"

  msg_info "Starting Service"
  systemctl start trailarr
  msg_ok "Started Service"
  msg_ok "Updated successfully"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
