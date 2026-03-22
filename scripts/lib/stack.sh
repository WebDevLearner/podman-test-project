#!/usr/bin/env bash

readonly MYSQL_CONTAINER="podman-test-mysql"
readonly RABBITMQ_CONTAINER="podman-test-rabbitmq"
readonly APP_CONTAINER="podman-test-api-compose"
readonly API_BASE_URL="http://localhost:8080/api/messages"

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
    log "curl not found; skipping API probe. Verify manually at ${API_BASE_URL}"
    return 0
  fi

  while (( elapsed < timeout_seconds )); do
    if curl --silent --show-error --fail "${API_BASE_URL}" >/dev/null; then
      log "API is responding at ${API_BASE_URL}"
      return 0
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done

  podman logs "${APP_CONTAINER}" || true
  fail "Timed out waiting for API to respond at ${API_BASE_URL}"
}

show_status() {
  log "Containers"
  podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  log "Pods"
  podman pod ps --format "table {{.Name}}\t{{.Status}}\t{{.Containers}}" || true
}

compose_up() {
  local compose_file
  compose_file="$(compose_file_arg)"

  log "Using compose command: ${COMPOSE_CMD[*]}"
  log "Starting MySQL, RabbitMQ, and the Spring Boot API"
  "${COMPOSE_CMD[@]}" -f "${compose_file}" up -d --build

  wait_for_container_state "${MYSQL_CONTAINER}" healthy 180
  wait_for_container_state "${RABBITMQ_CONTAINER}" healthy 180
  wait_for_container_state "${APP_CONTAINER}" running 180
  wait_for_api 180
}

compose_down() {
  local compose_file
  compose_file="$(compose_file_arg)"

  log "Stopping compose stack"
  "${COMPOSE_CMD[@]}" -f "${compose_file}" down --remove-orphans
}
