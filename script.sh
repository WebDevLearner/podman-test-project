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
4. Quit
EOF
}

require_interactive_terminal() {
  [[ -t 0 ]] || fail "Interactive terminal required. Run this script in a shell session."
}

main() {
  local choice

  load_podman_mode
  bootstrap_path
  require_interactive_terminal

  while true; do
    show_menu
    read -r -p "Enter choice [1-4]: " choice

    case "${choice}" in
      1)
        compose_up
        show_status
        ;;
      2)
        show_status
        ;;
      3)
        compose_down
        ;;
      4)
        break
        ;;
      *)
        log "Unknown selection: ${choice}. Choose 1, 2, 3, or 4."
        ;;
    esac
  done
}

main
