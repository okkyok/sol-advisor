# Sol Advisor

**Sol runs the show. Luna / Max handles implementation, and a fresh Terra review
with a requested read-only profile stands between the diff and done.**

Sol Advisor is a Codex-native architect workflow for capability-routed software
delivery. The primary session stays focused on requirements, architecture, specs, and
verification while native Codex custom-agent threads handle implementation and review.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

| Lane | Native agent type | Pinned profile | Use it for |
|---|---|---|---|
| Orchestrator | Primary session | GPT-5.6 Sol / Medium | Requirements, architecture, decomposition, routing, and acceptance |
| Implementation | sol_advisor_luna_implementer | GPT-5.6 Luna / Max | Bounded work specified by the Sol orchestrator |
| Consultant | sol_advisor_sol_consultant | GPT-5.6 Sol / Medium | Commitment-boundary consults before hardest work |
| Floor | sol_advisor_luna_committer | GPT-5.6 Luna / Medium | Mechanical, fully-determined edits the specification leaves nothing to decide in |
| Final review | sol_advisor_sol_reviewer | GPT-5.6 Terra / High / requests read-only | Fresh review of the actual diff and verification evidence |
| Challenger | `scripts/challenge.sh` (external `claude` CLI, not a native agent) | Claude Opus | deadlock, irreversible, user-request |

The final review is context-independent and different-model within the same vendor: Terra
reviews Sol's orchestration with a fresh context. That catches conversational assumptions,
but it is not cross-vendor review. The Challenger remains the only cross-vendor check; it
is a rare, bounded remedy for deadlock, irreversible, and user-request triggers, not a
routine substitute for the final review.

For the exact triggers `deadlock`, `irreversible`, and `user-request`, the Challenger is
invoked as a plain shell command via `scripts/challenge.sh`, not a native custom agent.
This avoids routing Claude's judgment through a Codex summary, which would reintroduce the
model-family correlation the Challenger exists to break, and avoids the roughly 8.8s native
spawn floor.

## Install from GitHub

Requirements:

- A current Codex CLI or ChatGPT desktop app with plugins, native subagents, and
  custom agents enabled.
- Access to GPT-5.6 Sol, GPT-5.6 Luna, and GPT-5.6 Terra at the reasoning efforts in the table above.
- jq, which the companion-install lookup uses to locate the installed plugin package.

Add the GitHub repository as a Codex marketplace, then install the plugin:

~~~sh
codex plugin marketplace add DannyMac180/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
~~~

### Install the companion custom agents

Plugin installation does **not** automatically install custom-agent files. That is
intentional: the files are user-owned role pins, and the installer must never overwrite
a different local role silently. Install the companion templates separately:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

Without an explicit target, the installer uses the existing CODEX_HOME value when one is
already set, otherwise the user's default Codex agents directory. It does not invoke
Codex, edit config.toml, or overwrite a differing agent file. It only installs a
missing template and then verifies every installed copy byte-for-byte.

Start a **new Codex task** after the check passes. Native agent types are discovered at
task creation, so an existing task may not see the installed roles.

Then select GPT-5.6 Sol with Medium reasoning for the primary session and ask for
implementation work normally, or invoke the orchestration skill explicitly:

~~~text
Use $sol-advisor:orchestration to build this feature, verify it, and obtain the final Terra review before reporting done.
~~~

## Check and update

Run this check whenever a route must be trusted:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

To update the marketplace plugin and migrate the exact recognized v0.2.0 companion
files:

~~~sh
codex plugin marketplace upgrade sol-advisor
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

Version 0.4.0 recognizes only byte-exact v0.2.0 legacy `sol-advisor-luna-implementer.toml` and `sol-advisor-terra-implementer.toml` files.
The installer also migrates the previous shipped Sol reviewer template so a
project-changed shipped template is not refused as a conflict.
Normal installer mode installs the four current role templates, removes the exact retired
Terra implementer file, and refuses modified, nonregular, or symlinked destinations
without partial agent-file mutation. `--check` is non-mutating and fails until all four
current role files match exactly and the retired Terra file is absent.
This routing update was motivated by
[Eric Provencher's X post](https://x.com/pvncher/status/2083300990350954981).

Do not use a substitute agent as a shortcut. Start a fresh task after every successful
install or update.

## Runtime routing evidence

Native spawn/details metadata is the primary source of routing evidence. It must show
the selected custom agent type. When it also exposes model and effort, the orchestrator
compares those values with the role pin. If Desktop omits model or effort and the local
rollout is accessible, use the companion inspector as the authoritative read-only
fallback for those omitted fields:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
thread_id="<native-subagent-thread-id>"
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$thread_id"
~~~

For a disposable fixture or a non-default local session root, pass it explicitly:

~~~sh
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" --sessions-dir /absolute/path/to/sessions "$thread_id"
~~~

The helper searches only rollout filenames ending in that exact thread id, then emits a
single compact JSON object with allowlisted routing fields. It never prints prompts,
messages, environment variables, tokens, configuration contents, or arbitrary rollout
payloads. It refuses invalid ids, zero or multiple matches, and missing or inconsistent
role/model/effort; there is no inferred fallback. If public and local evidence both
exist, they must agree.

## How routing works

The Sol orchestrator writes a five-part spec for every implementation: objective, file
ownership, interfaces, constraints, and verification. Luna / Max is the sole
implementation producer; Sol keeps architecture, routing, parent verification, and
acceptance in the primary session.

Before delegation and acceptance, the skill requires all of the following:

1. The installed role files pass the byte-for-byte companion check.
2. The native spawn tool exposes all four exact names in the table above.
3. Public native spawn/details metadata identifies the selected role and, when exposed,
   its expected model and effort. If model or effort is omitted, the exact-rollout local
   inspector above must provide them instead.
4. The reviewer’s and consultant’s observed sandbox policy and permission profile types
   are captured and reported.

A missing, stale, conflicting, unavailable, inconsistent, or unobservable
role/model/effort stops the affected lane with an actionable error. There is no silent
model, reasoning, or agent-type fallback, and per-spawn calls do not override the role
pins.

The Terra reviewer TOML requests read-only sandboxing, but the host permission profile
may broaden that request. If the observed sandbox policy type is read-only, review can
proceed with enforced isolation. If the host broadens it, review can proceed only as
behaviorally read-only when hard isolation is not required, the prompt forbids edits,
and the parent captures and verifies exact before-and-after repository/artifact state;
the broader sandbox and permission profile must be reported as residual risk. If hard
isolation is required, the sandbox cannot be observed, or any mutation occurs, stop the
review lane and do not claim enforced read-only isolation.

The orchestrator inspects every diff and reruns verification. A fresh Terra reviewer then
returns ship, fix-first, or rethink. The session cannot report completion until the
reviewer returns ship. These remain native Codex subagent threads; Sol Advisor does not
launch a nested Codex CLI process or globally reroute unrelated subagents.

That review loop is budgeted at three final reviews per deliverable. A fresh reviewer
can always find something new, so an unbounded fix-first cycle never terminates on its
own. Cycle 1 fixes the finding set; later cycles judge only those findings and
regressions introduced by the fixes, and anything else is reported as deferred residual
risk. The cycle count persists outside the conversation so context compaction cannot
reset it, and it is never reset by a corrected specification, an architecture revision,
or a renegotiated scope. When the budget is exhausted, a finding survives two consecutive
fix cycles, or rethink arrives at cycle 2 or later, the session stops and hands the
unresolved findings and options to the user instead of spawning another lane.

### Machine-enforced review budget

The three-review budget is enforced by a `PreToolUse` hook shipped with the plugin, not
by convention. The hook recognizes `tool_input.agent_type` equal to either
`sol_advisor_sol_reviewer` or `sol_advisor_sol_consultant`, regardless of the host-provided
tool name. A consultant spawn is recorded as `consult` and never consumes a final-review
cycle. A reviewer prompt carrying the literal `COMMITMENT BOUNDARY` marker is a second,
auditable exemption path; a final reviewer that omits the marker is counted. The marker
is opt-in in that direction on purpose: the party composing the packet is the party with
an incentive to keep reviewing, so a forgotten marker must cost a cycle rather than grant
an unbounded loop. Consult and marker-exempt spawns are written to the ledger as `consult`
entries, which makes relabelling a final review auditable instead of invisible. It stores
the session-keyed, auditable ledger at `$PLUGIN_DATA/review-budget.jsonl`; a
new-deliverable record resets the count for a genuinely new deliverable in the same
session. The hook fails open by design, so malformed input or an internal bug can never
block a Codex session. Codex asks the user to trust a plugin's hooks on first use, and
enforcement remains inert until that trust is granted.

The hook writes a liveness heartbeat to `$PLUGIN_DATA/hook-status.json` on every
`PreToolUse` event. `scripts/check-hook-trust.sh` reads it and reports `HOOK ACTIVE` or
`HOOK INERT`. Pass a fresh literal nonce, never the example token verbatim; the hook
copies that nonce from the checker command into the heartbeat, proving that the
heartbeat came from that invocation rather than from a concurrent trusted session.
The hook reads the command text before the shell expands it, so `$$`, `$(...)`,
backticks, or a variable in the nonce are invisible to the hook and produce a false
`HOOK INERT`. A check without a nonce is reported as unverified. Denied fourth and
later reviews are now recorded in the ledger without increasing the review count. Run
`scripts/ledger-report.sh` to summarize cycles, cap hits, resets, exempt consults, and
whether the ledger suggests the review scope is still growing or the budget is being
routed around. The hook deliberately has no `matcher` in
`hooks.json`: narrowing it would hide the heartbeat from ordinary tool calls and
destroy the liveness check.

### Choosing a lane

The skill classifies every task into one of six classes (commit, implement, explore,
ingest, review, hardest) and routes it to the floor lane, Luna / Max, or the fresh
Terra reviewer by default, keeping work in the primary session only for five named
exceptions: context-bound tasks, work below the measured spawn floor, architect work
by definition, the final review gate, and tooling only the primary session can reach.
A failed delegation gets one corrected re-specification; a second failure on the same
objective stops delegation and returns the question to the primary session or a
commitment-boundary Sol consult instead of trying a third time.

## Retro

The ledger is only worth keeping if someone reads it. After ten to twenty deliverables,
run the reader and question the numbers rather than the impressions:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
sh "$plugin_dir/scripts/ledger-report.sh"
~~~

Three things are worth arguing with. A cap-hit rate above 25% means cycle 1 is not
producing the complete finding set, so freeze scope harder rather than raising the
budget. A non-zero bypass count means the budget is being routed around: the report
counts only the two moves that can actually evade it, a reset or an exempt consult
recorded immediately after a denial in the same session, so the pattern is checkable
rather than deniable. And a cycle distribution concentrated at 1 means the budget is not
the binding constraint at all, and the interesting question moved elsewhere.

The review ledger sees reviews and nothing else, so it cannot answer where the work went.
The skill's routing ledger covers that: one JSON line per delegation, per exception
applied, and per stopped lane, appended to
`${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl` — under `CODEX_HOME` because
`$PLUGIN_DATA` reaches hook processes only, and outside this public repository because
entries carry task descriptions. Without it the spawn floor in exception 2 and the cost
of a completed delegation stay borrowed numbers rather than measured ones.
Create the parent on first use before appending a record:

~~~sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/sol-advisor"
printf '%s\n' '<one routing JSON record>' >> "${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl"
~~~

The spawn-floor number quoted in the skill measures a spawn, not a delegation. On the
author's setup, a no-op spawn measured about 8.8 seconds wall clock, against a median
of about 540 seconds for a completed delegation across 17 logged delegations. These
are measurements from one setup, not universal constants; the completed-delegation
cost is the number the keep-it-in-session decision actually turns on.

## Local development

Install a checkout as a local marketplace when you want Codex to use its skill:

~~~sh
cd /absolute/path/to/sol-advisor
codex plugin marketplace add /absolute/path/to/sol-advisor
codex plugin add sol-advisor@sol-advisor
~~~

Run the repository verifier separately. It uses only a disposable target directory and
never changes your Codex configuration:

~~~sh
cd /absolute/path/to/sol-advisor
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
~~~

To exercise the installer itself against an explicit disposable target:

~~~sh
cd /absolute/path/to/sol-advisor
scratch_agents="$(mktemp -d)"
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$scratch_agents"
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$scratch_agents" --check
~~~

To install this checkout's templates for real local development, use the same
repository-relative commands without --target-dir, then begin a new task:

~~~sh
cd /absolute/path/to/sol-advisor
sh plugins/sol-advisor/scripts/install-agents.sh
sh plugins/sol-advisor/scripts/install-agents.sh --check
~~~

After editing the plugin, validate both layers:

~~~sh
cd /absolute/path/to/sol-advisor
if [ -n "$CODEX_HOME" ]; then
  codex_skills="$CODEX_HOME/skills/.system"
else
  codex_skills="$HOME/.codex/skills/.system"
fi
uv run --no-project --with pyyaml python "$codex_skills/skill-creator/scripts/quick_validate.py" plugins/sol-advisor/skills/orchestration
uv run --no-project --with pyyaml python "$codex_skills/plugin-creator/scripts/validate_plugin.py" plugins/sol-advisor
jq empty .agents/plugins/marketplace.json plugins/sol-advisor/.codex-plugin/plugin.json
~~~

The verifier validates JSON and TOML, the two exact role pins, clean/current/missing
and idempotent installer behavior, exact-v0.2.0 migration, refusal/non-mutation gates,
runtime-inspector safe fixtures, contract references, and shell syntax. The uv commands
supply the validators' PyYAML dependency in a disposable environment. They do not
install the marketplace or mutate Codex configuration.

## License

MIT
