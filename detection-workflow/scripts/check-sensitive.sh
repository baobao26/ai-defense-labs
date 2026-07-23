#!/usr/bin/env bash

if command -v jq >/dev/null 2>&1; then
  JQ=jq
else
  JQ=$(ls "$LOCALAPPDATA"/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe 2>/dev/null | head -n1)
fi
if [[ -z "$JQ" ]]; then
  echo "check-sensitive: jq not found on PATH or in WinGet packages" >&2
  exit 2
fi

input=$(cat)
file_path=$(echo "$input" | "$JQ" -r '.tool_input.file_path // empty')
command_text=$(echo "$input" | "$JQ" -r '.tool_input.command // empty')

if [[ -n "$file_path" ]]; then
  case "$file_path" in
    *.env|.env|*/.env|*.key|*.pem|secrets/*|*/secrets/*|credentials/*|*/credentials/*)
      echo "check-sensitive: blocked write to sensitive path: $file_path" >&2
      exit 2
      ;;
  esac
fi

# Bash tool_input has no file_path, only a raw command string — pattern-match
# it directly. Best-effort: arbitrary shell syntax (quoting, variables,
# encoding) can still evade this.
SENSITIVE_RE='\.env\b|\.key\b|\.pem\b|\bsecrets/|\bcredentials/'
if [[ -n "$command_text" ]] && echo "$command_text" | grep -Eiq "$SENSITIVE_RE"; then
  echo "check-sensitive: blocked command referencing a sensitive path: $command_text" >&2
  exit 2
fi

exit 0
