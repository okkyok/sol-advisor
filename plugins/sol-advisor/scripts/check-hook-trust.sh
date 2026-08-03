#!/bin/sh

usage() {
  printf '%s\n' "Usage: $0 [--data-dir PATH]" >&2
}

data_dir=
case "$#" in
  0)
    ;;
  2)
    if [ "$1" != "--data-dir" ] || [ -z "$2" ]; then
      usage
      exit 2
    fi
    data_dir=$2
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [ -z "$data_dir" ]; then
  if [ -n "${PLUGIN_DATA:-}" ]; then
    data_dir=$PLUGIN_DATA
  elif [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    data_dir=$CLAUDE_PLUGIN_DATA
  else
    data_dir=${CODEX_HOME:-$HOME/.codex}/sol-advisor
  fi
fi

status_file=$data_dir/hook-status.json
if [ ! -f "$status_file" ]; then
  printf '%s\n' \
    'HOOK INERT' \
    "The plugin's hooks are not running in this session: no heartbeat file was found." \
    "The review budget is therefore NOT enforced; only the architect's discipline bounds the review loop." \
    'The cause is almost always ungranted hook trust.' \
    "Approve the plugin's hooks in the interactive Codex UI and start a fresh task."
  exit 1
fi

python3 - "$status_file" <<'PY'
import datetime
import json
from pathlib import Path
import sys


status_file = Path(sys.argv[1])


def inert_common():
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
    print(f"The heartbeat file was unreadable or malformed: {status_file}")
    inert_common()
    raise SystemExit(1)

age = (datetime.datetime.now(datetime.timezone.utc) - parsed).total_seconds()
if age > 60:
    print("HOOK INERT")
    print(f"A stale hook heartbeat was found: {timestamp}")
    print("The hook did not fire for this invocation, so the plugin's hooks are not running in this session.")
    inert_common()
    raise SystemExit(1)

print("HOOK ACTIVE")
print(f"Heartbeat timestamp: {timestamp}")
print(f"Session id: {session_id}")
print(f"Plugin version: {plugin_version}")
print("Confirm that the session id above is the id of the session running this check.")
PY
