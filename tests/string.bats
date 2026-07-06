#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load 'helpers/common'
  load_lib string.sh
}

# --- plain string helpers ---

@test "is_blank accepts whitespace-only input" {
  run is_blank "   "
  [ "$status" -eq 0 ]
}

@test "is_blank rejects non-blank input" {
  run is_blank " a "
  [ "$status" -eq 1 ]
}

@test "trim_start strips a matching prefix" {
  run trim_start "x" "xhello"
  [ "$output" = "hello" ]
}

@test "trim_start leaves non-matching input alone" {
  run trim_start "x" "hello"
  [ "$output" = "hello" ]
}

@test "trim strips both ends" {
  run trim "x" "xhellox"
  [ "$output" = "hello" ]
}

@test "escape quotes shell metacharacters" {
  run escape "a b"
  [ "$output" = 'a\ b' ]
}

@test "halve keeps the first half (floor) of the input" {
  run halve "abcd"
  [ "$output" = "ab" ]
  run halve "abc"
  [ "$output" = "a" ]
}

# --- matchers ---

@test "match_at returns full match and groups as JSON" {
  run match_at '(a)(b)' 0 "abc"
  [ "$output" = '{"groupValues":["ab","a","b"]}' ]
}

@test "match_at returns empty groupValues on no match" {
  run match_at 'z' 0 "abc"
  [ "$output" = '{"groupValues":[]}' ]
}

@test "match_at anchors at the given index" {
  run match_at 'b' 1 "ab"
  [ "$output" = '{"groupValues":["b"]}' ]
}

@test "match_groups_at fills the array with match and groups" {
  wrapped() {
    local g=()
    match_groups_at g '(a)(b)' 0 "abc"
    printf '%s|%s|%s' "${g[0]}" "${g[1]}" "${g[2]}"
  }
  run wrapped
  [ "$output" = "ab|a|b" ]
}

@test "match_groups_at leaves the array empty on no match" {
  wrapped() {
    local g=(stale)
    match_groups_at g 'z' 0 "abc"
    printf '%d' "${#g[@]}"
  }
  run wrapped
  [ "$output" = "0" ]
}

@test "match_groups_at preserves newlines inside groups" {
  wrapped() {
    local g=()
    match_groups_at g '(?s)(a.*d)' 0 $'ab\ncd'
    printf '%s' "${g[1]}"
  }
  run wrapped
  [ "$output" = $'ab\ncd' ]
}

@test "single-quoted pattern matches escape sequences" {
  run match_at "$SINGLE_QUOTED_STRING_PATTERN" 0 $'\'a\\nb\''
  [[ "$output" != '{"groupValues":[]}' ]]
}

# --- braced interpolation ---

@test "substitute_string resolves \${VAR} from the environment" {
  sub() { substitute_string -e false <<<'home=${HOME} end'; }
  run sub
  [ "$status" -eq 0 ]
  [ "$output" = "home=$HOME end" ]
}

@test "substitute_string resolves \${VAR-default} when unset" {
  sub() { unset MISSING_BATS_VAR; substitute_string -e false <<<'${MISSING_BATS_VAR-dflt}'; }
  run sub
  [ "$output" = "dflt" ]
}

@test "substitute_string keeps unresolved keys raw with status 101" {
  sub() { unset MISSING_BATS_VAR; substitute_string -e false <<<'${MISSING_BATS_VAR}'; }
  run sub
  [ "$status" -eq 101 ]
  [ "$output" = '${MISSING_BATS_VAR}' ]
}

@test "substitute_string tolerates spaces inside braces" {
  sub() { substitute_string -e false <<<'v=${ HOME }'; }
  run sub
  [ "$output" = "v=$HOME" ]
}

@test "substitute_string resolves adjacent placeholders" {
  sub() { A_BATS=1 B_BATS=2 substitute_string -e false <<<'${A_BATS}${B_BATS}'; }
  run sub
  [ "$output" = "12" ]
}

@test "substitute_string dies on a missing closing brace" {
  sub() { substitute_string -e false <<<'${HOME'; }
  run sub
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing }"* ]]
}

@test "substitute_string dies on an empty \${}" {
  sub() { substitute_string -e false <<<'${}'; }
  run sub
  [ "$status" -eq 1 ]
  [[ "$output" == *"Empty interpolate"* ]]
}

@test "substitute_string with -ib false leaves braced placeholders alone" {
  sub() { substitute_string -ib false -e false <<<'v=${HOME}'; }
  run sub
  [ "$status" -eq 0 ]
  [ "$output" = 'v=${HOME}' ]
}

# --- dollar escaping ---

@test "substitute_string halves runs of double dollars by default" {
  sub() { substitute_string -e false <<<'cost $$HOME'; }
  run sub
  [ "$output" = 'cost $HOME' ]
}

@test "substitute_string keeps double dollars with -ud false" {
  sub() { substitute_string -ud false -e false <<<'cost $$HOME'; }
  run sub
  [ "$output" = 'cost $$HOME' ]
}

@test "substitute_string emits a lone trailing dollar literally" {
  sub() { substitute_string -e false <<<'end $'; }
  run sub
  [ "$status" -eq 0 ]
  [ "$output" = 'end $' ]
}

# --- unbraced interpolation ---

@test "unbraced \$VAR resolves when -i true" {
  sub() { substitute_string -i true -e false <<<'v=$HOME end'; }
  run sub
  [ "$output" = "v=$HOME end" ]
}

@test "unbraced interpolation stops at a dot boundary" {
  sub() { substitute_string -i true -e false <<<'v=$HOME. Done'; }
  run sub
  [ "$output" = "v=$HOME. Done" ]
}

@test "unbraced interpolation keeps a trailing dot" {
  sub() { substitute_string -i true -e false <<<'v=$HOME.'; }
  run sub
  [ "$output" = "v=$HOME." ]
}

@test "unbraced keys chain through dots for structured getters" {
  joined_getter() {
    local -n __k="$1"
    printf '<%s>' "${__k[*]}"
  }
  sub() { substitute_string -i true -e false joined_getter <<<'$a.b done'; }
  run sub
  [ "$output" = "<a b> done" ]
}

@test "quoted keys may contain spaces" {
  joined_getter() {
    local -n __k="$1"
    printf '<%s>' "${__k[*]}"
  }
  sub() { substitute_string -e false joined_getter <<<'${"a b"}'; }
  run sub
  [ "$output" = "<a b>" ]
}

@test "index keys are captured without brackets" {
  joined_getter() {
    local -n __k="$1"
    printf '<%s>' "${__k[*]}"
  }
  sub() { substitute_string -e false joined_getter <<<'${x.[0]}'; }
  run sub
  [ "$output" = "<x 0>" ]
}

# --- getter protocol ---

@test "getter results are cached per path" {
  counting_getter() {
    echo call >>"$BATS_TEST_TMPDIR/count"
    printf 'V'
  }
  sub() { substitute_string -e false counting_getter <<<'${k} ${k}'; }
  run sub
  [ "$output" = "V V" ]
  [ "$(wc -l <"$BATS_TEST_TMPDIR/count")" -eq 1 ]
}

@test "a DEEP_RESOLVE getter result is substituted recursively" {
  deepish_getter() {
    local -n __k="$1"
    case "${__k[0]}" in
    outer) printf 'x=${leaf}'; return "$DEEP_RESOLVE" ;;
    leaf) printf 'L' ;;
    *) return "$NO_SUCH_ELEMENT" ;;
    esac
  }
  sub() { substitute_string -e false deepish_getter <<<'${outer}'; }
  run sub
  [ "$status" -eq 0 ]
  [ "$output" = "x=L" ]
}

@test "an unexpected getter status aborts with an error" {
  bad_getter() { return 3; }
  sub() { substitute_string -e false bad_getter <<<'${k}'; }
  run sub
  [ "$status" -eq 3 ]
  [[ "$output" == *"Interpolate braced"* ]]
}

# --- evaluation ---

@test "\$<...> evaluates through bash" {
  sub() { substitute_string <<<'n=$<printf %s 42>'; }
  run sub
  [ "$output" = "n=42" ]
}

@test "evaluation respects > inside double quotes" {
  sub() { substitute_string <<<'r=$<printf %s "a>b">'; }
  run sub
  [ "$output" = "r=a>b" ]
}

@test "evaluation respects escapes inside single quotes" {
  sub() { substitute_string <<<"x=\$<printf %s 'a\\nb'>"; }
  run sub
  [ "$output" = 'x=a\nb' ]
}

@test "an unterminated \$< aborts without emitting partial output" {
  sub() { substitute_string <<<'a $<echo hi'; }
  run --separate-stderr sub
  [ "$status" -ne 0 ]
  [ "$output" = "" ]
}

@test "an evaluator returning NO_SUCH_ELEMENT keeps the raw expression" {
  nse_evaluator() { return "$NO_SUCH_ELEMENT"; }
  sub() { substitute_string bash_env nse_evaluator <<<'k $<echo x> t'; }
  run sub
  [ "$status" -eq 101 ]
  [ "$output" = 'k $<echo x> t' ]
}

@test "a failing evaluated script aborts with its status" {
  sub() { substitute_string <<<'k $<exit 9>'; }
  run sub
  [ "$status" -eq 9 ]
  [[ "$output" == *"Evaluate"* ]]
}

# --- option handling ---

@test "unknown options go to stderr, not into the output" {
  sub() { substitute_string -zz -e false <<<'plain'; }
  run --separate-stderr sub
  [ "$output" = "plain" ]
  [[ "$stderr" == *"Unknown option -zz"* ]]
}

@test "a missing option value terminates instead of looping" {
  sub() { substitute_string -i <<<'x'; }
  run sub
  [ "$status" -eq 0 ]
  [ "$output" = "x" ]
}
