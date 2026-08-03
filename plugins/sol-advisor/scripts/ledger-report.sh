#!/bin/sh

usage() {
  printf '%s\n' "Usage: $0 [--data-dir PATH]" >&2
}

data_dir_override=
case "$#" in
  0)
    ;;
  2)
    if [ "$1" != "--data-dir" ] || [ -z "$2" ]; then
      usage
      exit 2
    fi
    data_dir_override=$2
    ;;
  *)
    usage
    exit 2
    ;;
esac

if ! script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd); then
  printf '%s\n' 'Could not resolve the report script directory.' >&2
  exit 1
fi
. "$script_dir/resolve-data-dir.sh"
resolve_data_dir "$data_dir_override" review-budget.jsonl
data_dir=$resolved_data_dir
ledger_path=$data_dir/review-budget.jsonl

if [ "$resolved_data_file_found" -eq 0 ]; then
  printf 'no ledger found at %s\n' "$ledger_path"
  printf '%s\n' 'Checked candidate data directories:'
  printf '%s\n' "$resolved_data_candidates" | while IFS= read -r candidate; do
    printf '  %s\n' "$candidate"
  done
  exit 0
fi

python3 -c 'import json
from pathlib import Path
import sys


ledger_path = Path(sys.argv[1])
records = []
for line in ledger_path.read_text(encoding="utf-8", errors="replace").splitlines():
    try:
        record = json.loads(line)
    except (TypeError, ValueError):
        continue
    if isinstance(record, dict):
        records.append(record)

deliverables_by_session = {}
session_order = []
reset_count = 0
reset_sessions = set()
for record in records:
    session_id = record.get("session_id")
    session_key = json.dumps(session_id, sort_keys=True, separators=(",", ":"))
    event = record.get("event")
    if session_key not in deliverables_by_session:
        deliverables_by_session[session_key] = [[]]
        session_order.append(session_key)
    elif event == "new-deliverable":
        deliverables_by_session[session_key].append([])
    deliverables_by_session[session_key][-1].append(record)
    if event == "new-deliverable":
        reset_count += 1
        reset_sessions.add(session_key)

deliverables = [
    deliverable
    for session_key in session_order
    for deliverable in deliverables_by_session[session_key]
]
cycles = [
    sum(record.get("event") == "review" for record in deliverable)
    for deliverable in deliverables
]
cap_hits = sum(
    any(record.get("event") == "denied" for record in deliverable)
    for deliverable in deliverables
)
deliverable_count = len(deliverables)
cap_rate = 100.0 * cap_hits / deliverable_count if deliverable_count else 0.0

print(f"Resolved ledger: {ledger_path}")
print(f"Total records: {len(records)}")
print(f"Deliverables: {deliverable_count}")
print(f"Cycles used: 1 cycle={cycles.count(1)}, 2 cycles={cycles.count(2)}, 3 cycles={cycles.count(3)}")
print(f"Deliverables that hit the cap: {cap_hits} ({cap_rate:.1f}%)")
print(f"New-deliverable records: {reset_count} from {len(reset_sessions)} distinct session_ids")
print("Verdict:")
if not records:
    print("- No data yet, the budget has never been exercised.")
else:
    warned = False
    if cap_rate > 25.0:
        print("- The cap-hit rate is above 25%; scope freezing is not working and the finding set keeps growing.")
        warned = True
    if reset_count > deliverable_count:
        print("- Resets outnumber deliverables; the budget is being routed around rather than respected.")
        warned = True
    if not warned:
        print("- The ledger does not show either budget warning condition.")' "$ledger_path"
