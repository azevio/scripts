#!/usr/bin/env bash
# Renders examples/config/app.yaml with its imports merged and all
# placeholders and $<...> expressions resolved.
set -euo pipefail

dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$dir/../scripts.sh"

decode_file "$dir/config/app.yaml"
