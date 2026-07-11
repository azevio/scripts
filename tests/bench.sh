#!/usr/bin/env bash
# Benchmarks template rendering end to end. Usage: tests/bench.sh [iterations]
set -euo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
source ./serializer.sh

iterations="${1:-10}"

doc=$'a: 1\nb: "x ${a} y"\nc: "eval $<printf %s hi> and ${a}"\nlist:\n  - "item ${a}"\n  - "plain text"\nd: "many ${a} ${a} tokens $$ESCAPED"'

render() {
  local i
  for ((i = 0; i < iterations; i++)); do
    substitute "" "$doc" </dev/null >/dev/null
  done
}

printf 'rendering %s iterations of a 6-token template\n' "$iterations" >&2
TIMEFORMAT='real %3R s (%3U user, %3S sys)'
time render
