#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load 'helpers/common'
  load_lib io.sh
}

# --- src ---

@test "src prints a literal argument" {
  run src "just a string"
  [ "$output" = "just a string" ]
}

@test "src reads a file when the argument names one" {
  printf 'file content' >"$BATS_TEST_TMPDIR/f.txt"
  run src "$BATS_TEST_TMPDIR/f.txt"
  [ "$output" = "file content" ]
}

@test "src reads stdin when no argument is given" {
  wrapped() { printf 'piped data' | src; }
  run wrapped
  [ "$output" = "piped data" ]
}

# --- clipboard ---

@test "clipboard returns 1 when no clipboard tool exists" {
  wrapped() { PATH=/nonexistent clipboard "hi"; }
  run wrapped
  [ "$status" -eq 1 ]
}

# --- hashing ---

@test "file_hash_sha256 computes the known digest of 'abc'" {
  printf 'abc' >"$BATS_TEST_TMPDIR/abc.txt"
  run file_hash_sha256 "$BATS_TEST_TMPDIR/abc.txt"
  [ "$output" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" ]
}

# --- downloads ---

@test "download_absent_file downloads via file:// and keeps content" {
  printf 'payload' >"$BATS_TEST_TMPDIR/remote.txt"
  cd "$BATS_TEST_TMPDIR"
  run --separate-stderr download_absent_file "file://$BATS_TEST_TMPDIR/remote.txt" got.txt
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
  [[ "$stderr" == *"Downloading"* ]]
  [ "$(cat got.txt)" = "payload" ]
}

@test "download_absent_file skips when the file already exists" {
  cd "$BATS_TEST_TMPDIR"
  printf 'old' >got.txt
  run --separate-stderr download_absent_file "file:///nonexistent" got.txt
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"already exists"* ]]
  [ "$(cat got.txt)" = "old" ]
}

@test "download_absent_file fails cleanly and leaves no partial file" {
  cd "$BATS_TEST_TMPDIR"
  run download_absent_file "file:///nonexistent-bats-xyz" got.txt
  [ "$status" -ne 0 ]
  [ ! -e got.txt ]
  [ ! -e got.txt.partial ]
}

# --- user input ---

@test "user_input returns what the user types" {
  wrapped() { printf 'typed\n' | user_input "def"; }
  run --separate-stderr wrapped
  [ "$output" = "typed" ]
}

@test "user_input falls back to the default on empty input" {
  wrapped() { printf '\n' | user_input "def"; }
  run --separate-stderr wrapped
  [ "$output" = "def" ]
}

@test "user_input renders the default label once" {
  wrapped() { printf '\n' | user_input "def"; }
  run --separate-stderr wrapped
  [[ "$stderr" == *"[def]"* ]]
  [[ "$stderr" != *"def [def]"* ]]
}

@test "user_input keeps extra arguments as prompt labels" {
  wrapped() { printf '\n' | user_input "def" "def" "" "Enter thing"; }
  run --separate-stderr wrapped
  [[ "$stderr" == *"Enter thing"* ]]
}

@test "default_user_input prompts with the input name" {
  wrapped() { printf '\n' | default_user_input "fallback" "" "port"; }
  run --separate-stderr wrapped
  [ "$output" = "fallback" ]
  [[ "$stderr" == *"Enter port"* ]]
}
