#!/bin/sh

usage() {
  printf '%s\n' "Usage: $0 [--data-dir PATH] [--nonce TOKEN]" >&2
}

data_dir_override=
nonce=
data_dir_seen=0
nonce_seen=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --data-dir)
      if [ "$data_dir_seen" -eq 1 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        usage
        exit 2
      fi
      data_dir_override=$2
      data_dir_seen=1
      shift 2
      ;;
    --nonce)
      if [ "$nonce_seen" -eq 1 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        usage
        exit 2
      fi
      nonce=$2
      nonce_seen=1
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [ "$nonce_seen" -eq 1 ]; then
  nonce_length=${#nonce}
  case "$nonce" in
    *[!A-Za-z0-9_.:-]*)
      usage
      exit 2
      ;;
  esac
  if [ "$nonce_length" -lt 4 ] || [ "$nonce_length" -gt 64 ]; then
    usage
    exit 2
  fi
fi

if ! script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd); then
  printf '%s\n' 'HOOK INERT' 'Could not resolve the checker script directory.'
  exit 1
fi
. "$script_dir/resolve-data-dir.sh"
resolve_data_dir "$data_dir_override" hook-status.json
data_dir=$resolved_data_dir
checked_count=$resolved_data_candidate_count

print_checked_candidates() {
  if [ "$checked_count" -le 1 ]; then
    return
  fi

  printf '%s\n' 'Checked candidate data directories:'
  printf '%s\n' "$resolved_data_candidates" | while IFS= read -r candidate; do
    printf '  %s\n' "$candidate"
  done
}

status_file=$data_dir/hook-status.json
if [ ! -r "$status_file" ]; then
  printf '%s\n' \
    'HOOK INERT' \
    "Resolved data directory: $data_dir" \
    'No hook is running in this session: no readable heartbeat file was found.'
  print_checked_candidates
  printf '%s\n' \
    'The review budget is therefore NOT enforced; only your own discipline bounds the review loop.' \
    'The cause is almost always ungranted hook trust.' \
    'Approve this plugin at the interactive Codex hook-trust prompt, then start a fresh task.'
  exit 1
fi

python3 -c 'import datetime
import json
from pathlib import Path
import sys


status_file = Path(sys.argv[1])
data_dir = sys.argv[2]
nonce = sys.argv[3]
checked_candidates = sys.argv[4].splitlines()


def inert_common():
    if len(checked_candidates) > 1:
        print("Checked candidate data directories:")
        for candidate in checked_candidates:
            print(f"  {candidate}")
    print("The review budget is therefore NOT enforced; only your own discipline bounds the review loop.")
    print("The cause is almost always ungranted hook trust.")
    print("Approve this plugin at the interactive Codex hook-trust prompt, then start a fresh task.")


try:
    heartbeat = json.loads(status_file.read_text(encoding="utf-8"))
    if not isinstance(heartbeat, dict):
        raise ValueError("heartbeat is not an object")
    timestamp = heartbeat["ts"]
    session_id = heartbeat["session_id"]
    plugin_version = heartbeat["plugin_version"]
    if not all(isinstance(value, str) for value in (timestamp, session_id, plugin_version)):
        raise ValueError("heartbeat fields are not strings")
    parsed = datetime.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("heartbeat timestamp has no timezone")
except Exception:
    print("HOOK INERT")
    print(f"Resolved data directory: {data_dir}")
    print(f"The heartbeat file was unreadable or malformed: {status_file}")
    inert_common()
    raise SystemExit(1)

age = (datetime.datetime.now(datetime.timezone.utc) - parsed).total_seconds()
if age > 60:
    print("HOOK INERT")
    print(f"Resolved data directory: {data_dir}")
    print(f"A stale hook heartbeat was found: {timestamp}")
    print("The hook did not fire for this invocation, so no hook is running in this session.")
    inert_common()
    raise SystemExit(1)

if nonce and heartbeat.get("nonce") != nonce:
    print("HOOK INERT")
    print(f"Resolved data directory: {data_dir}")
    print("The hook did not observe this invocation; either it is not running, or the heartbeat came from a different session or command.")
    inert_common()
    raise SystemExit(1)

print("HOOK ACTIVE")
print(f"Resolved data directory: {data_dir}")
print(f"Heartbeat timestamp: {timestamp}")
print(f"Session id: {session_id}")
print(f"Plugin version: {plugin_version}")
print("Confirm that the session id above is the id of the session running this check.")
if nonce:
    print("This heartbeat was produced by this invocation, so the result cannot come from a concurrent session.")
else:
    print("This result is unverified because no nonce was supplied; a concurrent trusted session could produce the same output.")' "$status_file" "$data_dir" "$nonce" "$resolved_data_candidates"
