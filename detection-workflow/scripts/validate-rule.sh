#!/usr/bin/env bash

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

case "$file_path" in
  rules/*.yml|rules/*.yaml) ;;
  *) exit 0 ;;
esac

if [[ ! -f "$file_path" ]]; then
  echo "validate-rule: file not found: $file_path" >&2
  exit 2
fi

if python3 -c "" >/dev/null 2>&1; then
  PYTHON=python3
elif python -c "" >/dev/null 2>&1; then
  PYTHON=python
else
  echo "validate-rule: no working python interpreter found" >&2
  exit 2
fi

errors=$("$PYTHON" - "$file_path" <<'PYEOF'
import sys
import yaml

path = sys.argv[1]
errors = []

try:
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
except Exception as e:
    print(f"failed to parse YAML: {e}")
    sys.exit(1)

if not isinstance(data, dict):
    print("rule file does not contain a YAML mapping")
    sys.exit(1)

if not data.get("title"):
    errors.append("missing 'title' field")

if not data.get("description"):
    errors.append("missing 'description' field")

tags = data.get("tags")
if not isinstance(tags, list) or not any(
    isinstance(tag, str) and tag.startswith("attack.t") for tag in tags
):
    errors.append("'tags' must be a list containing at least one 'attack.t*' entry")

if errors:
    for e in errors:
        print(e)
    sys.exit(1)

sys.exit(0)
PYEOF
)
status=$?

if [[ $status -ne 0 ]]; then
  echo "validate-rule: $file_path is INVALID" >&2
  echo "$errors" | sed 's/^/  - /' >&2
  exit 2
fi

echo "validate-rule: $file_path is valid" >&2
exit 2
