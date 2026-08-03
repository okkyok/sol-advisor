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

set --
if [ -n "$data_dir_override" ]; then
  set -- "$@" "$data_dir_override"
fi
if [ -n "${PLUGIN_DATA:-}" ]; then
  set -- "$@" "$PLUGIN_DATA"
fi
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  set -- "$@" "$CLAUDE_PLUGIN_DATA"
fi

if script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd); then
  plugin_root=$(dirname "$script_dir")
  plugin_dir=$(dirname "$plugin_root")
  marketplace_dir=$(dirname "$plugin_dir")
  cache_root=$(dirname "$marketplace_dir")
  plugins_root=$(dirname "$cache_root")
  if [ "$(basename "$plugins_root")" = plugins ]; then
    plugin_name=$(basename "$plugin_dir")
    marketplace=$(basename "$marketplace_dir")
    set -- "$@" "$plugins_root/data/$marketplace-$plugin_name"
  fi
fi

set -- "$@" "${CODEX_HOME:-$HOME/.codex}/sol-advisor"

data_dir=$1
checked_count=0
for candidate do
  checked_count=$((checked_count + 1))
  if [ -r "$candidate/hook-status.json" ]; then
    data_dir=$candidate
    break
  fi
done

print_checked_candidates() {
  limit=$1
  shift
  if [ "$limit" -le 1 ]; then
    return
  fi

  printf '%s\n' 'Checked candidate data directories:'
  shown=0
  for candidate do
    if [ "$shown" -ge "$limit" ]; then
      break
    fi
    printf '  %s\n' "$candidate"
    shown=$((shown + 1))
  done
}

status_file=$data_dir/hook-status.json
if [ ! -r "$status_file" ]; then
  printf '%s\n' \
    'HOOK INERT' \
    "Resolved data directory: $data_dir" \
    "The plugin's hooks are not running in this session: no readable heartbeat file was found."
  print_checked_candidates "$checked_count" "$@"
  printf '%s\n' \
    "The review budget is therefore NOT enforced; only the architect's discipline bounds the review loop." \
    'The cause is almost always ungranted hook trust.' \
    "Approve the plugin's hooks in the interactive Codex UI and start a fresh task."
  exit 1
fi

python3 - "$status_file" "$data_dir" "$checked_count" "$@" <<'PY'
import datetime
import json
from pathlib import Path
import sys


status_file = Path(sys.argv[1])
data_dir = sys.argv[2]
checked_count = int(sys.argv[3])
checked_candidates = sys.argv[4:4 + checked_count]


def inert_common():
    if len(checked_candidates) > 1:
        print("Checked candidate data directories:")
        for candidate in checked_candidates:
            print(f"  {candidate}")
    print("The review budget is therefore NOT enforced; only the architect's discipline bounds the review loop.")
    print("The cause is almost always ungranted hook trust.")
    print("Approve the plugin's hooks in the interactive Codex UI and start a fresh task.")


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
    print("The hook did not fire for this invocation, so the plugin's hooks are not running in this session.")
    inert_common()
    raise SystemExit(1)

print("HOOK ACTIVE")
print(f"Resolved data directory: {data_dir}")
print(f"Heartbeat timestamp: {timestamp}")
print(f"Session id: {session_id}")
print(f"Plugin version: {plugin_version}")
print("Confirm that the session id above is the id of the session running this check.")
PY
