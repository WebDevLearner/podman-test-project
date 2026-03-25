#!/usr/bin/env bash

readonly PODMAN_MODE_FILE="${SCRIPT_DIR}/.podman-mode"

PODMAN_BIN=""
USE_SUDO_PODMAN=0

resolve_podman_binary() {
  local podman_candidates=(
    "/c/Program Files/RedHat/Podman/podman.exe"
    "/mnt/c/Program Files/RedHat/Podman/podman.exe"
  )
  local candidate

  if [[ -n "${PODMAN_BIN}" ]]; then
    return 0
  fi

  if type -P podman >/dev/null 2>&1; then
    PODMAN_BIN="$(type -P podman)"
    return 0
  fi

  for candidate in "${podman_candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      PODMAN_BIN="${candidate}"
      return 0
    fi
  done

  fail "Required command not found: podman"
}

podman() {
  resolve_podman_binary

  if (( USE_SUDO_PODMAN == 1 )); then
    command sudo "${PODMAN_BIN}" "$@"
    return
  fi

  "${PODMAN_BIN}" "$@"
}

bootstrap_path() {
  resolve_podman_binary
}

load_podman_mode() {
  if [[ -f "${PODMAN_MODE_FILE}" ]] && [[ "$(tr -d '\r\n' < "${PODMAN_MODE_FILE}")" == "sudo" ]]; then
    USE_SUDO_PODMAN=1
  fi
}

save_podman_mode() {
  local mode="$1"
  printf '%s\n' "${mode}" > "${PODMAN_MODE_FILE}"
}

enable_sudo_podman() {
  command -v sudo >/dev/null 2>&1 || fail "Rootless Podman failed and sudo is not available."
  log "Switching to sudo podman for compatibility on this host"
  command sudo -v
  USE_SUDO_PODMAN=1
  save_podman_mode "sudo"
}

maybe_enable_sudo_podman() {
  local answer=""

  if (( USE_SUDO_PODMAN == 1 )); then
    return 1
  fi

  if [[ -t 0 ]]; then
    read -r -p "Rootless Podman failed. Retry with sudo podman? [Y/n] " answer
  fi

  case "${answer:-Y}" in
    Y|y|YES|yes|"")
      enable_sudo_podman
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
