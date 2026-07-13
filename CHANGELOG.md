# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-07-06

First versioned release: full audit, test suite, tooling, and CI.

### Added
- `scripts.sh` umbrella entry point exposing `SCRIPTS_VERSION`.
- bats-core test suite (130+ tests, one file per module) with hermetic gpg
  keyrings, `file://` download fixtures, and opt-in network tests.
- `Makefile`: `test`, `test-linux` (pinned Debian container), `test-windows`,
  `test-network`, `lint`, `fmt`/`fmt-check` (shfmt), `coverage` (kcov),
  `bench`, `hooks`, `check`.
- GitHub Actions CI: shellcheck + shfmt, test matrix (Linux, macOS,
  Windows/Git Bash), kcov coverage artifact.
- Bash >= 4.4 guard in every module with a clear failure message.
- Include guards: modules are idempotent under repeated sourcing.
- Recursion depth cap (`SUBSTITUTE_MAX_DEPTH`, 32) — self-referential
  templates now fail cleanly instead of fork-storming.
- UTF-8-aware tokenizer: multibyte templates and patterns match as
  characters, not bytes; token-stream integrity guards abort loudly on a
  failed or corrupt tokenizer run instead of emitting empty output.
- `get_raw` — reads raw string content at a path (vs. `get`'s representation).
- Runnable examples under `examples/`, executed by the suite.
- bpkg `package.json`, `.editorconfig`, git hooks under `.githooks/`.

### Changed
- **Breaking:** `type` → `yaml_type` so sourcing the library no longer
  shadows the bash builtin. The other document verbs keep their short names
  by design; the toolkit is format-agnostic (YAML and JSON alike).
- Substitution operates on raw string content and assigns back via yq's
  `strenv`: JSON documents, quoted and multiline strings substitute
  correctly, substituted fields keep their string type, and whole
  maps/arrays interpolate into strings as YAML text.
- **Breaking:** `gpg_secret_key_list` → `gpg_export_secret_keys` (it exports
  private key material); passphrase now passes via stdin fd, not the process
  command line. `is_gpg_key_exported` / `gpg_export_key` take the key first.
- Template engine rewritten around a single-pass perl tokenizer
  (one process per string instead of several per token; ~2x faster end to
  end, dominated now by yq).
- `timestamp` uses bash's builtin strftime (no `date` fork per log line).
- Progress/diagnostic messages consistently go to stderr; xclip/xsel target
  the CLIPBOARD selection; `download_absent_file` downloads atomically with
  `curl -f` and never caches error pages.

### Fixed
- Env interpolation resolved to the key name instead of its value
  (`${HOME}` → `HOME`) — default getter now honors the getter protocol.
- Unbraced interpolation swallowed following words into the lookup path
  (`$VER. Done` lost `. Done`).
- Option parsing looped forever on a missing option value and leaked
  "Unknown option" into captured output.
- `is_gpg_key_exported` relied on non-POSIX `grep -qv` semantics (and later,
  on exit codes that batch-mode search does not provide) — detection now uses
  `--with-colons` machine output.
- `gpg_gen_key` never worked against gpg 2.x (parameter block must start
  with `Key-Type`; empty passphrase/comment values are rejected).
- `ensure_cmd` called an undefined `die`; unresolved-value failures inside
  recursive substitution were silently swallowed; structured values
  interpolated into strings now fail with a clear error instead of silently
  emptying the document.
- `VERBOSE=true` silenced logging (arithmetic coercion); `user_input`'s
  unguarded `shift 3`; `join_to_string` echoing away option-like values;
  single-quoted escape handling in `$<...>` expressions; unterminated `$<`
  emitting garbled output; `${""}` crashing on an empty cache subscript;
  Cygwin hosts path; CRLF hosts-file duplicate appends.

### Removed
- `tests/smoke.sh` (superseded by the bats suite).
- Dead block-scalar strip in `yml_assign`/`yml_assign_in_file`.

[1.0.0]: https://github.com/azevio/scripts/releases/tag/v1.0.0
