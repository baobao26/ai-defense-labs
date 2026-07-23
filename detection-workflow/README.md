# detection-workflow

Sigma-style detection rule authoring, guarded by Claude Code hooks and permissions.

## Layout

- `rules/` — Sigma-style rule files (`.yml`/`.yaml`). Each must have a `title`, a
  `description`, and a `tags` list containing at least one `attack.t*` entry.
- `scripts/` — hook scripts wired into `.claude/settings.json`.
- `tests/` — plain-bash test suites for the scripts (no external test framework).

## Hooks (`.claude/settings.json`)

| Event | Script | Purpose |
|---|---|---|
| `SessionStart` | `check-prereqs.sh` | Verifies `jq` is resolvable (PATH or WinGet packages dir). Fails closed (exit 2) if missing, since the other hooks depend on it. |
| `PreToolUse` (`.*`) | `check-sensitive.sh` | Blocks (exit 2) any tool call touching `.env*`, `*.key`, `*.pem`, `secrets/`, or `credentials/` — via `tool_input.file_path` for Write/Edit/Read-style tools, or a regex match on `tool_input.command` for `Bash` — before the tool runs. |
| `PostToolUse` (`Write\|Edit`) | `validate-rule.sh` | After a write/edit under `rules/*.yml`/`*.yaml`, checks for `title`, `description`, and an `attack.t*` tag; reports INVALID via stderr if any are missing. |
| `Stop` | `notify-complete.sh` | Logs a timestamped completion notice (with session ID) to stderr when the session ends. |

All scripts read the tool payload as JSON from stdin and resolve `jq` the same
way: try `command -v jq` first, then fall back to
`$LOCALAPPDATA/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe`. If neither
resolves, the script fails closed (exit 2) rather than silently skipping
validation.

## Permissions (`.claude/settings.json`)

- `deny`: blocks `Read`/`Edit` on `.env*`, `*.key`, `*.pem`, and `secrets/**` —
  defense-in-depth alongside the `check-sensitive.sh` hook.
- `allow`: pre-approves `npm test` and `python -m pytest` without prompting.

## Tests

```sh
bash tests/check-sensitive.test.sh
```

Runs `check-sensitive.sh` against blocked and allowed paths, a missing
`file_path` payload, and the block-message content, printing PASS/FAIL per
case and exiting non-zero if anything fails.
