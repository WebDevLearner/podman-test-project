#!/usr/bin/env bash

log() {
  printf '[podman-test] %s\n' "$*"
}

fail() {
  printf '[podman-test] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || fail "Required command not found: ${command_name}"
}
