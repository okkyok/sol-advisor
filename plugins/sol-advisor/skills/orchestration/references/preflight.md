# Preflight the companion custom agents

Complete this preflight before the first delegation in a session and before accepting
any lane's result. These are the same checks [SKILL.md](../SKILL.md) points to;
nothing here supersedes it.

The three role files are user-owned native custom-agent TOML files. Installing or
updating the plugin does not automatically register them. Install them separately and
start a fresh Codex task so native discovery sees the current profiles.

Complete step 1 once per session. Before every delegation, complete steps 2-3. After
spawning a lane, complete steps 4-5 before accepting its result:

1. Verify that hook enforcement is live before relying on it, by running:

   ~~~sh
   references_dir=<directory-containing-this-file>
   checker="$references_dir/../../../scripts/check-hook-trust.sh"
   sh "$checker"
   ~~~

   `HOOK ACTIVE` means the review budget is enforced by the host; confirm the printed
   session id matches the current session. `HOOK INERT` does not stop the lane -- the
   workflow still runs -- but the architect must say so plainly in its final report:
   the review budget was not machine-enforced during this deliverable, and the loop was
   bounded only by the architect's own discipline. Never claim an enforced budget
   without a fresh `HOOK ACTIVE`.

2. Resolve `../../../scripts/install-agents.sh` relative to this file and run its
   non-mutating exactness check:

   ~~~sh
   references_dir=<directory-containing-this-file>
   installer="$references_dir/../../../scripts/install-agents.sh"
   sh "$installer" --check
   ~~~

   It must exit zero. This proves Terra, Sol, and the Luna floor lane match the
   shipped templates exactly and the retired Luna companion file is absent. If the
   check reports a missing, stale, unsafe, or conflicting file, stop the affected
   lane. Give the user the installer path and reported destination. Never work
   around failure with another agent, model, or effort.

3. Inspect the native spawn tool's available `agent_type` entries. All three exact
   names must be exposed:

   - `sol_advisor_terra_implementer`
   - `sol_advisor_sol_reviewer`
   - `sol_advisor_luna_committer`

   If any is missing, tell the user to install/check the companion files, start a
   fresh task, and update Codex if the name remains unavailable. Do not substitute a
   built-in or similarly named role.

4. Treat exact templates plus observed runtime routing as an acceptance gate.
   Inspect public native spawn/details metadata first. It must identify the selected
   custom role. When it exposes model or effort, compare them with the role pin.

   If public details omit model or effort and the local rollout is accessible, resolve
   `../../../scripts/inspect-agent-runtime.sh` relative to this file and run:

   ~~~sh
   references_dir=<directory-containing-this-file>
   runtime_inspector="$references_dir/../../../scripts/inspect-agent-runtime.sh"
   sh "$runtime_inspector" <native-subagent-thread-id>
   ~~~

   The helper's allowlisted output is the authoritative local fallback for omitted
   model and effort. If public and local values both exist, they must agree. Accepted
   values are Terra / high for judgment-bearing implementation, Luna / medium for
   the floor lane, and Sol / high for review. Missing, inconsistent, unavailable, or
   unobservable routing stops that lane.

5. For every Sol review, capture the observed sandbox policy type and permission
   profile type. The shipped reviewer requests read-only sandboxing, but the host may
   broaden it. Never call the review OS-enforced read-only unless the observed sandbox
   policy type is `read-only`.

The custom-agent TOML, not the spawn call, pins model and effort. Never add per-spawn
model or reasoning overrides.
