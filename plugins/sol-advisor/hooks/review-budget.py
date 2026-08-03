import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import sys


def main():
    try:
        payload = json.loads(sys.stdin.read())

        # This hook deliberately has no matcher in hooks.json. Narrowing it to
        # spawn_agent would hide the heartbeat from ordinary shell commands and
        # destroy the liveness check.
        try:
            data_dir = os.environ.get("PLUGIN_DATA") or os.environ.get(
                "CLAUDE_PLUGIN_DATA"
            )
            if not data_dir:
                codex_home = os.environ.get("CODEX_HOME")
                if not codex_home:
                    codex_home = os.path.join(os.environ["HOME"], ".codex")
                data_dir = os.path.join(codex_home, "sol-advisor")
            heartbeat_path = Path(os.path.abspath(data_dir)) / "hook-status.json"
            heartbeat_path.parent.mkdir(parents=True, exist_ok=True)
            heartbeat_temp = heartbeat_path.with_name(
                f"{heartbeat_path.name}.{os.getpid()}.tmp"
            )
            heartbeat = {
                "ts": datetime.datetime.now(datetime.timezone.utc)
                .isoformat()
                .replace("+00:00", "Z"),
                "session_id": payload.get("session_id"),
                "plugin_version": "0.6.2",
            }
            tool_input_text = json.dumps(
                payload.get("tool_input"), separators=(",", ":"), ensure_ascii=False
            )
            nonce_match = re.search(
                r"--nonce[ =]+([A-Za-z0-9_.:-]{4,64})", tool_input_text
            )
            if nonce_match:
                heartbeat["nonce"] = nonce_match.group(1)
            heartbeat_temp.write_text(
                json.dumps(heartbeat, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
            os.replace(heartbeat_temp, heartbeat_path)
        except BaseException:
            pass

        if payload.get("hook_event_name") != "PreToolUse":
            return
        if payload.get("tool_name") != "spawn_agent":
            return

        tool_input = payload.get("tool_input")
        if not isinstance(tool_input, dict):
            return
        if tool_input.get("agent_type") != "sol_advisor_sol_reviewer":
            return

        message = tool_input.get("message", "")
        if not isinstance(message, str) or "REVIEW CYCLE" not in message:
            return

        data_dir = os.environ.get("PLUGIN_DATA") or os.environ.get("CLAUDE_PLUGIN_DATA")
        if not data_dir:
            codex_home = os.environ.get("CODEX_HOME")
            if not codex_home:
                codex_home = os.path.join(os.environ["HOME"], ".codex")
            data_dir = os.path.join(codex_home, "sol-advisor")
        ledger_path = Path(os.path.abspath(data_dir)) / "review-budget.jsonl"
        ledger_path.parent.mkdir(parents=True, exist_ok=True)

        session_id = payload.get("session_id")
        with ledger_path.open("a+", encoding="utf-8", errors="replace") as ledger:
            fcntl.flock(ledger.fileno(), fcntl.LOCK_EX)
            ledger.seek(0)
            contents = ledger.read()
            session_records = []
            for line in contents.splitlines():
                try:
                    record = json.loads(line)
                except (TypeError, ValueError):
                    continue
                if isinstance(record, dict) and record.get("session_id") == session_id:
                    session_records.append(record)

            last_reset = -1
            for index, record in enumerate(session_records):
                if record.get("event") == "new-deliverable":
                    last_reset = index
            count = sum(
                record.get("event") == "review"
                for record in session_records[last_reset + 1 :]
            )

            if count >= 3:
                reset_record = json.dumps(
                    {"event": "new-deliverable", "session_id": session_id},
                    separators=(",", ":"),
                )
                newline_escape = "\\n"
                reset_command = (
                    f"printf {shlex.quote(reset_record + newline_escape)} >> "
                    f"{shlex.quote(str(ledger_path))}"
                )
                reason = (
                    "The review budget of 3 final reviews for this deliverable is "
                    "exhausted; stop and hand the unresolved findings, the current diff, "
                    "the verification evidence, and the options back to the user rather "
                    "than spawning another reviewer. The ledger is "
                    f"{ledger_path}. A genuinely new deliverable in the same session "
                    "requires appending a new-deliverable record with the documented "
                    "command, which is recorded and auditable: "
                    f"{reset_command}"
                )
                try:
                    ledger.seek(0, os.SEEK_END)
                    if contents and not contents.endswith(("\n", "\r")):
                        ledger.write("\n")
                    denied_record = {
                        "ts": datetime.datetime.now(datetime.timezone.utc)
                        .isoformat()
                        .replace("+00:00", "Z"),
                        "event": "denied",
                        "session_id": session_id,
                        "cwd": payload.get("cwd", ""),
                        "cycle": count + 1,
                    }
                    ledger.write(
                        json.dumps(denied_record, separators=(",", ":")) + "\n"
                    )
                    ledger.flush()
                except BaseException:
                    pass
                print(
                    json.dumps(
                        {
                            "hookSpecificOutput": {
                                "hookEventName": "PreToolUse",
                                "permissionDecision": "deny",
                                "permissionDecisionReason": reason,
                            }
                        },
                        separators=(",", ":"),
                    )
                )
                return

            ledger.seek(0, os.SEEK_END)
            if contents and not contents.endswith(("\n", "\r")):
                ledger.write("\n")
            record = {
                "ts": datetime.datetime.now(datetime.timezone.utc)
                .isoformat()
                .replace("+00:00", "Z"),
                "event": "review",
                "session_id": session_id,
                "cwd": payload.get("cwd", ""),
                "cycle": count + 1,
            }
            ledger.write(json.dumps(record, separators=(",", ":")) + "\n")
            ledger.flush()
    except BaseException:
        return


if __name__ == "__main__":
    main()
