#!/usr/bin/env bash
# Tests for scripts/validate-rule.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/validate-rule.sh"

cd "$REPO_ROOT" || exit 1

pass=0
fail=0
tmpfiles=()

cleanup() {
  for f in "${tmpfiles[@]}"; do
    rm -f "$f"
  done
}
trap cleanup EXIT

make_rule() {
  local name="$1" content="$2"
  local path="rules/$name"
  printf '%s\n' "$content" > "$path"
  tmpfiles+=("$path")
}

run_case() {
  local desc="$1" file_path="$2" expected="$3" needle="${4:-}"
  local output actual
  output=$(echo "{\"tool_input\":{\"file_path\":\"$file_path\"}}" | bash "$SCRIPT" 2>&1 >/dev/null)
  actual=$?
  if [[ "$actual" -ne "$expected" ]]; then
    echo "FAIL: $desc (expected exit $expected, got $actual: $output)"
    fail=$((fail + 1))
    return
  fi
  if [[ -n "$needle" && "$output" != *"$needle"* ]]; then
    echo "FAIL: $desc (expected output to contain '$needle', got: $output)"
    fail=$((fail + 1))
    return
  fi
  echo "PASS: $desc"
  pass=$((pass + 1))
}

VALID_RULE='title: Valid Rule
description: A valid test rule.
tags:
  - attack.t1003'

make_rule "tmp-valid.yml" "$VALID_RULE"
run_case "valid rule (title+description+attack.t* tag)" "rules/tmp-valid.yml" 0 "is valid"

make_rule "tmp-valid.yaml" "$VALID_RULE"
run_case ".yaml extension also accepted" "rules/tmp-valid.yaml" 0 "is valid"

make_rule "tmp-missing-title.yml" 'description: Missing a title.
tags:
  - attack.t1003'
run_case "missing title" "rules/tmp-missing-title.yml" 2 "missing 'title' field"

make_rule "tmp-missing-description.yml" 'title: Missing Description
tags:
  - attack.t1003'
run_case "missing description" "rules/tmp-missing-description.yml" 2 "missing 'description' field"

make_rule "tmp-missing-tags.yml" 'title: Missing Tags
description: No tags field at all.'
run_case "missing tags entirely" "rules/tmp-missing-tags.yml" 2 "'tags' must be a list"

make_rule "tmp-tags-not-list.yml" 'title: Tags Not A List
description: Tags is a bare string.
tags: attack.t1003'
run_case "tags present but not a list" "rules/tmp-tags-not-list.yml" 2 "'tags' must be a list"

make_rule "tmp-no-attack-tag.yml" 'title: No Attack Tag
description: Has tags but none are attack.t*.
tags:
  - t1003
  - windows'
run_case "tags present but no attack.t* entry" "rules/tmp-no-attack-tag.yml" 2 "'tags' must be a list containing at least one 'attack.t*' entry"

make_rule "tmp-multiple-errors.yml" 'description: Missing title, no attack tag.
tags:
  - windows'
run_case "multiple missing fields reported together" "rules/tmp-multiple-errors.yml" 2 "missing 'title' field"

make_rule "tmp-malformed.yml" 'title: "Unterminated string
description: This is not valid YAML.'
run_case "malformed YAML" "rules/tmp-malformed.yml" 2 "failed to parse YAML"

make_rule "tmp-not-a-mapping.yml" '- item1
- item2'
run_case "YAML that is not a mapping" "rules/tmp-not-a-mapping.yml" 2 "does not contain a YAML mapping"

run_case "nonexistent file" "rules/tmp-does-not-exist.yml" 2 "file not found"

run_case "path outside rules/ is ignored" "src/main.py" 0
run_case "rules/ file with unrelated extension is ignored" "rules/tmp-notes.txt" 0

echo ""
echo "Missing file_path (no tool_input.file_path key):"
output=$(echo '{"tool_input":{}}' | bash "$SCRIPT" 2>&1 >/dev/null)
actual=$?
if [[ "$actual" -eq 0 ]]; then
  echo "PASS: missing file_path allowed"
  pass=$((pass + 1))
else
  echo "FAIL: missing file_path (expected exit 0, got $actual)"
  fail=$((fail + 1))
fi

echo ""
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
