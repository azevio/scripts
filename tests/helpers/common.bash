# Shared bats helpers. Load from a .bats file with: load 'helpers/common'

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export REPO_ROOT

# Source a library file into the current test shell.
load_lib() {
  # shellcheck disable=SC1090
  source "$REPO_ROOT/$1"
}

# Skip the current test unless every named command exists.
require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || skip "$cmd not installed"
  done
}

# Skip unless network-dependent tests were requested explicitly.
require_network_opt_in() {
  [[ -n "${RUN_NETWORK_TESTS:-}" ]] || skip "set RUN_NETWORK_TESTS=1 to run network tests"
}
