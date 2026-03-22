#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/common.sh"
source "${SCRIPT_DIR}/scripts/lib/podman.sh"
source "${SCRIPT_DIR}/scripts/lib/stack.sh"

show_menu() {
  cat <<'EOF'
Select an option:
1. Start stack
2. Show status
3. Stop stack
EOF
}

require_interactive_terminal() {
  [[ -t 0 ]] || fail "Interactive terminal required. Run this script in a shell session."
}

require_start_prerequisites() {
  [[ -f "${COMPOSE_FILE}" ]] || fail "compose file not found at ${COMPOSE_FILE}"
}

require_stop_prerequisites() {
  :
}

main() {
  local choice

  load_podman_mode
  bootstrap_path
  require_interactive_terminal
  show_menu
  read -r -p "Enter choice [1-3]: " choice

  case "${choice}" in
    1)
      require_start_prerequisites
      compose_up
      show_status
      ;;
    2)
      show_status
      ;;
    3)
      require_stop_prerequisites
      compose_down
      ;;
    *)
      fail "Unknown selection: ${choice}. Choose 1, 2, or 3."
      ;;
  esac
}

main
