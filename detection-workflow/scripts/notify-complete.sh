#!/usr/bin/env bash
# Stop hook: surface a completion notice back to the user.

if command -v jq >/dev/null 2>&1; then
  JQ=jq
else
  JQ=$(ls "$LOCALAPPDATA"/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe 2>/dev/null | head -n1)
fi

input=$(cat)

if [[ -n "$JQ" ]]; then
  session_id=$(echo "$input" | "$JQ" -r '.session_id // empty')
else
  session_id=""
fi

if [[ -n "$session_id" ]]; then
  echo "notify-complete: session $session_id finished at $(date '+%Y-%m-%d %H:%M:%S')" >&2
else
  echo "notify-complete: session finished at $(date '+%Y-%m-%d %H:%M:%S')" >&2
fi

exit 0
