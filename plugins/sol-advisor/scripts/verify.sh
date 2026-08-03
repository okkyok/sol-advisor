#!/bin/sh
# Repository-local verification for Sol Advisor's three-role companion migration.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
runtime_inspector=$script_dir/inspect-agent-runtime.sh
templates=$plugin_dir/agents
manifest=$plugin_dir/.codex-plugin/plugin.json
hooks_file=$plugin_dir/hooks.json
review_hook=$plugin_dir/hooks/review-budget.py
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
preflight=$plugin_dir/skills/orchestration/references/preflight.md
readme=$repo_dir/README.md

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/sol-advisor-verify.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "REFUSING cleanup of unexpected directory: $tmp_dir" >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/sol-advisor-verify.XXXXXX") || fail "could not create disposable verification directory"

terra_file=sol-advisor-terra-implementer.toml
sol_file=sol-advisor-sol-reviewer.toml
floor_file=sol-advisor-luna-committer.toml
luna_file=sol-advisor-luna-implementer.toml
legacy_terra_sha256=4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca
legacy_luna_sha256=fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb
prev_sol_sha256=0333acf0ef562bcfebd06009ac09bd1dd8cbc04c4cf28e08e9e049bd8bf202d2

snapshot_files() {
  target=$1
  if [ ! -d "$target" ]; then
    printf '%s\n' MISSING
    return
  fi
  find "$target" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort | while IFS= read -r path; do
    if [ -L "$path" ]; then
      printf 'L %s -> %s\n' "$(basename "$path")" "$(readlink "$path")"
    elif [ -f "$path" ]; then
      shasum -a 256 "$path"
    else
      printf 'O %s\n' "$(basename "$path")"
    fi
  done
}

write_legacy_roles() {
  target=$1
  mkdir -p "$target"
  cat > "$target/$terra_file" <<'LEGACY_TERRA'
name = "sol_advisor_terra_implementer"
description = "Sol Advisor's complex implementation lane for context-heavy or higher-risk work."
model = "gpt-5.6-terra"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's complex implementation worker. Resolve difficult implementation
details within the settled architecture, including context-heavy, higher-risk, or
wider-blast-radius work. Preserve every stated interface and constraint, stay within
the owned file set, and document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface ambiguity, scope conflicts, or verification failures rather
than changing the architecture without direction. Run the requested checks and report
actual evidence. Do not silently substitute a different role, model, or reasoning
level; this installed custom-agent profile is the required complex lane.
"""
LEGACY_TERRA
  cat > "$target/$luna_file" <<'LEGACY_LUNA'
name = "sol_advisor_luna_implementer"
description = "Sol Advisor's routine implementation lane for bounded, fully specified work."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"

developer_instructions = """
You are Sol Advisor's routine implementation worker. Execute the supplied five-part
implementation specification exactly when it is bounded and largely determined by
the contract. Preserve stated interfaces and constraints, make only the files you
own, and adapt to concurrent edits instead of reverting work you do not own.

Surface material ambiguity, missing acceptance criteria, scope conflicts, or failed
verification rather than redesigning the architecture. Run the requested checks and
report actual evidence. Do not silently substitute a different role, model, or
reasoning level; this installed custom-agent profile is the required routine lane.
"""
LEGACY_LUNA
  cp "$templates/$sol_file" "$target/$sol_file"
  [ "$(shasum -a 256 "$target/$terra_file" | awk '{print $1}')" = "$legacy_terra_sha256" ] || fail "legacy Terra fixture digest drifted"
  [ "$(shasum -a 256 "$target/$luna_file" | awk '{print $1}')" = "$legacy_luna_sha256" ] || fail "legacy Luna fixture digest drifted"
}

for required in "$installer" "$runtime_inspector" "$manifest" "$hooks_file" "$review_hook" "$skill" "$contracts" "$preflight" "$readme"; do
  test -f "$required" || fail "required file missing: $required"
done

jq empty "$manifest"
[ "$(jq -r '.version' "$manifest")" = 0.5.1 ] || fail "manifest version is not 0.5.1"
[ "$(jq -r '.hooks' "$manifest")" = ./hooks.json ] || fail "manifest hooks path is not ./hooks.json"
pass "manifest JSON, version, and hook declaration"

jq empty "$hooks_file"
jq -e '
  (keys == ["hooks"])
  and ((.hooks | keys) == ["PreToolUse"])
  and (.hooks.PreToolUse | length == 1)
  and (.hooks.PreToolUse[0].hooks | length == 1)
  and (.hooks.PreToolUse[0].hooks[0].type == "command")
  and (.hooks.PreToolUse[0].hooks[0].timeout == 10)
  and (.hooks.PreToolUse[0].hooks[0].command | contains("CLAUDE_PLUGIN_ROOT"))
' "$hooks_file" >/dev/null || fail "PreToolUse hook definition is invalid"
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$review_hook"
pass "single PreToolUse hook definition and Python syntax"

hook_data=$tmp_dir/hook-data
hook_ledger=$hook_data/review-budget.jsonl
run_review_hook() {
  printf '%s' "$1" | PLUGIN_DATA="$hook_data" python3 "$review_hook"
}

exec_payload='{"hook_event_name":"PreToolUse","tool_name":"exec","session_id":"budget-session","cwd":"/fixture","tool_input":{}}'
if ! hook_output=$(run_review_hook "$exec_payload"); then fail "exec payload did not fail open"; fi
[ -z "$hook_output" ] || fail "exec payload produced stdout"
test ! -e "$hook_ledger" || fail "exec payload created the review ledger"

implementer_payload='{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_terra_implementer","message":"REVIEW CYCLE"}}'
if ! hook_output=$(run_review_hook "$implementer_payload"); then fail "implementer payload did not fail open"; fi
[ -z "$hook_output" ] || fail "implementer payload produced stdout"
test ! -e "$hook_ledger" || fail "implementer payload created the review ledger"

consult_payload='{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_sol_reviewer","message":"Commitment-boundary consult"}}'
if ! hook_output=$(run_review_hook "$consult_payload"); then fail "consult payload did not fail open"; fi
[ -z "$hook_output" ] || fail "consult payload produced stdout"
test ! -e "$hook_ledger" || fail "consult payload created the review ledger"

review_payload='{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_sol_reviewer","message":"REVIEW CYCLE\nThis is a budgeted final review."}}'
for cycle in 1 2 3; do
  if ! hook_output=$(run_review_hook "$review_payload"); then fail "review cycle $cycle did not exit 0"; fi
  [ -z "$hook_output" ] || fail "review cycle $cycle produced stdout"
done
jq -s -e '
  length == 3
  and (map(.event) == ["review", "review", "review"])
  and (map(.session_id) == ["budget-session", "budget-session", "budget-session"])
  and (map(.cycle) == [1, 2, 3])
' "$hook_ledger" >/dev/null || fail "first three review cycles were not recorded exactly"

if ! hook_output=$(run_review_hook "$review_payload"); then fail "fourth review did not exit 0"; fi
printf '%s\n' "$hook_output" | jq -e '
  .hookSpecificOutput.permissionDecision == "deny"
  and (.hookSpecificOutput.permissionDecisionReason | type == "string" and length > 0)
' >/dev/null || fail "fourth review did not produce the required denial"
[ "$(jq -s 'length' "$hook_ledger")" = 3 ] || fail "denied review changed the ledger"

printf '%s\n' '{"event":"new-deliverable","session_id":"budget-session"}' >> "$hook_ledger"
if ! hook_output=$(run_review_hook "$review_payload"); then fail "new deliverable review did not exit 0"; fi
[ -z "$hook_output" ] || fail "new deliverable review produced stdout"
jq -s -e '
  .[-1].event == "review"
  and .[-1].session_id == "budget-session"
  and .[-1].cycle == 1
' "$hook_ledger" >/dev/null || fail "new deliverable did not restart at cycle 1"

other_session_payload='{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","session_id":"other-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_sol_reviewer","message":"REVIEW CYCLE\nThis is another session."}}'
if ! hook_output=$(run_review_hook "$other_session_payload"); then fail "other session review did not exit 0"; fi
[ -z "$hook_output" ] || fail "other session review produced stdout"
jq -s -e '
  .[-1].event == "review"
  and .[-1].session_id == "other-session"
  and .[-1].cycle == 1
' "$hook_ledger" >/dev/null || fail "other session was affected by the exhausted session"

if ! hook_output=$(printf '%s' 'not json at all' | PLUGIN_DATA="$hook_data" python3 "$review_hook"); then fail "malformed input did not exit 0"; fi
[ -z "$hook_output" ] || fail "malformed input produced stdout"
pass "review-budget hook filtering, enforcement, reset, and fail-open behavior"

python3 - "$templates" <<'PY'
from pathlib import Path
import sys, tomllib

root = Path(sys.argv[1])
expected = {
    "sol-advisor-terra-implementer.toml": {
        "name": "sol_advisor_terra_implementer",
        "model": "gpt-5.6-terra",
        "model_reasoning_effort": "high",
    },
    "sol-advisor-sol-reviewer.toml": {
        "name": "sol_advisor_sol_reviewer",
        "model": "gpt-5.6-sol",
        "model_reasoning_effort": "high",
        "sandbox_mode": "read-only",
    },
    "sol-advisor-luna-committer.toml": {
        "name": "sol_advisor_luna_committer",
        "model": "gpt-5.6-luna",
        "model_reasoning_effort": "medium",
    },
}
actual = {path.name for path in root.glob("*.toml")}
if actual != set(expected):
    raise SystemExit(f"expected exactly {sorted(expected)}, found {sorted(actual)}")
for filename, pins in expected.items():
    data = tomllib.loads((root / filename).read_text(encoding="utf-8"))
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise SystemExit(f"{filename}: missing {field}")
    for field, value in pins.items():
        if data.get(field) != value:
            raise SystemExit(f"{filename}: {field}={data.get(field)!r}, expected {value!r}")
print("three exact role pins are valid")
PY
pass "exact three-role TOML inventory"

grep -Fq "legacy_terra_sha256=$legacy_terra_sha256" "$installer" || fail "installer legacy Terra digest mismatch"
grep -Fq "legacy_luna_sha256=$legacy_luna_sha256" "$installer" || fail "installer legacy Luna digest mismatch"
grep -Fq "prev_sol_sha256=$prev_sol_sha256" "$installer" || fail "installer previous Sol digest mismatch"
pass "immutable v0.2.0 migration fingerprints"

clean_target=$tmp_dir/clean
sh "$installer" --target-dir "$clean_target"
cmp -s "$templates/$terra_file" "$clean_target/$terra_file" || fail "clean Terra install mismatch"
cmp -s "$templates/$sol_file" "$clean_target/$sol_file" || fail "clean Sol install mismatch"
cmp -s "$templates/$floor_file" "$clean_target/$floor_file" || fail "clean floor-lane install mismatch"
test ! -e "$clean_target/$luna_file" || fail "clean install created retired Luna role"
sh "$installer" --target-dir "$clean_target" --check
before=$(snapshot_files "$clean_target")
sh "$installer" --target-dir "$clean_target"
after=$(snapshot_files "$clean_target")
[ "$before" = "$after" ] || fail "idempotent install changed current roles"
pass "clean install, exact check, and idempotence"

missing_target=$tmp_dir/missing
if sh "$installer" --target-dir "$missing_target" --check; then fail "--check accepted missing target"; fi
test ! -e "$missing_target" || fail "--check mutated missing target"
pass "missing-target check refusal is non-mutating"

codex_home=$tmp_dir/codex-home
CODEX_HOME="$codex_home" sh "$installer"
cmp -s "$templates/$terra_file" "$codex_home/agents/$terra_file" || fail "CODEX_HOME Terra mismatch"
cmp -s "$templates/$sol_file" "$codex_home/agents/$sol_file" || fail "CODEX_HOME Sol mismatch"
cmp -s "$templates/$floor_file" "$codex_home/agents/$floor_file" || fail "CODEX_HOME floor-lane mismatch"
test ! -e "$codex_home/config.toml" || fail "installer created config.toml"
relative_parent=$tmp_dir/relative-parent
mkdir "$relative_parent"
(cd "$relative_parent" && sh "$installer" --target-dir relative-agents)
cmp -s "$templates/$terra_file" "$relative_parent/relative-agents/$terra_file" || fail "relative target Terra mismatch"
pass "CODEX_HOME and relative target behavior"

migration_target=$tmp_dir/migration
write_legacy_roles "$migration_target"
sh "$installer" --target-dir "$migration_target"
cmp -s "$templates/$terra_file" "$migration_target/$terra_file" || fail "legacy Terra was not migrated"
cmp -s "$templates/$sol_file" "$migration_target/$sol_file" || fail "Sol changed during migration"
test ! -e "$migration_target/$luna_file" || fail "exact legacy Luna was not removed"
sh "$installer" --target-dir "$migration_target" --check
pass "exact v0.2.0 Terra replacement and Luna retirement"

prev_sol_target=$tmp_dir/previous-sol-migration
sh "$installer" --target-dir "$prev_sol_target"
if ! command -v git >/dev/null 2>&1; then
  printf '%s\n' "SKIP: predecessor Sol migration requires git"
else
  prev_sol_fixture=$tmp_dir/previous-sol-reviewer.toml
  if ! git -C "$repo_dir" show HEAD:plugins/sol-advisor/agents/sol-advisor-sol-reviewer.toml > "$prev_sol_fixture"; then
    printf '%s\n' "SKIP: predecessor Sol migration could not read the template from git"
  else
    cp "$prev_sol_fixture" "$prev_sol_target/$sol_file"
    prev_sol_digest=$(shasum -a 256 "$prev_sol_target/$sol_file" | awk '{print $1}')
    current_sol_digest=$(shasum -a 256 "$templates/$sol_file" | awk '{print $1}')
    if [ "$prev_sol_digest" = "$current_sol_digest" ]; then
      printf '%s\n' "SKIP: predecessor Sol template is byte-identical to the current template"
    else
      [ "$prev_sol_digest" = "$prev_sol_sha256" ] || fail "predecessor Sol fixture digest mismatch"
      sh "$installer" --target-dir "$prev_sol_target"
      cmp -s "$templates/$sol_file" "$prev_sol_target/$sol_file" || fail "previous Sol reviewer was not migrated"
      sh "$installer" --target-dir "$prev_sol_target" --check
      pass "previous shipped Sol reviewer migration"
    fi
  fi
fi

modified_luna=$tmp_dir/modified-luna
write_legacy_roles "$modified_luna"
printf '%s\n' modified >> "$modified_luna/$luna_file"
before=$(snapshot_files "$modified_luna")
if sh "$installer" --target-dir "$modified_luna"; then fail "installer removed modified Luna"; fi
after=$(snapshot_files "$modified_luna")
[ "$before" = "$after" ] || fail "modified-Luna refusal partially mutated target"
pass "modified Luna refusal with zero partial mutation"

modified_terra=$tmp_dir/modified-terra
write_legacy_roles "$modified_terra"
printf '%s\n' modified >> "$modified_terra/$terra_file"
before=$(snapshot_files "$modified_terra")
if sh "$installer" --target-dir "$modified_terra"; then fail "installer replaced modified Terra"; fi
after=$(snapshot_files "$modified_terra")
[ "$before" = "$after" ] || fail "modified-Terra refusal partially mutated target"
pass "modified Terra refusal with zero partial mutation"

stale_luna=$tmp_dir/stale-luna
sh "$installer" --target-dir "$stale_luna"
stale_fixture=$tmp_dir/stale-fixture
write_legacy_roles "$stale_fixture"
cp "$stale_fixture/$luna_file" "$stale_luna/$luna_file"
before=$(snapshot_files "$stale_luna")
if sh "$installer" --target-dir "$stale_luna" --check; then fail "--check accepted stale Luna"; fi
after=$(snapshot_files "$stale_luna")
[ "$before" = "$after" ] || fail "stale-Luna check mutated target"
pass "stale Luna check refusal is non-mutating"

unsafe=$tmp_dir/unsafe
mkdir "$unsafe"
ln -s "$templates/$terra_file" "$unsafe/$terra_file"
before=$(snapshot_files "$unsafe")
if sh "$installer" --target-dir "$unsafe"; then fail "installer accepted symlinked Terra"; fi
after=$(snapshot_files "$unsafe")
[ "$before" = "$after" ] || fail "symlink refusal partially mutated target"
test ! -e "$unsafe/$sol_file" || fail "symlink refusal partially installed Sol"
pass "unsafe destination refusal with zero partial mutation"

runtime_sessions=$tmp_dir/runtime-sessions
runtime_day=$runtime_sessions/2026/08/02
mkdir -p "$runtime_day"
runtime_id=11111111-1111-7111-8111-111111111111
runtime_rollout=$runtime_day/rollout-2026-08-02T00-00-00-$runtime_id.jsonl
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK_PROMPT"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_terra_implementer\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"high","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_rollout"
runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$runtime_id")
printf '%s\n' "$runtime_output" | jq -e --arg id "$runtime_id" '
  .thread_id == $id and .agent_role == "sol_advisor_terra_implementer"
  and .model == "gpt-5.6-terra" and .effort == "high"
  and .sandbox_policy_type == "danger-full-access"
  and .permission_profile_type == "disabled"
' >/dev/null || fail "runtime inspector returned wrong Terra/High evidence"
if printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK; then fail "runtime inspector leaked payload"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" invalid >/dev/null 2>&1; then fail "runtime inspector accepted invalid id"; fi
zero_id=22222222-2222-7222-8222-222222222222
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$zero_id" >/dev/null 2>&1; then fail "runtime inspector accepted zero matches"; fi
pass "runtime inspector Terra/High routing and safe refusal"

for document in "$skill" "$contracts"; do
  grep -Fq 'agent_type: sol_advisor_terra_implementer' "$document" || fail "missing Terra spawn in $document"
  grep -Fq 'agent_type: sol_advisor_sol_reviewer' "$document" || fail "missing Sol spawn in $document"
  grep -Fq 'agent_type: sol_advisor_luna_committer' "$document" || fail "missing floor-lane spawn in $document"
  grep -Fq 'fork_turns: none' "$document" || fail "missing fresh context in $document"
  if grep -Eq 'agent_type:.*(luna_implementer|terra_max)' "$document"; then fail "retired Luna implementer or Terra max spawn remains in $document"; fi
  if grep -Eq '^[[:space:]]*(model|reasoning_effort):' "$document"; then fail "per-spawn override remains in $document"; fi
done
grep -Fq '../../scripts/install-agents.sh' "$preflight" || fail "preflight does not resolve installer relatively"
grep -Fq '../../scripts/inspect-agent-runtime.sh' "$preflight" || fail "preflight does not resolve inspector relatively"
grep -Fqi 'public native spawn/details metadata first' "$preflight" || fail "preflight lacks public-details-first evidence rule"
grep -Fqi 'parent captures and verifies exact before-and-after' "$contracts" || fail "contracts lack behavioral read-only state check"
forbidden_terra='sol_advisor_terra_'"max"
forbidden_file='sol-advisor-terra-'"max"
if rg -n "$forbidden_terra|$forbidden_file" "$readme" "$plugin_dir"; then fail "forbidden second Terra role remains"; fi
pass "three-lane documentation and no per-spawn overrides"
grep -Fq 'sol_advisor_luna_committer' "$preflight" || fail "preflight is missing sol_advisor_luna_committer"
for role in sol_advisor_terra_implementer sol_advisor_sol_reviewer sol_advisor_luna_committer; do
  grep -Fq "$role" "$preflight" || fail "preflight is missing required role: $role"
done
if grep -Fq 'The two role files' "$preflight"; then fail "preflight retains retired two-lane role-file wording"; fi
pass "preflight three required role names and retired two-lane wording absence"

sh -n "$installer"
sh -n "$runtime_inspector"
sh -n "$script_dir/verify.sh"
pass "shell syntax"

printf '%s\n' "VERIFY PASSED: Sol Advisor three-role migration checks completed in $tmp_dir"
