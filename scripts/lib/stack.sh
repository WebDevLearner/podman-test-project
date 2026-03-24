#!/usr/bin/env bash

readonly MYSQL_CONTAINER="podman-test-mysql"
readonly RABBITMQ_CONTAINER="podman-test-rabbitmq"
readonly APP_CONTAINER="podman-test-api-compose"
readonly API_BASE_URL="http://localhost:8080/api/messages"
readonly NETWORK_NAME="podman-test-network"
readonly RABBITMQ_IMAGE="localhost/podman-test-rabbitmq:latest"
readonly APP_IMAGE="localhost/podman-test-app:latest"

runtime_preflight() {
  log "Running Podman runtime preflight"

  if ! podman run --rm docker.io/library/hello-world >/tmp/podman-runtime-preflight.log 2>&1; then
    cat /tmp/podman-runtime-preflight.log >&2 || true

    if maybe_enable_sudo_podman && podman run --rm docker.io/library/hello-world >/tmp/podman-runtime-preflight.log 2>&1; then
      return 0
    fi

    cat /tmp/podman-runtime-preflight.log >&2 || true
    fail "Podman cannot run a basic container on this host. Fix the Podman runtime before starting the stack."
  fi
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
  log "Networks"
  podman network ls --format "table {{.Name}}\t{{.Driver}}"
}

build_images() {
  log "Building RabbitMQ image with podman"
  if ! podman build -t "${RABBITMQ_IMAGE}" -f "${SCRIPT_DIR}/rabbitmq/Containerfile" "${SCRIPT_DIR}/rabbitmq"; then
    if maybe_enable_sudo_podman; then
      podman build -t "${RABBITMQ_IMAGE}" -f "${SCRIPT_DIR}/rabbitmq/Containerfile" "${SCRIPT_DIR}/rabbitmq"
    else
      fail "Failed to build RabbitMQ image with rootless Podman."
    fi
  fi

  log "Building application image with podman"
  if ! podman build -t "${APP_IMAGE}" -f "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"; then
    if maybe_enable_sudo_podman; then
      podman build -t "${APP_IMAGE}" -f "${SCRIPT_DIR}/Containerfile" "${SCRIPT_DIR}"
    else
      fail "Failed to build application image with rootless Podman."
    fi
  fi
}

remove_container_if_present() {
  local container_name="$1"
  if podman inspect "${container_name}" >/dev/null 2>&1; then
    podman rm -f "${container_name}" >/dev/null
  fi
}

ensure_network() {
  if ! podman network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    podman network create "${NETWORK_NAME}" >/dev/null
  fi
}

run_mysql() {
  remove_container_if_present "${MYSQL_CONTAINER}"
  podman run -d \
    --name "${MYSQL_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    --network-alias mysql \
    -e MYSQL_ROOT_PASSWORD=test \
    -e MYSQL_DATABASE=podman_test \
    -p 3307:3306 \
    --health-cmd "mysqladmin ping -h 127.0.0.1 -uroot -ptest" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 10 \
    docker.io/library/mysql:8.0 >/dev/null
}

run_rabbitmq() {
  remove_container_if_present "${RABBITMQ_CONTAINER}"
  podman run -d \
    --name "${RABBITMQ_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    --network-alias rabbitmq \
    -p 5672:5672 \
    -p 15672:15672 \
    --health-cmd "rabbitmq-diagnostics -q ping" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 10 \
    "${RABBITMQ_IMAGE}" >/dev/null
}

run_app() {
  remove_container_if_present "${APP_CONTAINER}"
  podman run -d \
    --name "${APP_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    -e DB_URL="jdbc:mysql://mysql:3306/podman_test?createDatabaseIfNotExist=false&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
    -e DB_USERNAME=root \
    -e DB_PASSWORD=test \
    -e RABBITMQ_HOST=rabbitmq \
    -e RABBITMQ_PORT=5672 \
    -e RABBITMQ_USERNAME=guest \
    -e RABBITMQ_PASSWORD=guest \
    -e MESSAGING_ENABLED=true \
    -e MESSAGING_QUEUE=podman.test.messages \
    -p 8080:8080 \
    "${APP_IMAGE}" >/dev/null
}

compose_up() {
  runtime_preflight
  build_images
  ensure_network
  log "Starting MySQL, RabbitMQ, and the Spring Boot API"
  run_mysql
  run_rabbitmq

  wait_for_container_state "${MYSQL_CONTAINER}" healthy 180
  wait_for_container_state "${RABBITMQ_CONTAINER}" healthy 180
  run_app
  wait_for_container_state "${APP_CONTAINER}" running 180
  wait_for_api 180
}

compose_down() {
  log "Stopping containers"
  remove_container_if_present "${APP_CONTAINER}"
  remove_container_if_present "${RABBITMQ_CONTAINER}"
  remove_container_if_present "${MYSQL_CONTAINER}"
  if podman network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    podman network rm "${NETWORK_NAME}" >/dev/null || true
  fi
}
