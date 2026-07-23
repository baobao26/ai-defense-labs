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

if [[ -z "$file_path" ]]; then
  exit 0
fi

case "$file_path" in
  *.env|.env|*/.env|*.key|*.pem|secrets/*|*/secrets/*|credentials/*|*/credentials/*)
    echo "check-sensitive: blocked write to sensitive path: $file_path" >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
