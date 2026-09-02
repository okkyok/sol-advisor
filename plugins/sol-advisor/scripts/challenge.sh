#!/bin/sh

set -eu

usage() {
  printf '%s\n' "Usage: $0 [--packet FILE]" >&2
}

packet_arg=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --packet)
      if [ "$#" -ne 2 ] || [ -z "$2" ] || [ -n "$packet_arg" ]; then
        usage
        exit 2
      fi
      packet_arg=$2
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

work_dir=
cleanup() {
  if [ -n "$work_dir" ] && [ -d "$work_dir" ]; then
    rm -rf "$work_dir" || :
  fi
}
trap cleanup 0 HUP INT TERM

if ! work_dir=$(mktemp -d "${TMPDIR:-/tmp}/sol-advisor-challenge.XXXXXX"); then
  printf '%s\n' 'CHALLENGER UNAVAILABLE: could not create a temporary directory' >&2
  exit 1
fi

if [ -n "$packet_arg" ]; then
  packet_file=$packet_arg
  if [ ! -r "$packet_file" ]; then
    printf '%s\n' 'CHALLENGER UNAVAILABLE: packet file is not readable' >&2
    exit 1
  fi
else
  packet_file=$work_dir/packet
  if ! cat > "$packet_file"; then
    printf '%s\n' 'CHALLENGER UNAVAILABLE: could not read packet from stdin' >&2
    exit 1
  fi
fi

if ! first_line=$(sed -n '1p' "$packet_file"); then
  printf '%s\n' 'CHALLENGER UNAVAILABLE: could not read packet' >&2
  exit 1
fi

case "$first_line" in
  'TRIGGER: deadlock')
    trigger=deadlock
    ;;
  'TRIGGER: irreversible')
    trigger=irreversible
    ;;
  'TRIGGER: user-request')
    trigger=user-request
    ;;
  *)
    printf '%s\n' 'CHALLENGER REFUSED: first line must be exactly one of: TRIGGER: deadlock, TRIGGER: irreversible, TRIGGER: user-request' >&2
    exit 1
    ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' 'CHALLENGER UNAVAILABLE: python3 not found' >&2
  exit 1
fi

system_prompt='You are an external challenger from a different model family than both the orchestrator and every implementation lane in this workflow. That difference is the entire reason you were called. You have no repository access. Judge only what the packet contains; do not ask for tools or file access. Return exactly one of agree, challenge, or blocked-risk, plus the one decisive reason and the single largest risk. Use blocked-risk when the packet is insufficient to judge, and name exactly what is missing. Stay under 300 words; the reader is another model mid-task. If the decision or change set is sound, answer agree in one line. Never manufacture disagreement just to justify having been consulted. You advise. You never implement, and you never write or propose a patch.'

response_file=$work_dir/response.json
metadata_dir=$work_dir/metadata
mkdir "$metadata_dir"

availability_message=
claude_status=127
if command -v claude >/dev/null 2>&1; then
  if cat "$packet_file" | claude -p --model opus --output-format json --strict-mcp-config --system-prompt "$system_prompt" --disallowedTools "Write" "Edit" "NotebookEdit" "Bash" > "$response_file"; then
    claude_status=0
  else
    claude_status=$?
  fi
else
  availability_message='CHALLENGER UNAVAILABLE: claude CLI not found'
fi

metadata_ready=0
is_error=0
api_error_present=0
result_ok=0
has_opus=0
model=unknown
cost_json=null

if [ -z "$availability_message" ]; then
  if python3 -c 'import json, math, sys
from pathlib import Path


response = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(response, dict):
    raise ValueError("response is not an object")
metadata_dir = Path(sys.argv[2])
model_usage = response.get("modelUsage")
model_ids = list(model_usage) if isinstance(model_usage, dict) else []
cost = response.get("total_cost_usd")
if not isinstance(cost, (int, float)) or isinstance(cost, bool) or not math.isfinite(cost):
    cost = None
(metadata_dir / "is_error").write_text("1" if response.get("is_error") is True else "0", encoding="utf-8")
(metadata_dir / "api_error_present").write_text("1" if response.get("api_error_status") is not None else "0", encoding="utf-8")
(metadata_dir / "result_ok").write_text("1" if isinstance(response.get("result"), str) else "0", encoding="utf-8")
(metadata_dir / "has_opus").write_text("1" if "claude-opus-5" in model_ids else "0", encoding="utf-8")
(metadata_dir / "models").write_text(", ".join(model_ids) if model_ids else "", encoding="utf-8")
(metadata_dir / "cost").write_text(json.dumps(cost, separators=(",", ":")), encoding="utf-8")' "$response_file" "$metadata_dir" 2>/dev/null; then
    metadata_ready=1
  fi
fi

if [ "$metadata_ready" -eq 1 ]; then
  is_error=$(cat "$metadata_dir/is_error")
  api_error_present=$(cat "$metadata_dir/api_error_present")
  result_ok=$(cat "$metadata_dir/result_ok")
  has_opus=$(cat "$metadata_dir/has_opus")
  model_ids=$(cat "$metadata_dir/models")
  cost_json=$(cat "$metadata_dir/cost")
  if [ -n "$model_ids" ]; then
    model=$model_ids
  fi
fi

outcome=unavailable
degraded=false
note=
if [ -n "$availability_message" ]; then
  note='claude CLI not found'
elif [ "$claude_status" -ne 0 ]; then
  note="claude exited with status $claude_status"
elif [ "$metadata_ready" -ne 1 ]; then
  note='invalid JSON response'
elif [ "$is_error" -eq 1 ]; then
  note='claude reported an error'
elif [ "$api_error_present" -eq 1 ]; then
  note='claude API error status was reported'
elif [ "$result_ok" -ne 1 ]; then
  note='claude response had no result text'
elif [ "$has_opus" -eq 1 ]; then
  outcome=ok
else
  outcome=degraded
  degraded=true
  note='modelUsage did not include claude-opus-5'
fi

ledger_dir=${CODEX_HOME:-$HOME/.codex}/sol-advisor
ledger_path=$ledger_dir/challenger.jsonl
if ! mkdir -p "$ledger_dir"; then
  printf '%s\n' "CHALLENGER LEDGER WRITE FAILED: could not create $ledger_dir" >&2
elif ! python3 -c 'import datetime, json, sys
from pathlib import Path


ledger_path = Path(sys.argv[1])
cost = json.loads(sys.argv[5])
record = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "trigger": sys.argv[2],
    "model": sys.argv[3],
    "degraded": sys.argv[4] == "true",
    "cost_usd": cost,
    "outcome": sys.argv[6],
    "note": sys.argv[7],
}
with ledger_path.open("a", encoding="utf-8") as ledger:
    print(json.dumps(record, ensure_ascii=False, separators=(",", ":")), file=ledger)' "$ledger_path" "$trigger" "$model" "$degraded" "$cost_json" "$outcome" "$note"; then
  printf '%s\n' "CHALLENGER LEDGER WRITE FAILED: could not append $ledger_path" >&2
fi

if [ -n "$availability_message" ]; then
  printf '%s\n' "$availability_message" >&2
  exit 1
fi
if [ "$outcome" = unavailable ]; then
  printf '%s\n' "CHALLENGER UNAVAILABLE: $note" >&2
  exit 1
fi
if [ "$outcome" = degraded ]; then
  printf '%s\n' "CHALLENGER DEGRADED: $model" >&2
fi

python3 -c 'import json, sys
from pathlib import Path


response = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
sys.stdout.write(response["result"])' "$response_file"
