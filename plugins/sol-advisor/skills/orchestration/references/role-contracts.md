# Native Codex role contracts

Use these contracts with Sol Advisor's role-pinned native custom agents. They do not
launch a nested Codex CLI or change global default-subagent routing. Adapt every
placeholder without removing a required field.

## Required preflight

Before each spawn, check exact installed files and exposed role names. Inspect public
native spawn/details metadata first; use the local runtime inspector only for omitted
fields. Confirm the selected role, model, and effort match its pin. For reviewer and
consultant roles, capture sandbox policy and permission profile types. Stop on missing,
stale, unsafe, conflicting, unavailable, inconsistent, or unobservable routing.

## Shared implementation contract

Every implementation prompt must contain all five sections:

~~~text
OBJECTIVE
<Observable outcome and why it matters.>

FILES AND OWNERSHIP
You own only:
- <exact file or module>

You are not alone in the codebase. Other agents or the user may be editing concurrently.
Preserve their edits, do not revert unrelated work, and adapt to changes already present.
Do not modify files outside your ownership.

INTERFACES
- <Signatures, types, schemas, commands, or behavior that must remain compatible.>

CONSTRAINTS
- <Repository conventions, safety boundaries, excluded scope, and settled decisions.>

VERIFICATION
- Run: <exact command>
  Success: <concrete expected result>
- Inspect: <exact file, diff, or generated artifact>
  Success: <concrete expected evidence>

RETURN
Return exact commands and actual evidence. A completion claim without evidence is invalid.

IMPLEMENTATION REPORT
STATUS: complete | partial | blocked
OBJECTIVE: <one-line restatement>
CHANGES: <file-by-file summary from the actual diff>
VERIFIED: <exact commands plus concrete output evidence>
JUDGMENT CALLS: <decisions the specification left open, or none>
GAPS: <unfinished work, ambiguity, or none>
~~~

The primary session inspects the diff and reruns verification.

## Luna committer — mechanical edits

Use for mechanical, fully determined changes. A blocked return is a routing error; send
the task to the implementer without counting a failure step.

~~~text
agent_type: sol_advisor_luna_committer
fork_turns: none
~~~

Pinned `gpt-6-luna` / low. If the specification requires choosing between reasonable
designs or underdetermines the result, return `STATUS: blocked` and the open question.

## Luna implementer — default

Use for ordinary, well-specified implementation, exploration, or ingest.

~~~text
agent_type: sol_advisor_luna_implementer
fork_turns: none
~~~

Pinned `gpt-6-luna` / high. Resolve the specification within settled architecture and
surface ambiguity rather than redesigning it.

## Luna deep — narrow retry

Use only after one prior failure when the retry is at most 3 files, has runnable
verification, and the failure was reasoning on a clear specification.

~~~text
agent_type: sol_advisor_luna_deep
fork_turns: none
~~~

Pinned `gpt-6-luna` / max. Stay within the specified files and report blocked rather than
widening scope.

## Sol worker — broad work and senior escalation

Use first for several interacting components, integration-heavy interfaces, and
wide-search debugging; use also after two failures on one objective or when a local
judgment cannot be pinned down in a specification.

~~~text
agent_type: sol_advisor_sol_worker
fork_turns: none
~~~

Pinned `gpt-6.1-sol` / medium. Implement against the specification and report blocked if
the specification itself is wrong.

## Sol reviewer — senior read-only review

Use for security, schema, public API, migration, concurrency, irreversible or wide-blast
radius changes, or work that resisted two attempts.

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

Pinned `gpt-6.1-sol` / medium, read-only. Packet:

~~~text
ROLE
Review the actual change set. Remain read-only; never implement.

GOAL AND CONSTRAINTS
<Goal and constraints.>

DIFF AND VERIFICATION
<Complete diff and exact verification result.>

SILENCE GAP
<List paths the change should have touched but did not: callers, parallel implementations,
adjacent config.>

REVIEW
Cycle 1 already defined the complete finding set. Stay under 300 words. Scope inflation is a defect, not a preference. A change set that delivers artifacts the objective did not ask for fails the objective like a missing requirement. Judge correctness, completeness, regressions, scope, interfaces, and material risk. Return
ship, fix-first, or rethink with evidence. If framing itself is in doubt, add a final line:
ESCALATE: <one-sentence reason>
~~~

## Astra consultant — frontier consult

Consult before the next implementation attempt for architectural deadlock or a failed Sol
worker (a failure after its one corrected-spec retry, or a failed senior escalation), before
the first attempt for an expensive-to-reverse decision, and once on a review stop
condition before returning to the user.

~~~text
agent_type: sol_advisor_astra_consultant
fork_turns: none
~~~

Pinned `gpt-6-astra` / medium, read-only. The packet starts with `COMMITMENT BOUNDARY` (an audit marker; the hook
identifies the consult by agent type) and
contains the decisive question, current approach, evidence, and what failed. Require:

~~~text
RECOMMENDATION: proceed | change | stop
LARGEST RISK: <one>
REFRAMED APPROACH: <required for change; otherwise none>
~~~

A `change` recommendation becomes a new specification; a patched specification retains
its failure count. Astra never implements. The consult is uncounted by the review budget.
