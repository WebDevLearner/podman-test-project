#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_FILE="${SCRIPT_DIR}/compose.yaml"
readonly MYSQL_CONTAINER="podman-test-mysql"
readonly RABBITMQ_CONTAINER="podman-test-rabbitmq"
readonly APP_CONTAINER="podman-test-api-compose"
readonly API_URL="http://localhost:8080/api/v1/test"

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

wait_for_container_state() {
  local container_name="$1"
  local expected_state="$2"
  local timeout_seconds="$3"
  local elapsed=0
  local state

  while (( elapsed < timeout_seconds )); do
    state="$(podman inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_name}" 2>/dev/null || true)"

    if [[ "${state}" == "${expected_state}" ]]; then
      log "${container_name} is ${expected_state}"
      return 0
    fi

    if [[ "${state}" == "unhealthy" || "${state}" == "exited" || "${state}" == "stopped" ]]; then
      podman logs "${container_name}" || true
      fail "${container_name} entered unexpected state: ${state}"
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done

  podman logs "${container_name}" || true
  fail "Timed out waiting for ${container_name} to become ${expected_state}"
}

wait_for_api() {
  local timeout_seconds="$1"
  local elapsed=0

  if ! command -v curl >/dev/null 2>&1; then
    log "curl not found; skipping API probe. Verify manually at ${API_URL}"
    return 0
  fi

  while (( elapsed < timeout_seconds )); do
    if curl --silent --show-error --fail "${API_URL}" >/dev/null; then
      log "API is responding at ${API_URL}"
      return 0
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done

  podman logs "${APP_CONTAINER}" || true
  fail "Timed out waiting for API to respond at ${API_URL}"
}

main() {
  require_command podman
  [[ -f "${COMPOSE_FILE}" ]] || fail "compose file not found at ${COMPOSE_FILE}"

  select_compose_command

  log "Using compose command: ${COMPOSE_CMD[*]}"
  log "Starting MySQL, RabbitMQ, and the Spring Boot API"
  "${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" up -d --build

  wait_for_container_state "${MYSQL_CONTAINER}" healthy 180
  wait_for_container_state "${RABBITMQ_CONTAINER}" healthy 180
  wait_for_container_state "${APP_CONTAINER}" running 180
  wait_for_api 180

  cat <<'EOF'

Environment is up.

API:
  http://localhost:8080/api/v1/test

MySQL:
  jdbc:mysql://localhost:3307/podman_test?createDatabaseIfNotExist=false&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
  mysql://root:test@localhost:3307/podman_test

RabbitMQ:
  amqp://guest:guest@localhost:5672
  http://guest:guest@localhost:15672

Quick checks:
  curl http://localhost:8080/api/v1/test
  curl -u guest:guest http://localhost:15672/api/overview
  mysql -h 127.0.0.1 -P 3307 -u root -ptest -D podman_test -e "SHOW TABLES;"
EOF
}

main "$@"
