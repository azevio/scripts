#!/usr/bin/env bash
# Regression smoke tests for the script library. Run: bash tests/smoke.sh
# Only exercises local, side-effect-free paths (no network, gpg, clipboard, hosts).
set -u

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." || exit 1

REPO="$PWD"
failures=0

function assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s\n  expected: [%s]\n  actual:   [%s]\n' "$label" "$expected" "$actual"
    ((failures += 1))
  fi
}

function assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s\n  missing:  [%s]\n  in:       [%s]\n' "$label" "$needle" "$haystack"
    ((failures += 1))
  fi
}

function assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s\n  unexpected: [%s]\n  in:         [%s]\n' "$label" "$needle" "$haystack"
    ((failures += 1))
  fi
}

# --- string.sh: interpolation ---

out="$( (source ./string.sh; substitute_string -e false <<<'home=${HOME} end') 2>/dev/null )"
assert_eq "braced env interpolation" "home=$HOME end" "$out"

out="$( (source ./string.sh; unset MISSING_VAR_XYZ_123; substitute_string -e false <<<'${MISSING_VAR_XYZ_123-dflt}') 2>/dev/null )"
assert_eq "env default value" "dflt" "$out"

out="$( (source ./string.sh; unset MISSING_VAR_XYZ_123; substitute_string -e false <<<'${MISSING_VAR_XYZ_123}') 2>/dev/null )"
status=$?
assert_eq "unset env keeps raw text" '${MISSING_VAR_XYZ_123}' "$out"
assert_eq "unset env returns NO_SUCH_ELEMENT" "101" "$status"

out="$( (source ./string.sh; substitute_string -i true -e false <<<'v=$HOME. Done') 2>/dev/null )"
assert_eq "unbraced keeps dot boundary" "v=$HOME. Done" "$out"

out="$( (source ./string.sh; substitute_string -i true -e false <<<'v=$HOME end') 2>/dev/null )"
assert_eq "unbraced keeps space boundary" "v=$HOME end" "$out"

out="$( (source ./string.sh; substitute_string -e false <<<'cost $$HOME') 2>/dev/null )"
assert_eq "double dollar unescapes" 'cost $HOME' "$out"

# --- string.sh: option parsing ---

out="$( (source ./string.sh; substitute_string -zz true -e false <<<'plain') 2>/dev/null )"
assert_eq "unknown option kept off stdout" "plain" "$out"

out="$( (ulimit -t 5; source ./string.sh; substitute_string -i <<<'x') 2>/dev/null )"
assert_eq "missing option value terminates" "x" "$out"

# --- string.sh: evaluation ---

out="$( (source ./string.sh; substitute_string <<<'n=$<printf %s 42>') 2>/dev/null )"
assert_eq "evaluate expression" "n=42" "$out"

tpl="x=\$<printf %s 'a\\nb'>"
out="$( (source ./string.sh; substitute_string <<<"$tpl") 2>/dev/null )"
assert_eq "single-quote escapes inside eval" 'x=a\nb' "$out"

out="$( (source ./string.sh; substitute_string <<<'a $<echo hi') 2>/dev/null )"
status=$?
assert_eq "unterminated eval emits nothing" "" "$out"
assert_not_contains "unterminated eval fails" "status=0" "status=$status"

# --- string.sh: misc ---

out="$( (source ./string.sh; trim "x" "xhellox") 2>/dev/null )"
assert_eq "trim" "hello" "$out"

# --- array.sh ---

out="$( (source ./array.sh; a=(-n); join_to_string a) )"
assert_eq "join_to_string option-like value" "-n" "$out"

out="$( (source ./array.sh; a=(1 2 3); join_to_string a "-") )"
assert_eq "join_to_string delimiter" "1-2-3" "$out"

# --- env.sh ---

out="$( (source ./env.sh; FOO_SMOKE=val bash_env "FOO_SMOKE") 2>/dev/null )"
assert_eq "bash_env direct string" "val" "$out"

out="$( (source ./env.sh; unset FOO_SMOKE; bash_env "FOO_SMOKE-dflt") 2>/dev/null )"
assert_eq "bash_env direct default" "dflt" "$out"

( source ./env.sh; ensure_cmd definitely_missing_cmd_xyz ) 2>/dev/null
assert_eq "ensure_cmd aborts on missing command" "1" "$?"

# --- log.sh ---

out="$( (source ./log.sh; VERBOSE=true COLOR=0 info "hello") 2>&1 )"
assert_contains "VERBOSE=true keeps info" "[INFO] hello" "$out"

out="$( (source ./log.sh; VERBOSE=0 COLOR=0 info "hello") 2>&1 )"
assert_eq "VERBOSE=0 silences info" "" "$out"

# --- io.sh ---

out="$(printf 'typed\n' | (source ./io.sh; user_input "def") 2>/dev/null)"
assert_eq "user_input returns typed value" "typed" "$out"

out="$(printf '\n' | (source ./io.sh; user_input "def") 2>/dev/null)"
assert_eq "user_input falls back to default" "def" "$out"

err="$( { printf '\n' | (source ./io.sh; user_input "def") >/dev/null; } 2>&1 )"
assert_contains "user_input shows default label" "[def]" "$err"
assert_not_contains "user_input default not duplicated as label" "def [def]" "$err"

tmpf="$(mktemp)"
printf 'abc' >"$tmpf"
out="$( (source ./io.sh; file_hash_sha256 "$tmpf") 2>/dev/null )"
assert_eq "file_hash_sha256" "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" "$out"
rm -f "$tmpf"

tmpd="$(mktemp -d)"
( cd "$tmpd" && source "$REPO/io.sh" && download_absent_file "file:///nonexistent-smoke-xyz" out.bin ) 2>/dev/null
status=$?
assert_not_contains "failed download returns nonzero" "status=0" "status=$status"
[[ -e "$tmpd/out.bin" || -e "$tmpd/out.bin.partial" ]] && found=1 || found=0
assert_eq "failed download leaves no file" "0" "$found"
rm -rf "$tmpd"

# --- serializer.sh ---

out="$( (source ./serializer.sh; substitute "" $'name: world\ngreet: "hi ${name}"') 2>/dev/null )"
assert_eq "serializer substitute e2e" $'name: world\ngreet: "hi world"' "$out"

out="$( (source ./serializer.sh; yaml_type <<<'[1,2]') 2>/dev/null )"
assert_eq "yaml_type" "!!seq" "$out"

out="$( (source ./serializer.sh; type printf) 2>/dev/null )"
assert_contains "builtin type not shadowed" "builtin" "$out"

( source ./serializer.sh; is_scalar "world" ) 2>/dev/null
assert_eq "is_scalar scalar" "0" "$?"

( source ./serializer.sh; is_scalar $'a:\n  b: 1' ) 2>/dev/null && s=0 || s=1
assert_eq "is_scalar map" "1" "$s"

( source ./serializer.sh; is_object $'a:\n  b: 1' ) 2>/dev/null
assert_eq "is_object map" "0" "$?"

out="$( (source ./serializer.sh; assign "a.b" "=" "5" $'a:\n  c: 1' | get "a.b") 2>/dev/null )"
assert_eq "assign/get roundtrip" "5" "$out"

# --- gpg.sh (local keyring only; skipped when gpg is absent) ---

if command -v gpg >/dev/null 2>&1; then
  # short path: gpg agent sockets exceed sun_path limits in deep directories
  export GNUPGHOME="$(mktemp -d)"
  chmod 700 "$GNUPGHOME"

  ( source ./gpg.sh; gpg_gen_key "smokepass" RSA 2048 RSA 2048 "Smoke Test" "test" "smoke@example.com" 0 ) >/dev/null 2>&1
  assert_eq "gpg_gen_key with passphrase" "0" "$?"

  ( source ./gpg.sh; gpg_gen_key "" RSA 2048 RSA 2048 "Smoke Two" "" "smoke2@example.com" 0 ) >/dev/null 2>&1
  assert_eq "gpg_gen_key empty passphrase and comment" "0" "$?"

  primaries="$( (source ./gpg.sh; gpg_long_primary_key_list) 2>/dev/null )"
  assert_eq "gpg_long_primary_key_list count" "2" "$(printf '%s\n' "$primaries" | wc -l | tr -d ' ')"

  short_id="$( (source ./gpg.sh; gpg_short_key_list) 2>/dev/null | head -1 )"
  assert_contains "gpg_short_key_list matches a primary fingerprint" "$short_id" "$primaries"

  out="$( (source ./gpg.sh; gpg_export_secret_keys "smokepass") 2>/dev/null )"
  assert_contains "gpg_export_secret_keys armored output" "BEGIN PGP PRIVATE KEY BLOCK" "$out"

  ( source ./gpg.sh; gpg_clean_keys ) >/dev/null 2>&1
  out="$( (source ./gpg.sh; gpg_key_list) 2>/dev/null )"
  assert_eq "gpg_clean_keys empties keyring" "" "$out"

  gpgconf --kill all 2>/dev/null
  rm -rf "$GNUPGHOME"
  unset GNUPGHOME
else
  printf 'skip gpg tests (gpg not installed)\n'
fi

# --- summary ---

if ((failures > 0)); then
  printf '\n%d failure(s)\n' "$failures"
  exit 1
fi

printf '\nall tests passed\n'
