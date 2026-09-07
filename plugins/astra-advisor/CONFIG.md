# Recommended Codex settings for Astra Advisor

Use these settings only if your Codex build exposes the same Multi-Agent V2 configuration keys. If a key is unavailable in your installed version, omit it rather than inventing an equivalent.

```toml
[features.multi_agent_v2]
enabled = true

# Astra parent + up to three concurrent children.
max_concurrent_threads_per_session = 4

# Avoid tight polling. Completion events should wake the parent before these deadlines.
min_wait_timeout_ms = 120000
default_wait_timeout_ms = 600000
max_wait_timeout_ms = 1500000

# Keep delegated workers as leaf workers by default.
subagent_developer_instructions = """
Complete only the bounded task assigned by the parent.
Do not spawn additional subagents unless the parent explicitly authorizes nested delegation for this task.
Do not broaden scope or modify unrelated files.
Return concise changes, verification evidence, blockers, and remaining uncertainty.
"""
```

## Why these defaults

- `4` threads means one Astra parent plus up to three children: enough useful width without uncontrolled fan-out.
- The default wait is 10 minutes, not a short polling loop. A child completion event should return control earlier.
- The 25-minute maximum is a deadline, not a forced sleep.
- The Skill still asks Astra to choose `max(5 minutes, about 2x remaining duration)` when per-wait timeout controls are available.
- `fork_turns: none` is handled per spawn by the Skill because it is a routing decision, not a global assumption.

Do not globally force every child to Luna or any fixed model. Astra Advisor selects model and reasoning effort from task difficulty and the controls actually exposed by the runtime.
