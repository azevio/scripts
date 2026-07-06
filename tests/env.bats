#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  load_lib env.sh
}

@test "os_name matches uname -s" {
  run os_name
  [ "$output" = "$(uname -s)" ]
}

@test "arch_name matches uname -m" {
  run arch_name
  [ "$output" = "$(uname -m)" ]
}

@test "ensure_cmd passes for an existing command" {
  run ensure_cmd bash
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "ensure_cmd dies for a missing command" {
  run ensure_cmd definitely-missing-cmd-xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"Required command not found"* ]]
}

@test "bash_env resolves a set variable by name" {
  export FOO_BATS=val
  run bash_env FOO_BATS
  [ "$status" -eq 0 ]
  [ "$output" = "val" ]
}

@test "bash_env resolves an empty-but-set variable to empty" {
  export FOO_BATS=""
  run bash_env "FOO_BATS-dflt"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "bash_env falls back to the -default suffix when unset" {
  unset FOO_BATS
  run bash_env "FOO_BATS-dflt"
  [ "$status" -eq 0 ]
  [ "$output" = "dflt" ]
}

@test "bash_env keeps dashes inside the default value" {
  unset FOO_BATS
  run bash_env "FOO_BATS-a-b"
  [ "$output" = "a-b" ]
}

@test "bash_env returns NO_SUCH_ELEMENT when unset without default" {
  unset FOO_BATS
  run bash_env FOO_BATS
  [ "$status" -eq 101 ]
}

@test "bash_env accepts the getter protocol (array name)" {
  export FOO_BATS=via-array
  local keys=(FOO_BATS)
  run bash_env keys
  [ "$status" -eq 0 ]
  [ "$output" = "via-array" ]
}

@test "bash_env rejects multi-component paths with NO_SUCH_ELEMENT" {
  local keys=(a b)
  run bash_env keys
  [ "$status" -eq 101 ]
}

@test "bash_env rejects non-identifier keys instead of evaluating them" {
  local keys=('x[$(echo pwned)]')
  run bash_env keys
  [ "$status" -eq 101 ]
  [ "$output" = "" ]
}

@test "bash_c runs a script and returns its output" {
  run bash_c 'printf hi'
  [ "$status" -eq 0 ]
  [ "$output" = "hi" ]
}

@test "bash_c fails fast on the first error (errexit)" {
  run bash_c 'false; echo not-reached'
  [ "$status" -ne 0 ]
  [[ "$output" != *"not-reached"* ]]
}

@test "bash_c propagates pipeline failures (pipefail)" {
  run bash_c 'false | true'
  [ "$status" -ne 0 ]
}
