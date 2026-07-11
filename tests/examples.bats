#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load 'helpers/common'
  require_cmd yq jq perl
}

# --- executable documentation ---

@test "examples/render-config.sh renders imports and placeholders" {
  run --separate-stderr "$REPO_ROOT/examples/render-config.sh"
  [ "$status" -eq 0 ]
  [ "$(yq -r '.banner' <<<"$output")" = "starting demo on port 8080" ]
  [ "$(yq -r '.workers' <<<"$output")" = "4" ]
}

@test "examples/greet-template.sh renders against the environment" {
  run "$REPO_ROOT/examples/greet-template.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == "Hello "*", home is $HOME" ]]
}
