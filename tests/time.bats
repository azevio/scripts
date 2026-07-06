#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  load_lib time.sh
}

@test "timestamp prints a YYYY-MM-DD HH:MM:SS time" {
  run timestamp
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]
}

@test "timestamp matches the system clock date" {
  run timestamp
  [[ "$output" == "$(date +%Y-%m-%d)"* ]]
}
