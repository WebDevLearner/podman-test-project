#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_FILE="${SCRIPT_DIR}/compose.yaml"
readonly MYSQL_CONTAINER="podman-test-mysql"
readonly RABBITMQ_CONTAINER="podman-test-rabbitmq"
readonly APP_CONTAINER="podman-test-api-compose"
readonly API_BASE_URL="http://localhost:8080/api/messages"
readonly QUEUE_NAME="podman.test.messages"

PODMAN_BIN=""
COMPOSE_CMD=()

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

api_call() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local response

  if [[ -n "${body}" ]]; then
    response="$(curl --silent --show-error \
      --request "${method}" \
      --header 'Content-Type: application/json' \
      --data "${body}" \
      --write-out $'\n%{http_code}' \
      "${url}")"
  else
    response="$(curl --silent --show-error \
      --request "${method}" \
      --write-out $'\n%{http_code}' \
      "${url}")"
  fi

  API_RESPONSE_BODY="${response%$'\n'*}"
  API_RESPONSE_CODE="${response##*$'\n'}"
}

extract_json_number() {
  local json="$1"
  local key="$2"

  printf '%s' "${json}" | sed -n "s/.*\"${key}\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p"
}

assert_contains() {
  local content="$1"
  local expected="$2"

  [[ "${content}" == *"${expected}"* ]] || fail "Expected response to contain: ${expected}"
}

show_status() {
  log "Containers"
  podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  log "Pods"
  podman pod ps --format "table {{.Name}}\t{{.Status}}\t{{.Containers}}" || true
}

compose_file_arg() {
  if [[ -n "${PODMAN_BIN}" ]] && command -v wslpath >/dev/null 2>&1; then
    wslpath -w "${COMPOSE_FILE}"
    return
  fi

  printf '%s\n' "${COMPOSE_FILE}"
}

run_smoke_test() {
  local create_payload='{"author":"aws-linux","content":"created by script"}'
  local update_payload
  local message_id
  local db_match_count
  local queue_ready

  log "Running API smoke test"

  api_call GET "${API_BASE_URL}"
  [[ "${API_RESPONSE_CODE}" == "200" ]] || fail "GET /api/messages returned ${API_RESPONSE_CODE}"

  api_call POST "${API_BASE_URL}" "${create_payload}"
  [[ "${API_RESPONSE_CODE}" == "201" ]] || fail "POST /api/messages returned ${API_RESPONSE_CODE}"
  assert_contains "${API_RESPONSE_BODY}" '"author":"aws-linux"'
  assert_contains "${API_RESPONSE_BODY}" '"content":"created by script"'

  message_id="$(extract_json_number "${API_RESPONSE_BODY}" "id")"
  [[ -n "${message_id}" ]] || fail "Could not read created message id from API response"
  log "Created message ${message_id}"

  api_call GET "${API_BASE_URL}/${message_id}"
  [[ "${API_RESPONSE_CODE}" == "200" ]] || fail "GET /api/messages/${message_id} returned ${API_RESPONSE_CODE}"
  assert_contains "${API_RESPONSE_BODY}" "\"id\":${message_id}"

  update_payload="{\"author\":\"aws-linux\",\"content\":\"updated by script\"}"
  api_call PUT "${API_BASE_URL}/${message_id}" "${update_payload}"
  [[ "${API_RESPONSE_CODE}" == "200" ]] || fail "PUT /api/messages/${message_id} returned ${API_RESPONSE_CODE}"
  assert_contains "${API_RESPONSE_BODY}" '"content":"updated by script"'

  db_match_count="$(podman exec "${MYSQL_CONTAINER}" \
    mysql -N -uroot -ptest -D podman_test \
    -e "SELECT COUNT(*) FROM messages WHERE id = ${message_id} AND author = 'aws-linux' AND content = 'updated by script';" \
    | tr -d '\r')"
  [[ "${db_match_count}" == "1" ]] || fail "MySQL validation failed for message ${message_id}"
  log "MySQL row verified for message ${message_id}"

  queue_ready="$(podman exec "${RABBITMQ_CONTAINER}" rabbitmqctl list_queues name messages_ready \
    | awk -v queue="${QUEUE_NAME}" '$1 == queue { print $2 }' \
    | tr -d '\r')"
  [[ -n "${queue_ready}" ]] || fail "RabbitMQ queue ${QUEUE_NAME} not found"
  log "RabbitMQ queue ${QUEUE_NAME} has ${queue_ready} ready message(s)"

  api_call DELETE "${API_BASE_URL}/${message_id}"
  [[ "${API_RESPONSE_CODE}" == "204" ]] || fail "DELETE /api/messages/${message_id} returned ${API_RESPONSE_CODE}"

  api_call GET "${API_BASE_URL}/${message_id}"
  [[ "${API_RESPONSE_CODE}" == "404" ]] || fail "Expected deleted message ${message_id} to return 404"
  assert_contains "${API_RESPONSE_BODY}" "\"message\":\"message ${message_id} was not found\""

  log "Smoke test passed"
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

main() {
  local command="${1:-up}"

  bootstrap_path
  require_command podman
  require_command curl
  [[ -f "${COMPOSE_FILE}" ]] || fail "compose file not found at ${COMPOSE_FILE}"

  select_compose_command

  case "${command}" in
    up)
      compose_up
      show_status
      run_smoke_test
      ;;
    smoke)
      show_status
      run_smoke_test
      ;;
    status)
      show_status
      ;;
    down)
      compose_down
      ;;
    logs)
      podman logs "${APP_CONTAINER}"
      ;;
    *)
      fail "Unknown command: ${command}. Use: up | smoke | status | down | logs"
      ;;
  esac
}

main "$@"
