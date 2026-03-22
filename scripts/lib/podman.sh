#!/usr/bin/env bash

readonly COMPOSE_FILE="${SCRIPT_DIR}/compose.yaml"

PODMAN_BIN=""
COMPOSE_CMD=()

bootstrap_path() {
  local podman_candidates=(
    "/c/Program Files/RedHat/Podman/podman.exe"
    "/mnt/c/Program Files/RedHat/Podman/podman.exe"
  )
  local candidate

  if ! command -v podman >/dev/null 2>&1; then
    for candidate in "${podman_candidates[@]}"; do
      if [[ -x "${candidate}" ]]; then
        PODMAN_BIN="${candidate}"
        podman() {
          "${PODMAN_BIN}" "$@"
        }
        export -f podman
        break
      fi
    done
  fi
}

select_compose_command() {
  if podman compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(podman compose)
    return
  fi

  if command -v podman-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(podman-compose)
    return
  fi

  fail "Neither 'podman compose' nor 'podman-compose' is available."
}

compose_file_arg() {
  if [[ -n "${PODMAN_BIN}" ]] && command -v wslpath >/dev/null 2>&1; then
    wslpath -w "${COMPOSE_FILE}"
    return
  fi

  printf '%s\n' "${COMPOSE_FILE}"
}
