# Handoff: detection-workflow

## What we built

Claude Code hook/permission guardrails for authoring Sigma-style detection
rules in `./rules/`, plus the scripts and tests backing them.

- **`.claude/settings.json`** wires four hook events:
  - `SessionStart` → `scripts/check-prereqs.sh` — verifies `jq` is resolvable before anything else runs.
  - `PreToolUse` (matcher `.*`, every tool call) → `scripts/check-sensitive.sh` — blocks (exit 2) before the tool runs if `tool_input.file_path` matches `.env*`, `*.key`, `*.pem`, `secrets/`, or `credentials/`.
  - `PostToolUse` (matcher `Write|Edit`) → `scripts/validate-rule.sh` — after a rule file is written, checks for `title`, `description`, and an `attack.t*` tag; reports INVALID via stderr if any are missing.
  - `Stop` → `scripts/notify-complete.sh` — logs a timestamped completion notice (with session ID, parsed via `jq`) to stderr.
  - `permissions.deny`/`allow` add a second, independent layer: `Read`/`Edit` on `.env*`/`*.key`/`*.pem`/`secrets/**` are denied outright, and `npm test`/`python -m pytest` are pre-approved without prompting.
- **`scripts/check-sensitive.sh`** checks both `tool_input.file_path` (Write/Edit/Read-style tools, via a case-pattern match) and `tool_input.command` (the `Bash` tool, via a regex match on the raw command text) against `.env*`/`*.key`/`*.pem`/`secrets/`/`credentials/`.
- **`scripts/validate-rule.sh`**, **`scripts/check-prereqs.sh`**, **`scripts/notify-complete.sh`** — along with `check-sensitive.sh`, all four resolve `jq` the same way: `command -v jq` first, then a fallback glob against `$LOCALAPPDATA/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe`. Any script that can't resolve `jq` at all fails closed (exit 2) rather than silently skipping its check.
- **`tests/check-sensitive.test.sh`** — a plain-bash (no framework) test suite: 15 cases covering blocked patterns (including nested `secrets/`/`credentials/` paths), allowed paths, a `monkey.txt`-style false-positive check on the `*.key` pattern, a missing-`file_path` payload, and the block message's content. Exits non-zero on any failure.
- **`rules/test-rule.yml`** — a minimal fixture (`title: Test Rule` only) used to exercise `validate-rule.sh`; it's deliberately INVALID (missing `description` and `tags`) rather than a real detection rule.
- **`README.md`** — hooks table, permissions summary, the shared jq-resolution pattern, and how to run the test suite.

## How to use it

```sh
bash tests/check-sensitive.test.sh              # run the check-sensitive.sh test suite
echo '{"tool_input":{"file_path":"X"}}' | bash scripts/check-sensitive.sh   # manually probe a path
echo '{"tool_input":{"file_path":"rules/test-rule.yml"}}' | bash scripts/validate-rule.sh
```

Verified manually against real Write-tool calls (not just piped simulation):
writing a genuine `.env` file through the Write tool triggered
`check-sensitive.sh` for real and blocked it, confirming the hook works
end-to-end, not just against hand-crafted stdin.

## What's left to do

- **`check-sensitive.sh`'s command-text matching is best-effort, not airtight.** It now also pattern-matches `tool_input.command` for the `Bash` tool (regex: `\.env\b|\.key\b|\.pem\b|\bsecrets/|\bcredentials/`), closing the original gap where `cat secrets/prod.txt` or `cat .env` sailed through unblocked. But it's a plain substring/regex match against raw shell text — quoting tricks, variable expansion, base64/encoding, or building the path piecemeal (`f=".e" "n" "v"; cat "$f"`) can still evade it. `permissions.deny` still only covers the named `Read`/`Edit` tools, not `Bash`.
- **No test suite for `validate-rule.sh`, `check-prereqs.sh`, or `notify-complete.sh`.** Only `check-sensitive.sh` has `tests/check-sensitive.test.sh`; the other three scripts have been exercised manually in-session but have no repeatable regression coverage.
- **`check-prereqs.sh` only checks for `jq`.** Nothing yet verifies `python`/`bash` availability or version, even though `validate-rule.sh` also depends on `python3`/`python` for its YAML parsing.
- **`notify-complete.sh` is stderr-only, local.** It logs a timestamped message but doesn't integrate with Slack, email, or any external notification channel — nothing in this repo currently has credentials/webhooks configured for that.
- **`rules/` has exactly one fixture, and it's intentionally invalid.** There's no real, valid Sigma rule in this repo yet to serve as a positive test case for `validate-rule.sh`.

## Decisions made and why

- **`jq` resolved via PATH-then-WinGet-fallback, not assumed to be on PATH.** `jq` was already installed via `winget` on this machine, and the user registry `PATH` already included its install directory — but the running shell session (and hook subprocess) started before that took effect, so `jq` silently resolved to nothing and the very first version of `validate-rule.sh` no-op'd on every rule file without any visible error. Rather than depend on a session/shell restart, every script now checks `command -v jq` first and falls back to globbing the known WinGet packages directory, then fails closed (exit 2) with a clear stderr message if `jq` truly can't be found — so a broken environment is loud, not silent.
- **`check-sensitive.sh` moved from `PostToolUse` to `PreToolUse` (matcher `.*`).** The user's own proposed config made this change; it matters because `PostToolUse` can only report after a tool has already run (the file is already written), whereas `PreToolUse` exit-2 genuinely vetoes the call before it happens.
- **`permissions.deniedPaths`/`allowedCommands`/`costThreshold` from an early draft config were rejected, not written verbatim.** They read like plausible settings.json keys but aren't real ones — verified against actual Claude Code documentation (via the `claude-code-guide` agent) before writing anything, since silently writing dead config keys would have recreated the exact "looks protected but isn't" problem the `jq` fix was solving. Replaced with the real `permissions.allow`/`deny` arrays using `Tool(specifier)` syntax; `costThreshold` was dropped entirely since Claude Code has no built-in cost/budget-enforcement mechanism.
- **Hook commands use `bash scripts/x.sh`, not `./scripts/x.sh`.** The user's draft config used the latter; changed for consistency with the pre-existing hooks in this file and because relative self-exec depends on the file's executable bit and shebang resolving correctly, which is exactly the class of thing that fails quietly on this Windows/git-bash setup.
- **`check-prereqs.sh`/`notify-complete.sh` started as harmless `exit 0` stubs, then were fleshed out on request** rather than being fully implemented speculatively up front — avoided guessing at scope (e.g. inventing a Slack integration) before it was asked for.
- **Test suite is plain bash, not `bats` or another framework.** No test framework was already present in this repo or the wider `ai-defense-labs` umbrella, and the assertions needed (piping JSON to a script, checking its exit code and stderr) are simple enough that a framework dependency wasn't justified.
