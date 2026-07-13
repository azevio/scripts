# scripts

[![CI](https://github.com/azevio/scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/azevio/scripts/actions/workflows/ci.yml)

A modular bash utility library: ANSI helpers, logging, IO, networking, GPG
automation, and a yq-backed YAML toolkit with a template engine
(`${placeholders}`, defaults, and `$<evaluated expressions>`).

## Requirements

- **bash >= 4.4** (namerefs, `mapfile -d`) — every module fails fast with a
  clear message on older shells. On macOS use `brew install bash`; stock
  `/bin/bash` 3.2 is not supported.
- `perl` >= 5.26 (template tokenizer) and, for the YAML toolkit, `yq` (mikefarah, v4)
  and `jq`.
- `curl` for `download_absent_file` / `get_ip`; `gpg` only for `gpg.sh`.

## Install

```bash
git clone https://github.com/azevio/scripts.git
# or, with bpkg:
bpkg install azevio/scripts
```

## Usage

Source the umbrella entry point, or any module on its own — modules source
their own dependencies and are idempotent under repeated sourcing:

```bash
source /path/to/scripts/scripts.sh   # everything (defines SCRIPTS_VERSION)
source /path/to/scripts/string.sh    # just the string/template module
```

Runnable examples live in [`examples/`](examples) and are executed as part of
the test suite:

```bash
examples/render-config.sh    # config decoding with imports + placeholders
examples/greet-template.sh   # inline template against the environment
```

## Modules

| Module | Provides |
|---|---|
| `ansi.sh` | `ansi_span` — print spans with automatic ANSI reset |
| `time.sh` | `timestamp` — fork-free `YYYY-MM-DD HH:MM:SS` |
| `log.sh` | `info` / `warn` / `error` / `check` (stderr, `VERBOSE`/`COLOR` aware) |
| `env.sh` | `os_name`, `arch_name`, `ensure_cmd`, `bash_env`, `bash_c` |
| `array.sh` | `join_to_string` |
| `io.sh` | `src`, `clipboard`, `file_hash_sha256`, `download_absent_file`, `user_input` |
| `string.sh` | `trim*`, `escape`, `halve`, `match_at`, `match_groups_at`, **`substitute_string`** |
| `net.sh` | `get_ip`, `hosts_set` |
| `gpg.sh` | key generation, listings, secret export, keyserver publish |
| `serializer.sh` | the YAML/JSON toolkit (`get`, `assign`, `merge`, …) and **`substitute`** / **`decode_file`** |

## Template language

`substitute_string` (strings) and `substitute` / `decode_file`
(YAML/JSON documents) share one grammar; templates may contain any UTF-8 text:

| Syntax | Meaning |
|---|---|
| `${key}` | interpolate a value; nested paths as `${a.b}`, indexes as `${a.[0]}`, quoted keys as `${"a b"}` |
| `${KEY-default}` | default value when the key is unset (mirrors `${VAR-default}`) |
| `$key.path` | unbraced form (opt-in via `-i true`); keys chain only through dots followed by another key |
| `$<command>` | evaluate through bash (`bash_c`: `set -euo pipefail`); quotes protect `<` and `>`; `$<var a.b>` reads values inside evaluated expressions |
| `$$` | escaped dollar; runs are halved unless `-ud false` |

Options (both functions): `-i/--interpolate`, `-ib/--interpolate-braced`,
`-e/--evaluate`, `-ud/--unescape-dollars`, each taking an explicit
`true`/`false` value.

**Getter protocol.** `substitute_string [opts] [getter] [evaluator] [cache] [source]`
calls the getter with the *name of an array* holding the key path. Status
codes: `0` = resolved (stdout is the value), `101`/`NO_SUCH_ELEMENT` = keep
the raw placeholder (propagated as the final exit status), `100`/`DEEP_RESOLVE`
= the returned value itself must be substituted recursively (depth-capped by
`SUBSTITUTE_MAX_DEPTH`, default 32). Any other status aborts. The default
getter is `bash_env` (environment lookups), the default evaluator `bash_c`.

`decode_file` renders a document after recursively merging its `imports:`
(relative to each file), deduplicating shared imports, and detecting cycles;
the import tree is drawn on stderr.

Substituted values are handled as raw string content and written back with
yq's `strenv` — so quoted (JSON) and multiline strings substitute safely, a
substituted field always stays a string, and interpolating a whole map/array
into a string embeds it as YAML text.

## Document toolkit

The toolkit is format-agnostic across what yq parses — YAML and JSON in the
same functions: `yaml_type`, `is_type`, `is_bool`/`is_int`/`is_float`/`is_str`/
`is_scalar`/`is_seq`/`is_map`/`is_object`, `uncomment`, `pretty_yaml`,
`pretty_yaml_objects`, `coalesce`, `contains`, `get`, `get_raw`, `assign`,
`slice`, `replace`, `delete`, `deletes`, `merge`, plus `*_in_file` variants,
`merge_files`, `substitute`, and `decode_file`. Paths are yq expressions;
sources may be a literal string, a file name, or stdin (see `src`).

## Platform support

| Platform | Status |
|---|---|
| Linux | Tested in CI and via `make test-linux` (pinned Debian container) |
| macOS | Tested in CI and locally (homebrew bash) |
| Windows | Via Git Bash or WSL only — tested in CI on `windows-latest`; the process-heavy template engine is noticeably slower there |

## Development

```bash
make help          # list all targets
make test          # bats suite (tests/*.bats)
make test-linux    # same suite in the pinned Debian container
make check         # fmt-check + shellcheck + tests
make fmt           # shfmt -i 2
make coverage      # informational kcov report into ./coverage (container)
make bench         # time template rendering (ITERATIONS=n)
make hooks         # install .githooks (fmt-check + lint on commit)
make test-network  # include opt-in keyserver tests
```

Tests are [bats-core](https://github.com/bats-core/bats-core); one file per
module under `tests/`, shared helpers in `tests/helpers/common.bash`. Tests
are hermetic: gpg uses throwaway keyrings, downloads use `file://` fixtures,
and network-dependent keyserver tests skip unless `RUN_NETWORK_TESTS=1`.

## Design notes & caveats

- `error` **exits the current shell** (by design, it is the library's `die`);
  when a function is called inside `$(...)`, only that subshell exits.
- The `101`/`100` status protocol conflicts with `set -e` in *callers*:
  capture results as `out="$(substitute ...)"` inside an `if`/`||` context.
- Interpolating a whole map/array into a string embeds it as YAML *text*
  (the field stays a string); merge structures via `imports:`/`merge` instead.
- The library deliberately uses short unprefixed names (`get`, `merge`,
  `substitute`, `info`, `src`, …). Source it in scripts rather than in
  interactive shells if that concerns you; only `yaml_type` deviates, to
  avoid shadowing the `type` builtin.

## Versioning

Semantic versioning; see [CHANGELOG.md](CHANGELOG.md). The current version is
exposed as `SCRIPTS_VERSION` by `scripts.sh`.

## License

[MIT](LICENSE)
