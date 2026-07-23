#!/usr/bin/env bash
# SessionStart hook: verify prerequisites the other hooks depend on.

if command -v jq >/dev/null 2>&1; then
  JQ=jq
else
  JQ=$(ls "$LOCALAPPDATA"/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe 2>/dev/null | head -n1)
fi

if [[ -z "$JQ" ]]; then
  echo "check-prereqs: jq not found on PATH or in WinGet packages — hooks that parse tool_input (validate-rule.sh, check-sensitive.sh) will fail closed" >&2
  exit 2
fi

exit 0
