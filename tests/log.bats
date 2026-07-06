#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load 'helpers/common'
  load_lib log.sh
  COLOR=0
  VERBOSE=1
}

@test "info writes the message to stderr, not stdout" {
  run --separate-stderr info "hello"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
  [[ "$stderr" == *"[INFO] hello"* ]]
}

@test "info is silenced by VERBOSE=0" {
  VERBOSE=0
  run info "hello"
  [ "$output" = "" ]
}

@test "info is not silenced by VERBOSE=true" {
  VERBOSE=true
  run info "hello"
  [[ "$output" == *"[INFO] hello"* ]]
}

@test "warn prints regardless of VERBOSE" {
  VERBOSE=0
  run warn "careful"
  [[ "$output" == *"[WARN] careful"* ]]
}

@test "error exits with the given code and message" {
  wrapped() { error "boom" 7; }
  run wrapped
  [ "$status" -eq 7 ]
  [[ "$output" == *"[ERROR] boom (exit code: 7)"* ]]
}

@test "error defaults to exit code 1" {
  wrapped() { error "boom"; }
  run wrapped
  [ "$status" -eq 1 ]
}

@test "COLOR=1 emits ANSI escapes, COLOR=0 does not" {
  COLOR=1
  run info "tinted"
  [[ "$output" == *$'\033'* ]]
  COLOR=0
  run info "plain"
  [[ "$output" != *$'\033'* ]]
}

@test "log lines carry a bracketed timestamp" {
  run info "stamped"
  [[ "$output" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\] ]]
}

@test "check dies when the condition is true" {
  wrapped() { check '[[ 1 -eq 1 ]]' "always"; }
  run wrapped
  [ "$status" -eq 1 ]
  [[ "$output" == *"always"* ]]
}

@test "check passes when the condition is false" {
  run check '[[ 1 -eq 2 ]]' "never"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
