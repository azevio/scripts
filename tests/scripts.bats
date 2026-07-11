#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  load_lib scripts.sh
}

# --- umbrella ---

@test "scripts.sh exposes a semantic version" {
  [[ "$SCRIPTS_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "scripts.sh sources one function from every module" {
  declare -F ansi_span timestamp info ensure_cmd join_to_string src \
    substitute_string get_ip gpg_gen_key get >/dev/null
}

@test "modules are idempotent under repeated sourcing" {
  load_lib scripts.sh
  load_lib serializer.sh
  declare -F get >/dev/null
}

# --- version guard ---

@test "modules refuse to load on bash older than 4.4" {
  [[ -x /bin/bash ]] || skip "no system bash"
  local major
  major="$(/bin/bash -c 'echo "${BASH_VERSINFO[0]}"')"
  ((major < 4)) || skip "system bash is modern enough"
  run /bin/bash -c "source '$REPO_ROOT/ansi.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bash >= 4.4 required"* ]]
}
