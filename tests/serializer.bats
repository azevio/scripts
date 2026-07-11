#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load 'helpers/common'
  require_cmd yq jq perl
  load_lib serializer.sh
}

# --- type inspection ---

@test "yaml_type reports YAML tags" {
  run yaml_type "[1,2]"
  [ "$output" = "!!seq" ]
}

@test "the bash builtin type is not shadowed" {
  run type printf
  [[ "$output" == *"builtin"* ]]
}

@test "is_bool / is_int / is_float / is_str discriminate scalars" {
  is_bool "true"
  is_int "1"
  is_float "1.5"
  is_str "hello"
  run is_bool "1"
  [ "$status" -eq 1 ]
  run is_int "hello"
  [ "$status" -eq 1 ]
}

@test "is_scalar accepts scalars and rejects null and objects" {
  is_scalar "world"
  is_scalar "42"
  run is_scalar ""
  [ "$status" -eq 1 ]
  run is_scalar $'a:\n  b: 1'
  [ "$status" -eq 1 ]
}

@test "is_seq / is_map / is_object discriminate objects" {
  is_seq "[1]"
  is_map "a: 1"
  is_object "[1]"
  is_object "a: 1"
  run is_object "scalar"
  [ "$status" -eq 1 ]
}

# --- document helpers ---

@test "uncomment strips comments" {
  run uncomment "a: 1 # note"
  [ "$output" = "a: 1" ]
}

@test "pretty_yaml converts JSON to YAML" {
  run pretty_yaml '{"a":1}'
  [ "$output" = "a: 1" ]
}

@test "coalesce replaces null with the default" {
  run coalesce 5 "null"
  [ "$output" = "5" ]
}

@test "contains reports present and absent paths" {
  contains "a.b" $'a:\n  b: 1'
  run contains "a.z" $'a:\n  b: 1'
  [ "$status" -eq 1 ]
}

@test "get reads nested values" {
  run get "a.b" $'a:\n  b: 5'
  [ "$output" = "5" ]
}

@test "assign writes a nested value" {
  wrapped() { assign "a.b" "=" "5" $'a:\n  c: 1' | get "a.b"; }
  run wrapped
  [ "$output" = "5" ]
}

@test "assign into an empty document creates it" {
  wrapped() { assign "x" "=" "5" "" </dev/null | get "x"; }
  run wrapped
  [ "$output" = "5" ]
}

@test "assign round-trips block-scalar values" {
  wrapped() { assign "x" "=" "$(printf '|-\n  hello')" "a: 0" | yq -r '.x'; }
  run wrapped
  [ "$output" = "hello" ]
}

@test "slice keeps only the requested paths" {
  wrapped() {
    local p=(a c)
    slice p $'a: 1\nb: 2\nc: 3' | yq -r 'keys | join(",")'
  }
  run wrapped
  [ "$output" = "a,c" ]
}

@test "replace moves a value to a new path" {
  wrapped() { replace "b" "=" "a" "a: 1" | yq -r 'keys | join(",")'; }
  run wrapped
  [ "$output" = "b" ]
}

@test "delete removes a path" {
  wrapped() { delete "a" $'a: 1\nb: 2' | yq -r 'keys | join(",")'; }
  run wrapped
  [ "$output" = "b" ]
}

@test "deletes removes several paths" {
  wrapped() {
    local p=(a c)
    deletes p $'a: 1\nb: 2\nc: 3' | yq -r 'keys | join(",")'
  }
  run wrapped
  [ "$output" = "b" ]
}

@test "merge combines documents, right side winning" {
  wrapped() {
    local docs=("a: 1" $'a: 2\nb: 9')
    merge docs | yq -r '.a, .b'
  }
  run wrapped
  [ "${lines[0]}" = "2" ]
  [ "${lines[1]}" = "9" ]
}

# --- in-file variants ---

@test "assign_in_file / slice_in_file / deletes_in_file / replace_in_file / delete_in_file edit in place" {
  local f="$BATS_TEST_TMPDIR/f.yaml"
  printf 'a: 1\nb: 2\nc: 3\n' >"$f"

  assign_in_file "x.y" "=" "9" "$f"
  [ "$(yq -r '.x.y' "$f")" = "9" ]

  local keep=(a c x)
  slice_in_file keep "$f"
  [ "$(yq -r 'keys | join(",")' "$f")" = "a,c,x" ]

  local drop=(x)
  deletes_in_file drop "$f"
  [ "$(yq -r 'keys | join(",")' "$f")" = "a,c" ]

  replace_in_file "renamed" "=" "a" "$f"
  [ "$(yq -r 'keys | join(",")' "$f")" = "c,renamed" ]

  delete_in_file "renamed" "$f"
  [ "$(yq -r 'keys | join(",")' "$f")" = "c" ]
}

@test "merge_files combines files" {
  printf 'a: 1\n' >"$BATS_TEST_TMPDIR/m1.yaml"
  printf 'b: 2\n' >"$BATS_TEST_TMPDIR/m2.yaml"
  wrapped() {
    local fs=("$BATS_TEST_TMPDIR/m1.yaml" "$BATS_TEST_TMPDIR/m2.yaml")
    merge_files fs | yq -r 'keys | join(",")'
  }
  run wrapped
  [ "$output" = "a,b" ]
}

# --- substitute ---

@test "substitute resolves placeholders against the document itself" {
  wrapped() { substitute "" $'name: world\ngreet: "hi ${name}"' </dev/null | yq -r '.greet'; }
  run wrapped
  [ "$status" -eq 0 ]
  [ "$output" = "hi world" ]
}

@test "substitute works on JSON documents" {
  wrapped() { substitute "" '{"name":"world","greet":"hi ${name}"}' </dev/null | yq -r '.greet'; }
  run wrapped
  [ "$status" -eq 0 ]
  [ "$output" = "hi world" ]
}

@test "substitute keeps multibyte content intact" {
  wrapped() { substitute "" $'name: wörld\ngreet: "héllo ${name} ✓"' </dev/null | yq -r '.greet'; }
  run wrapped
  [ "$output" = "héllo wörld ✓" ]
}

@test "substituted values keep their string type" {
  wrapped() { substitute "port: 8080" $'x: "${port}"' </dev/null | yq '.x | tag'; }
  run wrapped
  [ "$output" = "!!str" ]
}

@test "structured values interpolate into strings as YAML text" {
  wrapped() { substitute "" $'m:\n  q: "${x}"\nx: 2\ns: "${m}"' </dev/null | yq -r '.s' | yq -r '.q'; }
  run wrapped
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "substitute resolves placeholders against an explicit values document" {
  wrapped() { substitute "port: 8080" $'x: "p=${port}"' </dev/null | yq -r '.x'; }
  run wrapped
  [ "$output" = "p=8080" ]
}

@test "substitute -i true resolves unbraced nested paths" {
  wrapped() { substitute -i true "" $'x:\n  y: 1\nz: "$x.y"' </dev/null | yq -r '.z'; }
  run wrapped
  [ "$output" = "1" ]
}

@test "substitute evaluates \$<var path> expressions" {
  wrapped() { substitute "" $'x: 5\ny: "$<var x>"' </dev/null | yq -r '.y'; }
  run wrapped
  [ "$output" = "5" ]
}

@test "substitute keeps unknown options out of the document" {
  wrapped() { substitute -zz "" "a: 1" </dev/null; }
  run --separate-stderr wrapped
  [ "$output" = "a: 1" ]
  [[ "$stderr" == *"Unknown option -zz"* ]]
}

# --- decode_file ---

@test "decode_file merges imports and substitutes across them" {
  printf 'name: base\nport: 8080\n' >"$BATS_TEST_TMPDIR/base.yaml"
  printf 'imports:\n  - base.yaml\napp: "on ${port}"\n' >"$BATS_TEST_TMPDIR/app.yaml"
  wrapped() { decode_file "$BATS_TEST_TMPDIR/app.yaml" </dev/null; }
  run --separate-stderr wrapped
  [ "$status" -eq 0 ]
  [ "$(yq -r '.app' <<<"$output")" = "on 8080" ]
  [ "$(yq -r '.port' <<<"$output")" = "8080" ]
  [[ "$stderr" == *"File:"* ]]
}

@test "decode_file deduplicates diamond imports" {
  printf 'v: 1\n' >"$BATS_TEST_TMPDIR/base.yaml"
  printf 'imports: [base.yaml]\nka: "${v}"\n' >"$BATS_TEST_TMPDIR/a.yaml"
  printf 'imports: [base.yaml]\nkb: 2\n' >"$BATS_TEST_TMPDIR/b.yaml"
  printf 'imports: [a.yaml, b.yaml]\nkc: 3\n' >"$BATS_TEST_TMPDIR/c.yaml"
  wrapped() { decode_file "$BATS_TEST_TMPDIR/c.yaml" </dev/null; }
  run --separate-stderr wrapped
  [ "$status" -eq 0 ]
  [ "$(yq -r '.ka' <<<"$output")" = "1" ]
  [ "$(yq -r '.kc' <<<"$output")" = "3" ]
  [[ "$stderr" == *"↑"* ]]
}

@test "decode_file detects import cycles" {
  printf 'imports: [b.yaml]\nka: 1\n' >"$BATS_TEST_TMPDIR/a.yaml"
  printf 'imports: [a.yaml]\nkb: 2\n' >"$BATS_TEST_TMPDIR/b.yaml"
  wrapped() { decode_file "$BATS_TEST_TMPDIR/a.yaml" </dev/null; }
  run wrapped
  [ "$status" -ne 0 ]
  [[ "$output" == *"Detected cycle"* ]]
}
