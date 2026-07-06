#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load 'helpers/common'
  load_lib net.sh
}

@test "get_ip always returns an IPv4 address" {
  run get_ip
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

@test "hosts_set rejects an unsupported OS" {
  os_name() { printf 'SunOS'; }
  local hosts=(example.test)
  run --separate-stderr hosts_set hosts
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"Unsupported SunOS OS"* ]]
}
