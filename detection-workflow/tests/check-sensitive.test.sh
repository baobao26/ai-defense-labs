#!/usr/bin/env bash
# Tests for scripts/check-sensitive.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check-sensitive.sh"

pass=0
fail=0

run_case() {
  local desc="$1" file_path="$2" expected="$3"
  local actual
  echo "{\"tool_input\":{\"file_path\":\"$file_path\"}}" | bash "$SCRIPT" >/dev/null 2>&1
  actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected exit $expected, got $actual)"
    fail=$((fail + 1))
  fi
}

# Should block (exit 2)
run_case "bare .env"                      ".env"               2
run_case ".env in subdirectory"           "config/.env"        2
run_case "*.env suffix"                   "app.env"            2
run_case "*.key suffix"                   "id_rsa.key"         2
run_case "*.pem suffix"                   "server.pem"         2
run_case "secrets/ at root"               "secrets/prod.txt"   2
run_case "secrets/ nested"                "foo/secrets/bar.txt" 2
run_case "credentials/ at root"           "credentials/aws.json" 2
run_case "credentials/ nested"            "foo/credentials/aws.json" 2

# Should allow (exit 0)
run_case "unrelated yaml file"            "rules/test-rule.yml" 0
run_case "unrelated source file"          "src/main.py"         0
run_case "unrelated markdown file"        "README.md"           0
run_case "path containing but not matching 'key'" "monkey.txt"  0

run_command_case() {
  local desc="$1" command="$2" expected="$3"
  local actual
  echo "{\"tool_input\":{\"command\":\"$command\"}}" | bash "$SCRIPT" >/dev/null 2>&1
  actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected exit $expected, got $actual)"
    fail=$((fail + 1))
  fi
}

# Bash tool_input has no file_path, only a command string — should block (exit 2)
run_command_case "cat .env via Bash"                 "cat .env"                       2
run_command_case "cat secrets/ via Bash"             "cat secrets/prod.txt"           2
run_command_case "cat credentials/ via Bash"         "cat credentials/aws.json"       2
run_command_case "read *.key via Bash"               "openssl rsa -in id_rsa.key"     2
run_command_case "read *.pem via Bash"                "cat server.pem"                2
run_command_case "curl a secrets/ URL via Bash"      "curl https://example.com/secrets/token" 2

# Bash commands that should be allowed (exit 0)
run_command_case "unrelated ls via Bash"             "ls -la"                         0
run_command_case "'key' substring without dot"       "echo hello key"                 0
run_command_case "grep for the word secrets"         "grep -r TODO src/"              0

echo ""
echo "Missing file_path (no tool_input.file_path key):"
echo '{"tool_input":{}}' | bash "$SCRIPT" >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 0 ]]; then
  echo "PASS: missing file_path allowed"
  pass=$((pass + 1))
else
  echo "FAIL: missing file_path (expected exit 0, got $actual)"
  fail=$((fail + 1))
fi

echo ""
echo "Block message on stderr:"
message=$(echo '{"tool_input":{"file_path":".env"}}' | bash "$SCRIPT" 2>&1 >/dev/null)
if [[ "$message" == *"blocked"* && "$message" == *".env"* ]]; then
  echo "PASS: block message mentions path and 'blocked'"
  pass=$((pass + 1))
else
  echo "FAIL: block message missing or malformed: $message"
  fail=$((fail + 1))
fi

echo ""
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
