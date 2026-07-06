#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  load_lib array.sh
}

@test "join_to_string joins with comma by default" {
  local a=(1 2 3)
  run join_to_string a
  [ "$status" -eq 0 ]
  [ "$output" = "1,2,3" ]
}

@test "join_to_string joins with a custom delimiter" {
  local a=(1 2 3)
  run join_to_string a "-"
  [ "$output" = "1-2-3" ]
}

@test "join_to_string preserves option-like values" {
  local a=(-n)
  run join_to_string a
  [ "$output" = "-n" ]
}

@test "join_to_string of a single element is the element" {
  local a=(solo)
  run join_to_string a
  [ "$output" = "solo" ]
}

@test "join_to_string of an empty array is empty" {
  local a=()
  run join_to_string a
  [ "$output" = "" ]
}

@test "join_to_string uses only the first delimiter character" {
  local a=(1 2)
  run join_to_string a ", "
  [ "$output" = "1,2" ]
}
