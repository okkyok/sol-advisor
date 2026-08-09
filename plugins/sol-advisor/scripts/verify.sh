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
data_dir_resolver=$script_dir/resolve-data-dir.sh
ledger_report=$script_dir/ledger-report.sh
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
description = "Sol Advisor's sole implementation lane for routine and complex work."
model = "gpt-5.6-terra"
model_reasoning_effort = "high"

developer_instructions = """
You are Sol Advisor's sole implementation worker for routine, context-heavy,
higher-risk, and wider-blast-radius work. Execute the supplied five-part specification
within the settled architecture. Preserve every stated interface and constraint, stay
within the owned file set, and document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface ambiguity, scope conflicts, or verification failures rather
than redesigning the architecture without direction. Run the requested checks and
report actual evidence. Do not silently substitute a different role, model, or
reasoning level; this installed custom-agent profile is the only implementation lane.
"""
LEGACY_TERRA
  cp "$templates/$sol_file" "$target/$sol_file"
  cp "$templates/$floor_file" "$target/$floor_file"
  [ "$(shasum -a 256 "$target/$terra_file" | awk '{print $1}')" = "$legacy_terra_sha256" ] || fail "legacy Terra fixture digest drifted"
}

for required in "$installer" "$runtime_inspector" "$script_dir/check-hook-trust.sh" "$data_dir_resolver" "$ledger_report" "$manifest" "$hooks_file" "$review_hook" "$skill" "$contracts" "$preflight" "$readme"; do
  test -f "$required" || fail "required file missing: $required"
done

jq empty "$manifest"
[ "$(jq -r '.version' "$manifest")" = 0.7.1 ] || fail "manifest version is not 0.7.1"
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

implementer_payload='{"hook_event_name":"PreToolUse","tool_name":"collaboration.spawn_agent","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_terra_implementer","message":"REVIEW CYCLE"}}'
if ! hook_output=$(run_review_hook "$implementer_payload"); then fail "implementer payload did not fail open"; fi
[ -z "$hook_output" ] || fail "implementer payload produced stdout"
test ! -e "$hook_ledger" || fail "implementer payload created the review ledger"

consult_payload='{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_sol_reviewer","message":"COMMITMENT BOUNDARY\nPre-implementation consult."}}'
if ! hook_output=$(run_review_hook "$consult_payload"); then fail "consult payload did not fail open"; fi
[ -z "$hook_output" ] || fail "consult payload produced stdout"
jq -s -e '
  length == 1
  and (.[0].event == "consult")
  and (.[0].session_id == "budget-session")
  and (.[0].used == 0)
  and (.[0].cycle == null)
' "$hook_ledger" >/dev/null || fail "marked consult was not recorded as an uncounted consult"

# The host may namespace its tool name or omit it entirely. Reviewer identity comes
# from the exact agent type, while other agent types remain ignored.
namespaced_reviewer_payload='{"hook_event_name":"PreToolUse","tool_name":"collaboration.spawn_agent","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_sol_reviewer","message":"Please review the accumulated diff."}}'
if ! hook_output=$(run_review_hook "$namespaced_reviewer_payload"); then fail "namespaced review did not exit 0"; fi
[ -z "$hook_output" ] || fail "namespaced review produced stdout"
jq -s -e '
  (map(select(.event == "review")) | length) == 1
  and (.[-1].event == "review")
  and (.[-1].cycle == 1)
' "$hook_ledger" >/dev/null || fail "namespaced reviewer spawn was not counted against the budget"

tool_name_absent_reviewer_payload='{"hook_event_name":"PreToolUse","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_sol_reviewer","message":"Please review the accumulated diff again."}}'
if ! hook_output=$(run_review_hook "$tool_name_absent_reviewer_payload"); then fail "tool-name-absent review did not exit 0"; fi
[ -z "$hook_output" ] || fail "tool-name-absent review produced stdout"
jq -s -e '
  (map(select(.event == "review")) | length) == 2
  and (.[-1].event == "review")
  and (.[-1].cycle == 2)
' "$hook_ledger" >/dev/null || fail "tool-name-absent reviewer spawn was not counted against the budget"

review_payload='{"hook_event_name":"PreToolUse","tool_name":"spawn_agent","session_id":"budget-session","cwd":"/fixture","tool_input":{"agent_type":"sol_advisor_sol_reviewer","message":"REVIEW CYCLE\nThis is a budgeted final review."}}'
if ! hook_output=$(run_review_hook "$review_payload"); then fail "review cycle 3 did not exit 0"; fi
[ -z "$hook_output" ] || fail "review cycle 3 produced stdout"
jq -s -e '
  length == 4
  and (map(.event) == ["consult", "review", "review", "review"])
  and (map(.session_id) | unique == ["budget-session"])
  and (map(select(.event == "review")) | map(.cycle) == [1, 2, 3])
' "$hook_ledger" >/dev/null || fail "first three review cycles were not recorded exactly"

if ! hook_output=$(run_review_hook "$review_payload"); then fail "fourth review did not exit 0"; fi
printf '%s\n' "$hook_output" | jq -e '
  .hookSpecificOutput.permissionDecision == "deny"
  and (.hookSpecificOutput.permissionDecisionReason | type == "string" and length > 0)
' >/dev/null || fail "fourth review did not produce the required denial"
jq -s -e '
  (map(select(.event == "review")) | length) == 3
  and (map(select(.event == "denied")) | length) == 1
  and .[-1].cycle == 4
' "$hook_ledger" >/dev/null || fail "fourth review denial was not recorded exactly"

if ! hook_output=$(run_review_hook "$review_payload"); then fail "fifth review did not exit 0"; fi
printf '%s\n' "$hook_output" | jq -e '
  .hookSpecificOutput.permissionDecision == "deny"
' >/dev/null || fail "fifth review did not produce the required denial"
jq -s -e '
  (map(select(.event == "review")) | length) == 3
  and (map(select(.event == "denied")) | length) == 2
  and .[-1].cycle == 4
' "$hook_ledger" >/dev/null || fail "repeated denial inflated the review count"
pass "review denials are recorded without inflating the review budget"

# Relabelling an exhausted deliverable's final review as a consult is the one move the
# exemption makes possible, so it must leave a trace the reader reports.
if ! hook_output=$(run_review_hook "$consult_payload"); then fail "post-denial consult did not exit 0"; fi
[ -z "$hook_output" ] || fail "post-denial consult produced stdout"
jq -s -e '
  (map(select(.event == "review")) | length) == 3
  and (.[-1].event == "consult")
  and (.[-1].used == 3)
' "$hook_ledger" >/dev/null || fail "post-denial consult was counted or not recorded"

if ! ledger_output=$(sh "$ledger_report" --data-dir "$hook_data"); then fail "ledger report rejected the budget ledger"; fi
printf '%s\n' "$ledger_output" | grep -Fq 'Deliverables: 1' || fail "ledger report did not count one deliverable"
printf '%s\n' "$ledger_output" | grep -Fq '3 cycles=1' || fail "ledger report did not count three used cycles"
printf '%s\n' "$ledger_output" | grep -Fq 'Deliverables that hit the cap: 1' || fail "ledger report did not count one cap hit"
printf '%s\n' "$ledger_output" | grep -Fq 'scope freezing is not working' || fail "ledger report omitted the cap-hit verdict"
printf '%s\n' "$ledger_output" | grep -Fq 'Exempt consults: 2' || fail "ledger report did not count exempt consults"
printf '%s\n' "$ledger_output" | grep -Fq 'Bypass signatures after a denial: 1 (reset=0, consult=1)' || fail "ledger report did not detect the post-denial consult"
printf '%s\n' "$ledger_output" | grep -Fq 'routed around' || fail "ledger report omitted the bypass verdict"

bypass_reset_data=$tmp_dir/bypass-reset
mkdir "$bypass_reset_data"
printf '%s\n' \
  '{"event":"review","session_id":"s","cycle":1}' \
  '{"event":"review","session_id":"s","cycle":2}' \
  '{"event":"review","session_id":"s","cycle":3}' \
  '{"event":"denied","session_id":"s","cycle":4}' \
  '{"event":"new-deliverable","session_id":"s"}' \
  > "$bypass_reset_data/review-budget.jsonl"
if ! bypass_output=$(sh "$ledger_report" --data-dir "$bypass_reset_data"); then fail "ledger report rejected the bypass fixture"; fi
printf '%s\n' "$bypass_output" | grep -Fq 'Bypass signatures after a denial: 1 (reset=1, consult=0)' || fail "ledger report did not detect a reset immediately after a denial"

clean_reset_data=$tmp_dir/clean-reset
mkdir "$clean_reset_data"
printf '%s\n' \
  '{"event":"review","session_id":"s","cycle":1}' \
  '{"event":"new-deliverable","session_id":"s"}' \
  '{"event":"review","session_id":"s","cycle":1}' \
  > "$clean_reset_data/review-budget.jsonl"
if ! clean_output=$(sh "$ledger_report" --data-dir "$clean_reset_data"); then fail "ledger report rejected the clean-reset fixture"; fi
printf '%s\n' "$clean_output" | grep -Fq 'Bypass signatures after a denial: 0 (reset=0, consult=0)' || fail "ledger report flagged a reset that did not follow a denial"
printf '%s\n' "$clean_output" | grep -Fq 'does not show any budget warning condition' || fail "ledger report warned on a clean ledger"

empty_ledger_data=$tmp_dir/empty-ledger
mkdir "$empty_ledger_data"
before=$(snapshot_files "$empty_ledger_data")
if ! no_ledger_output=$(sh "$ledger_report" --data-dir "$empty_ledger_data"); then fail "missing ledger report did not exit 0"; fi
after=$(snapshot_files "$empty_ledger_data")
[ "$before" = "$after" ] || fail "missing ledger report mutated the data directory"
printf '%s\n' "$no_ledger_output" | grep -Fq "no ledger found at $empty_ledger_data/review-budget.jsonl" || fail "missing ledger report omitted the clean message"
if sh "$ledger_report" --unknown >/dev/null 2>&1; then fail "ledger report accepted an unknown argument"; else report_status=$?; fi
[ "$report_status" -eq 2 ] || fail "ledger report unknown argument did not exit 2"

multi_ledger_data=$tmp_dir/multi-ledger
mkdir "$multi_ledger_data"
printf '%s\n' \
  '{"event":"review","session_id":"session-a","cycle":1}' \
  '{"event":"new-deliverable","session_id":"session-a"}' \
  '{"event":"review","session_id":"session-a","cycle":1}' \
  '{"event":"review","session_id":"session-b","cycle":1}' \
  > "$multi_ledger_data/review-budget.jsonl"
if ! multi_ledger_output=$(sh "$ledger_report" --data-dir "$multi_ledger_data"); then fail "multi-session ledger report failed"; fi
printf '%s\n' "$multi_ledger_output" | grep -Fq 'Deliverables: 3' || fail "ledger report did not split deliverables by reset and session"
pass "ledger reporting, no-ledger handling, and deliverable grouping"

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

liveness_data=$tmp_dir/hook-liveness
liveness_status=$liveness_data/hook-status.json
if grep -q '<<' "$script_dir/check-hook-trust.sh"; then fail "check-hook-trust.sh uses a here-document, which needs a temp file and fails in a read-only sandbox"; fi
if grep -q '<<' "$data_dir_resolver"; then fail "resolve-data-dir.sh uses a here-document"; fi
if grep -q '<<' "$ledger_report"; then fail "ledger-report.sh uses a here-document"; fi
liveness_payload='{"hook_event_name":"PreToolUse","tool_name":"exec","session_id":"liveness-session","cwd":"/fixture","tool_input":{}}'
if ! hook_output=$(printf '%s' "$liveness_payload" | PLUGIN_DATA="$liveness_data" python3 "$review_hook"); then fail "liveness payload did not fail open"; fi
[ -z "$hook_output" ] || fail "liveness payload produced stdout"
test ! -e "$liveness_data/review-budget.jsonl" || fail "liveness payload created the review ledger"
python3 - "$liveness_status" <<'PY'
import datetime
import json
from pathlib import Path
import sys

heartbeat = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if set(heartbeat) != {"ts", "session_id", "plugin_version"}:
    raise SystemExit("heartbeat keys are not exact")
if heartbeat["session_id"] != "liveness-session":
    raise SystemExit("heartbeat session id is wrong")
timestamp = heartbeat["ts"]
if not isinstance(timestamp, str) or not timestamp.endswith("Z"):
    raise SystemExit("heartbeat timestamp is not UTC ISO-8601")
parsed = datetime.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
if parsed.tzinfo is None:
    raise SystemExit("heartbeat timestamp has no timezone")
if abs((datetime.datetime.now(datetime.timezone.utc) - parsed).total_seconds()) > 60:
    raise SystemExit("heartbeat timestamp is not plausibly fresh")
PY
[ "$(jq -r '.plugin_version' "$liveness_status")" = "$(jq -r '.version' "$manifest")" ] || fail "heartbeat plugin version does not match manifest"
if ! active_output=$(sh "$script_dir/check-hook-trust.sh" --data-dir "$liveness_data"); then fail "checker rejected a fresh heartbeat"; fi
[ "$(printf '%s\n' "$active_output" | sed -n '1p')" = "HOOK ACTIVE" ] || fail "fresh heartbeat output did not start with HOOK ACTIVE"
printf '%s\n' "$active_output" | grep -Fq 'unverified because no nonce was supplied' || fail "nonce-free checker did not warn that the result is unverified"

expanded_nonce_data=$tmp_dir/hook-expanded-nonce
expanded_nonce_status=$expanded_nonce_data/hook-status.json
mkdir "$expanded_nonce_data"
expanded_nonce_payload='{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"expanded-nonce-session","cwd":"/fixture","tool_input":{"command":"sh /path/check-hook-trust.sh --nonce \"$$-$(date +%s)\""}}'
[ "$(printf '%s' "$expanded_nonce_payload" | jq -r '.tool_input.command')" = 'sh /path/check-hook-trust.sh --nonce "$$-$(date +%s)"' ] || fail "expanded nonce fixture was altered by the test shell"
if ! hook_output=$(printf '%s' "$expanded_nonce_payload" | PLUGIN_DATA="$expanded_nonce_data" python3 "$review_hook"); then fail "expanded nonce payload did not fail open"; fi
[ -z "$hook_output" ] || fail "expanded nonce payload produced stdout"
jq -e '(.nonce == null)' "$expanded_nonce_status" >/dev/null || fail "hook recorded shell-expansion syntax as a usable nonce"
if expanded_nonce_output=$(sh "$script_dir/check-hook-trust.sh" --data-dir "$expanded_nonce_data" --nonce something-valid); then fail "checker accepted a heartbeat with no nonce key"; else expanded_nonce_exit=$?; fi
[ "$expanded_nonce_exit" -eq 1 ] || fail "missing heartbeat nonce did not exit 1"
[ "$(printf '%s\n' "$expanded_nonce_output" | sed -n '1p')" = "HOOK INERT" ] || fail "missing heartbeat nonce output did not start with HOOK INERT"
printf '%s\n' "$expanded_nonce_output" | grep -Fq 'shell expanded' || fail "missing heartbeat nonce output omitted the shell-expansion cause"
printf '%s\n' "$expanded_nonce_output" | grep -Fq 'Pass a literal token instead' || fail "missing heartbeat nonce output omitted the literal-token remedy"
if printf '%s\n' "$expanded_nonce_output" | grep -Fq 'did not observe this invocation'; then fail "missing heartbeat nonce used the differing-nonce wording"; fi

literal_nonce_data=$tmp_dir/hook-literal-nonce
literal_nonce_status=$literal_nonce_data/hook-status.json
mkdir "$literal_nonce_data"
literal_nonce_payload='{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"literal-nonce-session","cwd":"/fixture","tool_input":{"command":"sh /path/check-hook-trust.sh --nonce liveness-abc123"}}'
if ! hook_output=$(printf '%s' "$literal_nonce_payload" | PLUGIN_DATA="$literal_nonce_data" python3 "$review_hook"); then fail "literal nonce payload did not fail open"; fi
[ -z "$hook_output" ] || fail "literal nonce payload produced stdout"
[ "$(jq -r '.nonce' "$literal_nonce_status")" = liveness-abc123 ] || fail "hook heartbeat did not record the literal nonce"

nonce_payload='{"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"liveness-session","cwd":"/fixture","tool_input":{"command":"sh check-hook-trust.sh --data-dir /fixture --nonce abc-123"}}'
if ! hook_output=$(printf '%s' "$nonce_payload" | PLUGIN_DATA="$liveness_data" python3 "$review_hook"); then fail "nonce payload did not fail open"; fi
[ -z "$hook_output" ] || fail "nonce payload produced stdout"
[ "$(jq -r '.nonce' "$liveness_status")" = abc-123 ] || fail "hook heartbeat did not record the nonce"
if ! active_output=$(sh "$script_dir/check-hook-trust.sh" --data-dir "$liveness_data" --nonce abc-123); then fail "checker rejected a matching nonce"; fi
[ "$(printf '%s\n' "$active_output" | sed -n '1p')" = "HOOK ACTIVE" ] || fail "matching nonce output did not start with HOOK ACTIVE"
printf '%s\n' "$active_output" | grep -Fq 'produced by this invocation' || fail "matching nonce output omitted invocation proof"
if inert_output=$(sh "$script_dir/check-hook-trust.sh" --nonce different-1 --data-dir "$liveness_data"); then fail "checker accepted a different nonce"; else inert_status=$?; fi
[ "$inert_status" -eq 1 ] || fail "different nonce did not exit 1"
[ "$(printf '%s\n' "$inert_output" | sed -n '1p')" = "HOOK INERT" ] || fail "different nonce output did not start with HOOK INERT"
printf '%s\n' "$inert_output" | grep -Fq 'did not observe this invocation' || fail "different nonce output omitted the mismatch reason"
if printf '%s\n' "$inert_output" | grep -Fq 'recorded no nonce'; then fail "different nonce used the missing-nonce wording"; fi
if sh "$script_dir/check-hook-trust.sh" --data-dir "$liveness_data" --nonce 'bad;token' >/dev/null 2>&1; then fail "checker accepted a nonce containing a semicolon"; else nonce_status=$?; fi
[ "$nonce_status" -eq 2 ] || fail "invalid nonce did not exit 2"
if sh "$script_dir/check-hook-trust.sh" --nonce ab >/dev/null 2>&1; then fail "checker accepted a nonce shorter than four characters"; else nonce_status=$?; fi
[ "$nonce_status" -eq 2 ] || fail "short nonce did not exit 2"
if sh "$script_dir/check-hook-trust.sh" --nonce >/dev/null 2>&1; then fail "checker accepted --nonce without a value"; else nonce_status=$?; fi
[ "$nonce_status" -eq 2 ] || fail "missing nonce value did not exit 2"
if sh "$script_dir/check-hook-trust.sh" --unknown >/dev/null 2>&1; then fail "checker accepted an unknown argument"; else nonce_status=$?; fi
[ "$nonce_status" -eq 2 ] || fail "checker unknown argument did not exit 2"

if ! hook_output=$(printf '%s' "$liveness_payload" | PLUGIN_DATA="$liveness_data" python3 "$review_hook"); then fail "second nonce-free payload did not fail open"; fi
[ -z "$hook_output" ] || fail "second nonce-free payload produced stdout"
jq -e '(.nonce == null)' "$liveness_status" >/dev/null || fail "nonce-free heartbeat retained a nonce"
pass "hook nonce capture, shell-expansion diagnosis, and invocation-bound liveness checks"

empty_data=$tmp_dir/hook-empty
empty_data_codex_home=$tmp_dir/hook-empty-codex-home
mkdir "$empty_data"
if inert_output=$(env -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA CODEX_HOME="$empty_data_codex_home" sh "$script_dir/check-hook-trust.sh" --data-dir "$empty_data"); then fail "checker accepted a missing heartbeat"; fi
[ "$(printf '%s\n' "$inert_output" | sed -n '1p')" = "HOOK INERT" ] || fail "missing heartbeat output did not start with HOOK INERT"

stale_data=$tmp_dir/hook-stale
mkdir "$stale_data"
python3 -c "import datetime,json; print(json.dumps({'ts': (datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(hours=2)).isoformat().replace('+00:00','Z'), 'session_id':'stale-session','plugin_version':'0.5.2'}))" > "$stale_data/hook-status.json"
if inert_output=$(sh "$script_dir/check-hook-trust.sh" --data-dir "$stale_data"); then fail "checker accepted a stale heartbeat"; fi
[ "$(printf '%s\n' "$inert_output" | sed -n '1p')" = "HOOK INERT" ] || fail "stale heartbeat output did not start with HOOK INERT"

malformed_data=$tmp_dir/hook-malformed
mkdir "$malformed_data"
printf '%s\n' 'not json at all' > "$malformed_data/hook-status.json"
if inert_output=$(sh "$script_dir/check-hook-trust.sh" --data-dir "$malformed_data"); then fail "checker accepted a malformed heartbeat"; fi
[ "$(printf '%s\n' "$inert_output" | sed -n '1p')" = "HOOK INERT" ] || fail "malformed heartbeat output did not start with HOOK INERT"

fake_script_dir=$tmp_dir/fake/plugins/cache/mp/plug/9.9.9/scripts
fake_data=$tmp_dir/fake/plugins/data/mp-plug
fake_codex_home=$tmp_dir/fake-empty-codex-home
mkdir -p "$fake_script_dir" "$fake_data" "$fake_codex_home"
fake_data=$(CDPATH= cd "$fake_data" && pwd)
cp "$script_dir/check-hook-trust.sh" "$fake_script_dir/check-hook-trust.sh"
cp "$data_dir_resolver" "$fake_script_dir/resolve-data-dir.sh"
cp "$ledger_report" "$fake_script_dir/ledger-report.sh"
cp "$liveness_status" "$fake_data/hook-status.json"
cp "$hook_ledger" "$fake_data/review-budget.jsonl"
if ! active_output=$(env -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA CODEX_HOME="$fake_codex_home" sh "$fake_script_dir/check-hook-trust.sh"); then fail "checker rejected a derived-path heartbeat"; fi
[ "$(printf '%s\n' "$active_output" | sed -n '1p')" = "HOOK ACTIVE" ] || fail "derived-path output did not start with HOOK ACTIVE"
printf '%s\n' "$active_output" | grep -Fq "$fake_data" || fail "derived-path output did not name the derived data directory"
if ! derived_ledger_output=$(env -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA CODEX_HOME="$fake_codex_home" sh "$fake_script_dir/ledger-report.sh"); then fail "ledger reporter rejected a derived-path ledger"; fi
checker_resolved=$(printf '%s\n' "$active_output" | sed -n 's/^Resolved data directory: //p')
report_resolved=$(printf '%s\n' "$derived_ledger_output" | sed -n 's|^Resolved ledger: ||p' | sed 's|/review-budget.jsonl$||')
[ "$checker_resolved" = "$report_resolved" ] || fail "checker and ledger reporter resolved different data directories"
pass "shared hook and ledger-report data-directory resolution"

checkout_name=checkout-layout
checkout_script_dir=$tmp_dir/$checkout_name/plugins/sol-advisor/scripts
checkout_codex_home=$tmp_dir/checkout-codex-home
checkout_data=$checkout_codex_home/plugins/data/$checkout_name-sol-advisor
mkdir -p "$checkout_script_dir" "$checkout_data"
checkout_codex_home=$(CDPATH= cd "$checkout_codex_home" && pwd)
checkout_data=$checkout_codex_home/plugins/data/$checkout_name-sol-advisor
checkout_data=$(CDPATH= cd "$checkout_data" && pwd)
cp "$script_dir/check-hook-trust.sh" "$checkout_script_dir/check-hook-trust.sh"
cp "$data_dir_resolver" "$checkout_script_dir/resolve-data-dir.sh"
cp "$ledger_report" "$checkout_script_dir/ledger-report.sh"
cp "$liveness_status" "$checkout_data/hook-status.json"
cp "$hook_ledger" "$checkout_data/review-budget.jsonl"
if ! active_output=$(env -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA CODEX_HOME="$checkout_codex_home" sh "$checkout_script_dir/check-hook-trust.sh"); then fail "checkout checker rejected the installed data directory"; fi
[ "$(printf '%s\n' "$active_output" | sed -n '1p')" = "HOOK ACTIVE" ] || fail "checkout checker output did not start with HOOK ACTIVE"
printf '%s\n' "$active_output" | grep -Fq "$checkout_data" || fail "checkout checker did not resolve the installed data directory"
if ! checkout_ledger_output=$(env -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA CODEX_HOME="$checkout_codex_home" sh "$checkout_script_dir/ledger-report.sh"); then fail "checkout ledger reporter rejected the installed data directory"; fi
checkout_checker_resolved=$(printf '%s\n' "$active_output" | sed -n 's/^Resolved data directory: //p')
checkout_report_resolved=$(printf '%s\n' "$checkout_ledger_output" | sed -n 's|^Resolved ledger: ||p' | sed 's|/review-budget.jsonl$||')
[ "$checkout_checker_resolved" = "$checkout_data" ] || fail "checkout checker resolved the wrong data directory"
[ "$checkout_report_resolved" = "$checkout_data" ] || fail "checkout ledger reporter resolved the wrong data directory"
pass "checkout-layout hook and ledger-report data-directory resolution"

fake_inert_script_dir=$tmp_dir/fake-inert/plugins/cache/mp/plug/9.9.9/scripts
fake_inert_data=$tmp_dir/fake-inert/plugins/data/mp-plug
fake_inert_codex_home=$tmp_dir/fake-inert-empty-codex-home
mkdir -p "$fake_inert_script_dir" "$fake_inert_data" "$fake_inert_codex_home"
fake_inert_data=$(CDPATH= cd "$fake_inert_data" && pwd)
cp "$script_dir/check-hook-trust.sh" "$fake_inert_script_dir/check-hook-trust.sh"
cp "$data_dir_resolver" "$fake_inert_script_dir/resolve-data-dir.sh"
before=$(snapshot_files "$fake_inert_data")
if inert_output=$(env -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA CODEX_HOME="$fake_inert_codex_home" sh "$fake_inert_script_dir/check-hook-trust.sh"); then fail "checker accepted a missing derived-path heartbeat"; fi
after=$(snapshot_files "$fake_inert_data")
[ "$before" = "$after" ] || fail "inert checker mutated the derived data directory"
[ "$(printf '%s\n' "$inert_output" | sed -n '1p')" = "HOOK INERT" ] || fail "missing derived-path output did not start with HOOK INERT"
printf '%s\n' "$inert_output" | grep -Fq "$fake_inert_data" || fail "inert output omitted the derived candidate"
printf '%s\n' "$inert_output" | grep -Fq "$fake_inert_codex_home/sol-advisor" || fail "inert output did not name more than one candidate"

override_data=$tmp_dir/hook-override
exported_data=$tmp_dir/hook-exported
mkdir "$override_data" "$exported_data"
cp "$liveness_status" "$override_data/hook-status.json"
if ! active_output=$(PLUGIN_DATA="$exported_data" sh "$script_dir/check-hook-trust.sh" --data-dir "$override_data"); then fail "--data-dir did not win over PLUGIN_DATA"; fi
[ "$(printf '%s\n' "$active_output" | sed -n '1p')" = "HOOK ACTIVE" ] || fail "--data-dir precedence output did not start with HOOK ACTIVE"
printf '%s\n' "$active_output" | grep -Fq "$override_data" || fail "--data-dir precedence output named the wrong data directory"
pass "hook liveness, derived data resolution, precedence, read-only behavior, and trust-checker outcomes"

routing_codex_home=$tmp_dir/routing-codex-home
routing_ledger=$routing_codex_home/sol-advisor/routing.jsonl
routing_record='{"ts":"2026-08-05T10:00:00+09:00","task":"fixture","class":"implement","lane":"sol_advisor_terra_implementer","exception":null,"outcome":"success","attempts":1,"duration_s":1,"note":""}'
if ! env -u PLUGIN_DATA -u CLAUDE_PLUGIN_DATA CODEX_HOME="$routing_codex_home" sh -c '
  mkdir -p "${CODEX_HOME:-$HOME/.codex}/sol-advisor"
  printf "%s\\n" "$1" >> "${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl"
' sh "$routing_record"; then fail "documented routing-ledger first-use sequence failed"; fi
test -d "$routing_codex_home/sol-advisor" || fail "routing-ledger first-use sequence did not create its parent"
jq -s -e --argjson record "$routing_record" 'length == 1 and .[0] == $record' "$routing_ledger" >/dev/null || fail "routing-ledger first-use sequence did not write one valid record"
pass "routing-ledger first-use sequence creates its parent and writes one record"

python3 - "$templates" <<'PY'
from pathlib import Path
import sys, tomllib

root = Path(sys.argv[1])
expected = {
    "sol-advisor-luna-implementer.toml": {
        "name": "sol_advisor_luna_implementer",
        "model": "gpt-5.6-luna",
        "model_reasoning_effort": "max",
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
cmp -s "$templates/sol-advisor-luna-implementer.toml" "$clean_target/sol-advisor-luna-implementer.toml" || fail "clean Implementer install mismatch"
cmp -s "$templates/$sol_file" "$clean_target/$sol_file" || fail "clean Sol install mismatch"
cmp -s "$templates/$floor_file" "$clean_target/$floor_file" || fail "clean floor-lane install mismatch"
test ! -e "$clean_target/$terra_file" || fail "clean install created retired Terra role"
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
cmp -s "$templates/sol-advisor-luna-implementer.toml" "$codex_home/agents/sol-advisor-luna-implementer.toml" || fail "CODEX_HOME Implementer mismatch"
cmp -s "$templates/$sol_file" "$codex_home/agents/$sol_file" || fail "CODEX_HOME Sol mismatch"
cmp -s "$templates/$floor_file" "$codex_home/agents/$floor_file" || fail "CODEX_HOME floor-lane mismatch"
test ! -e "$codex_home/config.toml" || fail "installer created config.toml"
relative_parent=$tmp_dir/relative-parent
mkdir "$relative_parent"
(cd "$relative_parent" && sh "$installer" --target-dir relative-agents)
cmp -s "$templates/sol-advisor-luna-implementer.toml" "$relative_parent/relative-agents/sol-advisor-luna-implementer.toml" || fail "relative target Implementer mismatch"
pass "CODEX_HOME and relative target behavior"

migration_target=$tmp_dir/migration
write_legacy_roles "$migration_target"
sh "$installer" --target-dir "$migration_target"
cmp -s "$templates/sol-advisor-luna-implementer.toml" "$migration_target/sol-advisor-luna-implementer.toml" || fail "current Implementer was not installed"
cmp -s "$templates/$sol_file" "$migration_target/$sol_file" || fail "Sol changed during migration"
test ! -e "$migration_target/$luna_file" || fail "exact legacy Luna was not removed"
sh "$installer" --target-dir "$migration_target" --check
pass "migration to Luna/Max implementer with v0.2.0 legacy cleanup"

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

modified_terra=$tmp_dir/modified-terra
write_legacy_roles "$modified_terra"
printf '%s\n' modified >> "$modified_terra/$terra_file"
before=$(snapshot_files "$modified_terra")
if sh "$installer" --target-dir "$modified_terra"; then fail "installer replaced modified Terra"; fi
after=$(snapshot_files "$modified_terra")
[ "$before" = "$after" ] || fail "modified-Terra refusal partially mutated target"
pass "modified Terra refusal with zero partial mutation"

stale_terra=$tmp_dir/stale-terra
sh "$installer" --target-dir "$stale_terra"
stale_fixture=$tmp_dir/stale-fixture
write_legacy_roles "$stale_fixture"
cp "$stale_fixture/$terra_file" "$stale_terra/$terra_file"
before=$(snapshot_files "$stale_terra")
if sh "$installer" --target-dir "$stale_terra" --check; then fail "--check accepted stale Terra"; fi
after=$(snapshot_files "$stale_terra")
[ "$before" = "$after" ] || fail "stale-Terra check mutated target"
pass "stale Terra check refusal is non-mutating"

unsafe=$tmp_dir/unsafe
mkdir "$unsafe"
ln -s "$templates/sol-advisor-luna-implementer.toml" "$unsafe/sol-advisor-luna-implementer.toml"
before=$(snapshot_files "$unsafe")
if sh "$installer" --target-dir "$unsafe"; then fail "installer accepted symlinked Implementer"; fi
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
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_luna_implementer\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"max","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture"}}' \
  > "$runtime_rollout"
runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$runtime_id")
printf '%s\n' "$runtime_output" | jq -e --arg id "$runtime_id" '
  .thread_id == $id and .agent_role == "sol_advisor_luna_implementer"
  and .model == "gpt-5.6-luna" and .effort == "max"
  and .sandbox_policy_type == "danger-full-access"
  and .permission_profile_type == "disabled"
' >/dev/null || fail "runtime inspector returned wrong Luna/Max evidence"
if printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK; then fail "runtime inspector leaked payload"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" invalid >/dev/null 2>&1; then fail "runtime inspector accepted invalid id"; fi
zero_id=22222222-2222-7222-8222-222222222222
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$zero_id" >/dev/null 2>&1; then fail "runtime inspector accepted zero matches"; fi
pass "runtime inspector Luna/Max routing and safe refusal"

for document in "$skill" "$contracts"; do
  grep -Fq 'agent_type: sol_advisor_luna_implementer' "$document" || fail "missing Implementer spawn in $document"
  grep -Fq 'agent_type: sol_advisor_sol_reviewer' "$document" || fail "missing Sol spawn in $document"
  grep -Fq 'agent_type: sol_advisor_luna_committer' "$document" || fail "missing floor-lane spawn in $document"
  grep -Fq 'fork_turns: none' "$document" || fail "missing fresh context in $document"
  if grep -Eq 'agent_type:.*terra_implementer' "$document"; then fail "retired Terra implementer spawn remains in $document"; fi
  if grep -Eq '^[[:space:]]*(model|reasoning_effort):' "$document"; then fail "per-spawn override remains in $document"; fi
done
grep -Fq '../../scripts/install-agents.sh' "$preflight" || fail "preflight does not resolve installer relatively"
grep -Fq '../../scripts/inspect-agent-runtime.sh' "$preflight" || fail "preflight does not resolve inspector relatively"
grep -Fqi 'public native spawn/details metadata first' "$preflight" || fail "preflight lacks public-details-first evidence rule"
grep -Fqi 'parent captures and verifies exact before-and-after' "$contracts" || fail "contracts lack behavioral read-only state check"
if rg -n 'sol_advisor_terra_implementer|sol-advisor-terra-implementer' "$readme" "$plugin_dir" | grep -Fqv 'legacy\|retired'; then fail "unreferred Terra implementer remains in docs"; fi
pass "three-lane documentation and no per-spawn overrides"

grep -Fq 'COMMITMENT BOUNDARY' "$review_hook" || fail "hook no longer recognizes the consult exemption marker"
if grep -Fq 'REVIEW CYCLE' "$review_hook"; then fail "hook still gates the budget on a marker the final review must remember"; fi
for document in "$skill" "$contracts" "$readme"; do
  grep -Fq 'COMMITMENT BOUNDARY' "$document" || fail "consult exemption marker is undocumented in $document"
done
grep -Fq 'routing.jsonl' "$skill" || fail "skill is missing the routing ledger"
grep -Fq 'sol-advisor/routing.jsonl' "$readme" || fail "README does not point at the routing ledger"
if grep -Fq 'Resets outnumber deliverables' "$ledger_report"; then fail "ledger report retains the unreachable reset comparison"; fi
pass "inverted marker contract and routing ledger documentation"
grep -Fq 'sol_advisor_luna_committer' "$preflight" || fail "preflight is missing sol_advisor_luna_committer"
for role in sol_advisor_luna_implementer sol_advisor_sol_reviewer sol_advisor_luna_committer; do
  grep -Fq "$role" "$preflight" || fail "preflight is missing required role: $role"
done
if grep -Fq 'The two role files' "$preflight"; then fail "preflight retains retired two-lane role-file wording"; fi
pass "preflight three required role names and retired two-lane wording absence"

sh -n "$installer"
sh -n "$runtime_inspector"
sh -n "$script_dir/check-hook-trust.sh"
sh -n "$data_dir_resolver"
sh -n "$ledger_report"
sh -n "$script_dir/verify.sh"
pass "shell syntax"

printf '%s\n' "VERIFY PASSED: Sol Advisor three-role migration checks completed in $tmp_dir"
