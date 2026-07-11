#!/usr/bin/env bash
# Renders an inline template against environment variables, with a default.
set -euo pipefail

dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$dir/../string.sh"

substitute_string -e false <<<'Hello ${USER-stranger}, home is ${HOME}'
echo
