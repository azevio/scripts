#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  require_cmd gpg
  load_lib gpg.sh
  # short mktemp path: gpg agent sockets exceed sun_path limits in deep dirs
  GNUPGHOME="$(mktemp -d)"
  export GNUPGHOME
  chmod 700 "$GNUPGHOME"
}

teardown() {
  if [[ -n "${GNUPGHOME:-}" && -d "$GNUPGHOME" ]]; then
    gpgconf --kill all 2>/dev/null || true
    rm -rf "$GNUPGHOME"
  fi
}

gen_key() {
  gpg_gen_key "${1-pass}" RSA 2048 RSA 2048 "Bats ${2:-One}" "${3:-}" "bats${2:-1}@example.com" 0 >/dev/null 2>&1
}

# --- local keyring ---

@test "gpg_gen_key creates a key with a passphrase" {
  run gen_key pass One comment
  [ "$status" -eq 0 ]
  wrapped() { gpg_long_primary_key_list; }
  run wrapped
  [[ "$output" =~ ^[0-9A-F]{40}$ ]]
}

@test "gpg_gen_key accepts empty passphrase and comment" {
  run gen_key "" Two ""
  [ "$status" -eq 0 ]
  wrapped() { gpg_key_list; }
  run wrapped
  [[ "$output" == *"Bats Two"* ]]
}

@test "gpg_short_key_list is the tail of the primary fingerprint" {
  gen_key
  primary="$(gpg_long_primary_key_list)"
  run gpg_short_key_list
  [ "$output" = "${primary: -8}" ]
}

@test "gpg_long_key_list includes primary and subkey fingerprints" {
  gen_key
  run gpg_long_key_list
  [ "${#lines[@]}" -eq 2 ]
}

@test "gpg_long_primary_key_list lists one fingerprint per key" {
  gen_key pass One
  gen_key pass Two
  run gpg_long_primary_key_list
  [ "${#lines[@]}" -eq 2 ]
}

@test "gpg_export_secret_keys emits an armored private key via stdin passphrase" {
  gen_key secret-pass
  run gpg_export_secret_keys "secret-pass"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PRIVATE KEY BLOCK"* ]]
}

@test "gpg_clean_keys removes all secret and public keys" {
  gen_key
  gpg_clean_keys >/dev/null 2>&1
  run gpg_key_list
  [ "$output" = "" ]
}

# --- keyservers (network, opt-in) ---

@test "is_gpg_key_exported is false for an unpublished key" {
  require_network_opt_in
  run is_gpg_key_exported "0000000000000000000000000000000000000001" "keyserver.ubuntu.com"
  [ "$status" -ne 0 ]
}

@test "is_gpg_key_exported is true for a published key" {
  require_network_opt_in
  # Tor Browser Developers signing key, long published on keyserver.ubuntu.com
  run is_gpg_key_exported "EF6E286DDA85EA2A4BA7DE684E2C6E8793298290" "keyserver.ubuntu.com"
  [ "$status" -eq 0 ]
}
