# Sol Advisor

**Sol is the architect. Six pinned gpt-6 lanes handle mechanical edits, ordinary work,
narrow retries, broad implementation, senior review, and frontier consultation.**

Sol Advisor is a Codex-native workflow for requirements, architecture, specifications,
routing, verification, and acceptance. Native custom-agent threads handle implementation
and risk-proportional review.

## Lanes

| Role | Native agent type | Pinned profile | Use |
|---|---|---|---|
| Architect | Primary session | `gpt-6.1-sol` / medium | Requirements, decomposition, five-part spec, routing, verification, acceptance |
| Committer | `sol_advisor_luna_committer` | `gpt-6-luna` / low | Mechanical, fully determined edits |
| Implementer | `sol_advisor_luna_implementer` | `gpt-6-luna` / high | Default for ordinary well-specified work |
| Deep retry | `sol_advisor_luna_deep` | `gpt-6-luna` / max | One qualifying narrow retry |
| Sol worker | `sol_advisor_sol_worker` | `gpt-6.1-sol` / medium | Broad work and senior escalation |
| Sol reviewer | `sol_advisor_sol_reviewer` | `gpt-6.1-sol` / medium, read-only | High-risk review |
| Astra consultant | `sol_advisor_astra_consultant` | `gpt-6-astra` / high, read-only | Stuck or expensive-to-reverse decisions |

## Install

Requirements: a current Codex CLI or ChatGPT desktop app with plugins, native subagents,
and custom agents enabled; access to the six pinned profiles; and `jq` for companion
installation.

~~~sh
codex plugin marketplace add DannyMac180/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
~~~

### Install the companion custom agents

Plugin installation does not register user-owned custom-agent files. Install and check
the templates separately:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

The installer uses the existing `CODEX_HOME` when set, otherwise the default Codex agents
directory. It installs missing templates and refuses to overwrite differing local files.
Start a new Codex task after installation so native discovery sees the roles. Select
`gpt-6.1-sol` with medium reasoning for the primary session.

## Check and update

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

Update the marketplace plugin and migrate recognized older companion files:

~~~sh
codex plugin marketplace upgrade sol-advisor
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

The installer migrates recognized old templates, installs the six current role files,
and refuses modified, nonregular, or symlinked destinations without partial mutation.
Do not use a substitute role. Start a fresh task after a successful update.

## Runtime routing evidence

Public native spawn/details metadata must identify the selected role and, when exposed,
its model and effort. If a value is omitted and the local rollout is accessible, use
`scripts/inspect-agent-runtime.sh` as the read-only fallback. Public and local evidence
must agree. The role files pin model and effort; spawn calls omit overrides. Stop a lane
if its pinned model is unavailable or observed model/effort differs.

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
thread_id="<native-subagent-thread-id>"
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$thread_id"
~~~

## How routing works

The primary session writes a five-part specification: objective, file ownership,
interfaces, constraints, and verification. It owns architecture, routing, verification,
and acceptance. The committer handles fully determined edits; the implementer is the
default; the Sol worker takes broad work and senior escalations. A first failure gets a
corrected specification and one retry. A narrow retry of at most 3 files with runnable
verification after a reasoning failure on a clear spec goes to Luna deep. A second
failure or judgment the spec cannot pin down goes to the Sol worker; broad work that
started there gets its one corrected-spec retry there. Astra consults before the next
attempt on architectural deadlock or a failed Sol worker, and before the first attempt on
an expensive-to-reverse decision. A `change` creates a new spec and resets the failure count; a patched spec keeps
it. A post-consult Sol worker failure returns to the user without further delegation.

Before accepting work, verify all six installed files and exposed role names, then confirm
observed routing. Inspect every diff and rerun verification in the primary session.

## Choosing a lane

Use the committer only when the edit is mechanical and fully determined. The implementer
is the default; choose Luna deep only for a qualifying first retry. Start broad or
integration-heavy work in the Sol worker, and route repeated failures or unresolved local
judgment there. Consult Astra for a deadlock, a failed Sol worker, or an
expensive-to-reverse choice. Preflight the role pins in the table before every delegation.

## Review in proportion to risk

Trivial changes proven by passing verification need no separate review. The default is
primary-session self-review of the diff and verification. Use the Sol reviewer for
security, schema, public API, migration, concurrency, irreversible or wide-blast-radius
changes, or work that resisted two attempts. Astra is the exceptional review when a
reviewer returns `ESCALATE: ...`, lanes disagree, or framing is in doubt. Review packets
include the goal, constraints, diff, verification, and silence gap: expected callers,
parallel implementations, and adjacent configuration the change did not touch. Reviewers
never implement.

### Machine-enforced review budget

The plugin hook enforces at most three final reviews per deliverable. It counts
`sol_advisor_sol_reviewer`; Astra consults are uncounted. Scope freezes after cycle 1.
Later cycles judge only cycle-1 findings and regressions from fixes. The budget persists
through compaction and spec changes; a genuinely new deliverable needs a recorded reset.
Consult packets begin with the literal `COMMITMENT BOUNDARY` marker for the audit trail;
the hook identifies consults by agent type.
On a stop condition, make exactly one Astra consult, attach its answer, then return control
to the user. The hook fails open until trusted. `scripts/check-hook-trust.sh` reports
`HOOK ACTIVE` or `HOOK INERT`; `scripts/ledger-report.sh` summarizes the ledger.

## Routing evidence

The skill records routing decisions at `${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl`.
This file stays outside the public repository because entries include task descriptions.
The README and skill keep the same ledger path.

## Retro

After ten to twenty deliverables, run `scripts/ledger-report.sh` and review cap hits,
resets, consults, and routing outcomes. Use the routing ledger to compare the measured
spawn floor and completed-delegation time with actual local experience.

## 0.9.0

This release moves orchestration to gpt-6 lanes, adds the Sol worker and Sol reviewer in
place of the old Opus-equivalent roles, adds the Astra consultant, adopts risk-proportional
review, and removes Challenger. The installer automatically migrates recognized 0.8.0
companion files.

## Local development

~~~sh
cd /absolute/path/to/sol-advisor
codex plugin marketplace add /absolute/path/to/sol-advisor
codex plugin add sol-advisor@sol-advisor
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
~~~

To exercise the installer against a disposable target:

~~~sh
scratch_agents="$(mktemp -d)"
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$scratch_agents"
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$scratch_agents" --check
~~~

## License

MIT
