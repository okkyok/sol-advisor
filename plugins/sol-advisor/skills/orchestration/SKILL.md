---
name: orchestration
description: "Codex-native architect and delegation workflow using separately installed custom agents: a GPT-5.6 Terra implementer at high reasoning, a GPT-5.6 Luna floor lane at medium reasoning for mechanical edits, and a fresh GPT-5.6 Sol reviewer at high reasoning with a requested read-only profile. Use for classifying a task and choosing a lane, delegated implementation, multi-task builds, features, bug fixes, refactors, migrations, five-part implementation specs, parent verification, commitment-boundary advice, and the budgeted final Sol review."
---

# Sol Advisor Orchestration

Act as the architect. Own the user's intent, architecture, decomposition, complete
implementation specification, parent verification, and final acceptance. Delegate all
implementation to the native Terra / High role, then require a fresh Sol verdict before
reporting the deliverable complete. These are native Codex custom-agent threads, not a
nested Codex CLI wrapper or a global default-subagent setting.

Read [references/role-contracts.md](references/role-contracts.md) and
[references/preflight.md](references/preflight.md) before the first delegation in a
session.

## What this workflow optimizes

The primary Sol / High session is the scarcest resource in this workflow. Its output
is decomposition, specifications, routing decisions, verdicts on evidence, and short
reports, not implementation text.

Delegation exists to keep the primary context lean, not merely to save money:
everything in it is re-read on every turn.

Terminating is worth more than one more finding. A reviewer with a fresh context can
always produce another finding, so the workflow optimizes for a correct ship/stop
decision made once, not for the largest possible finding count.

When a rule below does not cover the situation, extrapolate from these three, in this
order.

## Confirm the primary session

Run the primary Codex session on gpt-5.6-sol with high reasoning. Verify the current
model and effort when runtime metadata exposes them. If either differs, tell the user
to select Sol / High and stop before delegation. If runtime metadata does not expose
them, ask the user to confirm Sol / High and stop until confirmed. A skill cannot
change the primary model itself; never assume or claim this prerequisite is satisfied.

## Preflight the companion custom agents

Complete the full preflight in [references/preflight.md](references/preflight.md)
before the first delegation in a session, and again before accepting any lane's
result. A missing, stale, unsafe, conflicting, unavailable, inconsistent, or
unobservable role, model, or effort stops that lane. Never work around a failure with
another agent, model, or effort.

## Keep architect work in the primary session

Keep these responsibilities in the primary session:

- Resolve requirements and material ambiguity.
- Choose architecture, interfaces, and decomposition.
- Write the complete five-part implementation specification.
- Inspect the actual diff and rerun verification.
- Judge reviewer feedback and accept the deliverable.

Do not type implementation code, tests, boilerplate, or mechanical configuration in
the primary session when the Terra lane can do it. If its result is wrong, correct the
specification and delegate the fix. Do not silently repair a failed worker patch.

## Classify the task and choose the lane

Before spending Sol effort on anything, classify the task and route it. The default
is a lane; keeping work in the primary session requires naming one of the five
exceptions below.

| Class | Definition | Default lane |
|---|---|---|
| commit | A trivial, fully-determined edit: a typo, one-line fix, version bump, config value, or one known pattern applied across many files. | The floor lane. |
| implement | Write or edit code, tests, or config against a specification. | Terra / High |
| explore | Read or search the codebase or history to answer a question. | Terra / High |
| ingest | Absorb external material (docs, logs, large files) into usable form. | Terra / High |
| review | Judge a completed change set against a stated goal. | Fresh Sol reviewer |
| hardest | Work whose difficulty or ambiguity exceeds what a spec can bound. | Terra / High, after a commitment-boundary Sol consult |

The floor lane's name is `sol_advisor_luna_committer`.

~~~text
agent_type: sol_advisor_luna_committer
fork_turns: none
~~~

The installed role pins GPT-5.6 Luna at medium reasoning. Per-spawn model and reasoning
fields are omitted. Work that turns out to need judgment comes back as blocked and is
re-routed to Terra rather than being finished in the floor lane.

There is no lane above Terra. A `hardest` task gets a commitment-boundary Sol consult
before implementation, not an escalation after it fails.

The deciding rule: how much of the outcome does the specification determine? Fully and
mechanically, route to the floor lane. Otherwise, route to Terra. Judgment about
architecture, interfaces, hypotheses, and evidence never leaves the primary session,
because that judgment is the architect's own work, not a lane's.

Keep work in the primary session only for one of these five named reasons:

1. Context-bound: the task depends on conversation state, and writing a
   self-contained five-part specification would cost more than doing the work.
2. Below the spawn floor: measured on this machine on 2026-08-03 with codex 0.146.0,
   spawn_agent returns an agent id in about 0.13 s, and a complete no-op delegation
   (spawn, wait, result) costs about 8.8 s of wall clock. This floor is low precisely
   because the lanes are in-process native threads, not a separate CLI process, so
   "faster to do it myself" is a valid exception only for a single-line, single-file
   edit, and only when the architect names the number.
3. Architect work by definition: decomposition, interface design, hypothesis
   selection, spec writing, and judging verification evidence.
4. The final review gate: the fresh Sol review never moves into the primary session.
5. Tooling the lane cannot reach: primary-session plugins, MCP servers, or browser
   access a custom-agent thread does not have.

These exceptions are a checklist applied after classifying a task, not a licence to
skip classification.

## Route implementation through Terra / High

Use the same role for routine features, mechanical edits, difficult debugging,
security-sensitive work, non-trivial algorithms, and broad refactors. There is no
second implementation or fallback lane.

Spawn exactly:

~~~text
agent_type: sol_advisor_terra_implementer
fork_turns: none
~~~

The installed role pins GPT-5.6 Terra at high reasoning. Omit per-spawn model and
reasoning fields. Confirm role, model, and effort using the public-details-first
procedure before accepting work.

Routing rules:

- Give each worker one owned file set or bounded responsibility.
- State that it is not alone in the codebase, must preserve other edits, and must
  adapt to concurrent changes.
- Run independent non-overlapping work concurrently only when useful. Keep shared-file
  edits and dependency chains serial.
- First failure: correct the specification and re-delegate once, naming the gap that
  made it fail. Never repeat an unchanged prompt.
- Second failure on the same objective: stop delegating. Inspect the code in the
  primary session and either re-specify from what you found or take the question to a
  commitment-boundary Sol consult. Two failures are evidence the specification is
  wrong, not that the lane is unlucky.
- There is no third delegation of the same objective. Report the situation to the
  user instead.
- A floor-lane task that returns blocked is a routing error, not a lane failure.
  Re-classify it and send it to Terra with the gap named; it does not consume a step
  of the first-failure/second-failure delegation ladder.
- Never silently substitute a role, model, or reasoning level.

## Verify every implementation

Treat worker reports as claims. Before acceptance:

1. Inspect the working tree and complete diff.
2. Confirm only in-scope files changed.
3. Rerun the specification's verification commands in the primary session.
4. Compare the evidence with the objective, interfaces, and constraints.
5. Delegate corrections when the evidence or diff is wrong.

Verify in the environment the real caller has, not one the test constructs. A test that
supplies the inputs the caller cannot supply proves nothing about the caller. Two
defects shipped through a green suite for exactly this reason: a helper read a variable
that only hook processes receive while every test exported it by hand, and a script used
a here-document that a read-only sandbox refuses while every test ran unsandboxed. Both
suites passed at every commit. When a change depends on ambient state -- environment
variables, sandbox policy, trust, installed layout -- exercise it once from a real
session before accepting it, and write the assertion that would have caught it.

## Consult Sol at commitment boundaries

Before a consequential architecture, migration, public API, or wide refactor, spawn a
fresh reviewer using the commitment-boundary packet from the role contracts:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

The role pins Sol / High and requests read-only isolation. Omit per-spawn model and
reasoning fields. Observe actual routing, sandbox, and permission metadata. The
primary session remains responsible for the decision.

Open the consult packet with the literal `COMMITMENT BOUNDARY` marker. Without it the
consult consumes one of the deliverable's three final-review cycles, which is the safe
direction to fail but still a cost worth avoiding.

## Require the final Sol review

After implementation and parent verification, always spawn a new, fresh reviewer:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

Use the final-review packet from the role contracts. Instruct the reviewer to remain
behaviorally read-only, inspect the actual files and accumulated diff, and return
exactly `ship`, `fix-first`, or `rethink`.

- `ship`: report completion with verification evidence.
- `fix-first`: delegate the required fixes, verify again, and obtain a new review
  inside the review budget below.
- `rethink`: revise architecture and do not report completion. A `rethink` consumes a
  review cycle like any other verdict.

Never let the reviewer implement its own fixes. A Sol-on-Sol review is context-clean,
not model-family-independent.

Apply the observed sandbox policy:

- If it is `read-only`, isolation is enforced.
- If the host broadens it, proceed only when hard isolation is not required, the
  prompt forbids edits, and the parent captures and verifies exact before-and-after
  repository and artifact state. Report the observed sandbox and permission profile.
- If hard isolation is required, the sandbox is unobservable, or any mutation occurs,
  stop the review. Do not claim read-only isolation or hide the mutation.

## Bound the review loop

The final review is budgeted. Unbounded, `fix-first` -> Terra fix -> fresh review repeats
until the task is interrupted, because a reviewer with a fresh context can always find
something new. Termination is the architect's responsibility, not the reviewer's, but
the architect's compliance is no longer what makes the budget hold.

Budget: at most 3 final reviews per deliverable, meaning the first review plus at most 2
re-reviews. Count every final review, including one that follows a `rethink`.

The plugin's `PreToolUse` hook counts each `tool_input.agent_type` equal to
`sol_advisor_sol_reviewer`, regardless of the host-provided tool name, and denies the
fourth at the host level. The primary session does not maintain the count. The hook
maintains `$PLUGIN_DATA/review-budget.jsonl`; read that ledger to see how many cycles this
deliverable has used. Denials are recorded in the same ledger. The
`scripts/ledger-report.sh` helper summarizes how the budget is actually being used. Do
not hand-edit the ledger.

Before the first final review, run the preflight's hook-liveness check at
`scripts/check-hook-trust.sh`. `HOOK ACTIVE` means the host holds the budget. `HOOK
INERT` means the budget is prose again; report that plainly in the final report rather
than assuming enforcement.

The marker contract fails safe. Every spawn of `sol_advisor_sol_reviewer` consumes a
cycle unless its packet carries the literal `COMMITMENT BOUNDARY` marker, which exempts
a commitment-boundary consult. Forgetting the marker on a consult costs one review
cycle; no omission anywhere grants an unbounded review loop. The exemption is opt-in
precisely because the party composing the packet is the party with an incentive to keep
reviewing.

Exempt spawns are recorded as `consult` entries rather than dropped, so relabelling a
final review as a consult is auditable instead of invisible: `ledger-report.sh` reports
an exempt consult or a reset that immediately follows a denial as a bypass signature.

The budget is keyed to the session and belongs to the deliverable. Never reset it because
context was compacted, the specification was corrected, the architecture was revised,
or the scope was renegotiated. Starting a genuinely new deliverable inside the same
session requires appending a `new-deliverable` record with the command documented in the
hook's denial. That reset is deliberately recorded and auditable rather than invisible.

Freeze the review scope after cycle 1. Cycle 1 defines the complete finding set. Cycles 2
and 3 judge only:

- whether each cycle-1 finding is now resolved, and
- regressions or new defects introduced by the fix diffs themselves.

Anything else is recorded as deferred residual risk and reported to the user. It does not
start another fix cycle. State this restriction in the review packet.

Stop and hand control back to the user instead of spawning another review when:

- the budget is exhausted, meaning cycle 3 returned a verdict other than `ship`;
- two consecutive reviews return findings the fixes did not resolve, or a fixed finding
  reappears; or
- a `rethink` arrives at cycle 2 or later, or a second `rethink` arrives at all.

On a stop condition, do not report the deliverable complete and do not spawn another
lane. Report the ledger lines, the current diff, the verification evidence, the unresolved
findings, and the options you see, then ask the user which to take.

A hook denial is not an error to route around; it is this stop condition firing. Hand the
unresolved findings, current evidence, and options to the user.

## Routing ledger

The review-budget ledger only sees reviews. Every other number this doctrine relies on --
the spawn floor in exception 2, the cost of a completed delegation, how often the floor
lane is misrouted -- is currently uncollected, which means the routing rules above are
calibrated from one author's measurements rather than from this installation's. Fix that
by appending one JSON line to `${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl` at
each of these moments:

- a delegated task reaches its final outcome (verified, re-specified, or abandoned);
- a task is kept in the primary session under one of the five exceptions -- these entries
  are what make an exception-2 claim checkable instead of a feeling;
- a lane is stopped by preflight, an unobservable pin, or the failure ladder.

The ledger lives under `CODEX_HOME`, not `$PLUGIN_DATA`: that variable reaches hook
processes only, never the primary session's shell. It is also outside the plugin
repository, which is public, because entries carry task descriptions.

Fields:

~~~json
{"ts":"<ISO8601>","task":"<short label>","class":"commit|implement|explore|ingest|review|hardest","lane":"sol_advisor_terra_implementer|sol_advisor_luna_committer|sol_advisor_sol_reviewer|architect","exception":null,"outcome":"success|spec-retry|reclassified|stopped|abandoned","attempts":1,"duration_s":540,"note":""}
~~~

- `lane: "architect"` with `exception: 1-5` records work kept in the primary session, and
  `duration_s` is the actual time it took, so an exception-2 claim can be compared with
  the measured spawn floor rather than accepted.
- `outcome: "spec-retry"` is the first-failure re-specification; name the gap in `note`.
  `"reclassified"` is a floor-lane task that returned blocked and moved to Terra.
  `"stopped"` is the failure ladder or a preflight refusal ending the objective.
- `attempts` counts specifications submitted to the final lane; `duration_s` is a rough
  wall-clock estimate, not a stopwatch reading.

On first use, create the ledger parent and append with a plain shell redirect -- no jq,
no wrapper script:

~~~sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/sol-advisor"
printf '%s\n' '{"ts":"2026-08-05T10:00:00+09:00","task":"add retry to sync client","class":"implement","lane":"sol_advisor_terra_implementer","exception":null,"outcome":"success","attempts":1,"duration_s":540,"note":""}' >> "${CODEX_HOME:-$HOME/.codex}/sol-advisor/routing.jsonl"
~~~

A read-only sandbox refuses that write. Report the refusal rather than dropping the entry
silently; an unlogged delegation is invisible to the next retro. Keep it to one line per
outcome -- the ledger records decisions, not narration.
