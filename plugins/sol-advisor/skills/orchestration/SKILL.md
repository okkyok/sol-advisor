---
name: orchestration
description: "Codex-native orchestration on gpt-6 lanes: primary gpt-6.1-sol medium architect; gpt-6-luna low committer for mechanical edits; gpt-6-luna high default implementer; gpt-6-luna max narrow retry; gpt-6.1-sol medium broad worker and read-only reviewer; gpt-6-astra medium read-only frontier consultant. Classify, specify, route, verify, and review in proportion to risk."
---

# Sol Advisor Orchestration

Act as the architect. Own the user's intent, requirements, architecture, decomposition,
complete implementation specification, routing, verification, and acceptance. Delegate
implementation to the pinned native Codex roles. These are native custom-agent threads,
not a nested CLI wrapper or a global default-subagent setting.

Read [references/role-contracts.md](references/role-contracts.md) and
[references/preflight.md](references/preflight.md) before the first delegation in a
session.

## What this workflow optimizes

The primary session's context is the scarce resource. Codex tokens are abundant; spend
them on width. Terminating beats one more finding. The primary session produces
requirements, architecture, specifications, routing decisions, evidence-based verdicts,
and short reports.

## Confirm the primary session

Run the primary Codex session on `gpt-6.1-sol` with medium reasoning. Verify the current
model and effort when runtime metadata exposes them. If either differs, tell the user to
select the required profile and stop before delegation. If runtime metadata does not
expose them, ask the user to confirm the profile and stop until confirmed. A skill cannot
change the primary model itself; never assume or claim this prerequisite is satisfied.

## Preflight the companion custom agents

Complete [references/preflight.md](references/preflight.md) before the first delegation,
and again before accepting any lane's result. A missing, stale, unsafe, conflicting,
unavailable, inconsistent, or unobservable role, model, or effort stops that lane.
Never work around a failure with another role, model, or effort.

## Keep architect work in the primary session

Keep requirements, material ambiguity, architecture, interfaces, decomposition, the
complete five-part specification, diff inspection, parent verification, and acceptance
in the primary session. Do not type implementation code or mechanical configuration
when a lane can do it. If a result is wrong, correct the specification and route the fix;
do not silently repair a failed worker patch.

## Classify the task and choose the lane

Classify before routing. Mechanical and fully determined work goes to the committer.
The default for ordinary well-specified implementation, exploration, or ingest is the
implementer. Broad work involving several interacting components, integration-heavy
interfaces, or wide-search debugging goes first to the Sol worker. Judgment-dominated
implementation also goes to the Sol worker.

After a first failure, correct the specification and delegate once. If the retry is
narrow (at most 3 files), has runnable verification, and failed because of reasoning on a
clear specification, use Luna deep instead of the implementer. A second failure on the
same objective, or work dominated by a local judgment/trade-off the specification cannot
pin down, goes to the Sol worker. Broad work that started on the Sol worker gets its one
corrected-specification retry there; a Sol worker failure after that retry, or a failed
senior escalation, is a failed Sol worker.

Consult Astra before the next implementation attempt for an architectural deadlock or a
failed Sol worker, and before the first one for an expensive-to-reverse decision (schema,
public API, data migration, or irreversible change). Astra's `change` answer becomes a new specification and restarts
the failure count at 0; a patched specification keeps the count. `stop` goes to the user.
If the Sol worker fails after an Astra consult, stop and hand the objective back to the
user without further delegation. A committer task returned as blocked is a routing error:
re-route to the implementer without consuming a failure step.

Keep work in the primary session only for these five reasons:

1. Context-bound: a self-contained five-part specification would cost more than doing
   work that depends on conversation state.
2. Below the spawn floor: measured on this machine on 2026-08-03 with codex 0.146.0,
   `spawn_agent` returns an id in about 0.13 s and a complete no-op delegation costs
   about 8.8 s. Use this exception only for a single-line, single-file edit, and name
   the number. Codex tokens are not a reason to keep work in session.
3. Architect work by definition: requirements, architecture, decomposition, spec writing,
   and judging evidence. Judgment-dominated implementation goes to the Sol worker.
4. Review: reviews follow the risk-proportional rules below.
5. Unreachable tooling: primary-session plugins, MCP servers, or browser access that a
   custom-agent thread cannot reach.

## Spawn the pinned role

Every spawn uses the role's pinned model and effort. Omit per-spawn model and reasoning
fields. If the pinned model is unavailable or observed model/effort differs, stop that
lane and report; never substitute another role, model, or effort.

~~~text
agent_type: sol_advisor_luna_committer
fork_turns: none
~~~

~~~text
agent_type: sol_advisor_luna_implementer
fork_turns: none
~~~

~~~text
agent_type: sol_advisor_luna_deep
fork_turns: none
~~~

~~~text
agent_type: sol_advisor_sol_worker
fork_turns: none
~~~

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

~~~text
agent_type: sol_advisor_astra_consultant
fork_turns: none
~~~

Give each implementation worker an owned file set and the complete five-part spec. State
that it is not alone in the codebase, must preserve concurrent edits, and must adapt to
changes already present. Keep shared-file edits and dependency chains serial.

## Verify every implementation

Treat worker reports as claims. Before acceptance, inspect the working tree and complete
diff, confirm only in-scope files changed, rerun the specified verification in the primary
session, compare evidence with the objective and constraints, and route corrections when
evidence or diff is wrong. Verify in the environment the real caller has. When a change
depends on ambient state, exercise it once from a real session and write the assertion
that would have caught a failure.

## Consult Astra when the approach is stuck

Consult Astra before implementation for the triggers above. Send the decisive question,
current approach, evidence, and what failed. Begin the packet with the literal
`COMMITMENT BOUNDARY` marker for the audit trail; the hook identifies the consult by its
agent type, not by the marker. The consult is uncounted by the review
budget. Astra advises with `proceed`, `change`, or `stop`, the largest risk, and for
`change` a reframed approach. The primary session remains responsible for decisions.

## Review in proportion to blast radius

Choose one review level:

- `none`: a trivial change fully proven by its passing verification.
- `self_review` (default): the primary session re-reads the diff and reruns verification.
- `sol_advisor_sol_reviewer`: security, schema, public API, data migration, concurrency,
  irreversible changes, wide blast radius, or a change that resisted two attempts.
- Astra consult as exceptional review: the reviewer ended with `ESCALATE: ...`, lanes
  disagree, or the framing itself is in doubt.

Before any review, compute the **silence gap**: what the change should have touched
(callers, parallel implementations, adjacent config) minus what it did. Include those
paths in the packet. Give a fresh reviewer the goal, constraints, diff, verification
result, and silence gap, not the implementer's account. Instruct it to inspect actual
files and stay behaviorally read-only. Return `ship`, `fix-first`, or `rethink`; never let
the reviewer implement.

- `ship`: report completion with verification evidence.
- `fix-first`: route the required fixes, verify again, and obtain a new review inside the
  review budget below.
- `rethink`: revise the architecture and do not report completion. It consumes a review
  cycle like any other verdict.

Scope inflation is a defect, not a preference. A change set that delivers artifacts the
objective did not ask for fails the objective like a missing requirement. Name the surplus
artifact and the objective it does not serve. Judge against the stated objective; alternate
implementations, naming, and structure are deferred. Correct and complete means the goal
is met and nothing beyond it was delivered.

Apply observed sandbox policy. With `read-only`, isolation is enforced. If the host
broadens it, proceed only when hard isolation is not required, the prompt forbids edits,
and the parent captures and verifies exact before-and-after repository and artifact state;
report the observed sandbox and permission profile. If hard isolation is required, the
sandbox is unobservable, or any mutation occurs, stop the review.

## Bound the review loop

The hook enforces at most 3 final reviews per deliverable. Freeze scope after cycle 1;
later cycles judge only whether cycle-1 findings were resolved and regressions from fixes.
Other findings are deferred residual risk. The hook counts `sol_advisor_sol_reviewer`;
`sol_advisor_astra_consultant` is an uncounted consult. Never reset the budget for
compaction, a corrected specification, architecture revision, or renegotiated scope. A
genuinely new deliverable requires the documented `new-deliverable` ledger record.

Stop when cycle 3 is not `ship`, two consecutive reviews find unresolved or recurring
issues, or `rethink` arrives at cycle 2 or later or a second time. On a stop condition,
make exactly one Astra consult before handing control back to the user, attach its answer,
and do not report completion. A hook denial is this stop condition, not an error to route
around. Report the ledger, diff, verification, unresolved findings, and options.

The hook writes `$PLUGIN_DATA/review-budget.jsonl`; use `scripts/ledger-report.sh` to
inspect it. Before the first review, run `scripts/check-hook-trust.sh`. `HOOK ACTIVE`
means the host enforces the budget; `HOOK INERT` means it is prose and must be reported.
Do not hand-edit the ledger.

## Routing ledger

Append one JSON line to `${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl` when a
delegated task reaches its final outcome, work stays in the primary session under an
exception, or a lane stops at preflight or routing. This ledger is outside the public
repository because entries carry task descriptions. `$PLUGIN_DATA` reaches hook
processes only, not the primary shell.

~~~json
{"ts":"<ISO8601>","task":"<short label>","class":"commit|implement|explore|ingest|review|hardest","lane":"sol_advisor_luna_committer|sol_advisor_luna_implementer|sol_advisor_luna_deep|sol_advisor_sol_worker|sol_advisor_sol_reviewer|sol_advisor_astra_consultant|architect","exception":null,"outcome":"success|spec-retry|reclassified|stopped|abandoned","attempts":1,"duration_s":540,"note":""}
~~~

`lane: architect` with `exception: 1-5` records work kept in session. `spec-retry` names
the gap; `reclassified` records a blocked committer sent to the implementer. Append one
line per outcome, not narration.

On first use, create the parent and append with a plain shell redirect -- no jq, no
wrapper script:

~~~sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/sol-advisor"
printf '%s\n' '<one JSON line>' >> "${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl"
~~~

A read-only sandbox refuses that write. Report the refusal rather than dropping the entry
silently.
