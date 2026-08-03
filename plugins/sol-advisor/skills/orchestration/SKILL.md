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
something new. Termination is the architect's responsibility, not the reviewer's.

Budget: at most 3 final reviews per deliverable, meaning the first review plus at most 2
re-reviews. Count every final review, including one that follows a `rethink`.

Persist the count outside the conversation. Before each final review, append one line to
the ledger:

~~~sh
ledger_dir="${CODEX_HOME:-$HOME/.codex}/tmp/sol-advisor"
mkdir -p "$ledger_dir"
printf '%s | %s | cycle %s/3 | %s | %s\n' \
  "<UTC timestamp>" "<deliverable id>" "<n>" "<verdict, or pending>" "<one-line summary>" \
  >> "$ledger_dir/review-ledger.md"
~~~

Read that ledger to recover `n` after context compaction, a session restart, or a
handoff; never rely on conversation memory for the count.

The budget belongs to the deliverable. Never reset it because context was compacted, the
specification was corrected, the architecture was revised, or the scope was renegotiated.
Only an explicit user decision to change the goal starts a new deliverable id, and you
must say so when it happens.

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
