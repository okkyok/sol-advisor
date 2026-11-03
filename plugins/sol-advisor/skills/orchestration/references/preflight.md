# Preflight the companion custom agents

Complete this before the first delegation, and before accepting any lane's result.
These checks are the same ones [SKILL.md](../SKILL.md) requires.

The six role files are user-owned native custom-agent TOML files. Installing or updating
the plugin does not automatically register them. Install them separately and start a
fresh Codex task so native discovery sees current profiles.

## Required roles and pins

| `agent_type` | Pinned model / effort | Use |
|---|---|---|
| `sol_advisor_luna_committer` | `gpt-6-luna` / low | Mechanical, fully determined edits |
| `sol_advisor_luna_implementer` | `gpt-6-luna` / high | Default ordinary well-specified work |
| `sol_advisor_luna_deep` | `gpt-6-luna` / max | Qualifying narrow retry |
| `sol_advisor_sol_worker` | `gpt-6.1-sol` / medium | Broad work and senior escalation |
| `sol_advisor_sol_reviewer` | `gpt-6.1-sol` / medium, read-only | High-risk review |
| `sol_advisor_astra_consultant` | `gpt-6-astra` / medium, read-only | Frontier consult |

## Checks

1. Complete steps 1-2 once per session. Before every delegation, repeat steps 2-3.
   After spawning, complete steps 4-5 before accepting its result.
2. Verify hook enforcement with a fresh literal nonce:

   ~~~sh
   references_dir=<directory-containing-this-file>
   checker="$references_dir/../../scripts/check-hook-trust.sh"
   sh "$checker" --nonce liveness-CHANGEME
   ~~~

   Replace `CHANGEME` with a fresh 4-64 character `[A-Za-z0-9_.:-]` token. A literal
   nonce proves the heartbeat belongs to this invocation. `HOOK ACTIVE` means the host
   enforces the review budget; `HOOK INERT` means the loop is not machine-enforced and
   must be reported. Read the ledger from the printed data directory.
3. Resolve `../../scripts/install-agents.sh` relative to this file and run its
   non-mutating exactness check:

   ~~~sh
   references_dir=<directory-containing-this-file>
   installer="$references_dir/../../scripts/install-agents.sh"
   sh "$installer" --check
   ~~~

   It must exit zero and prove all six files match current templates with no retired
   companion file. Stop the affected lane on a missing, stale, unsafe, or conflicting
   file; report installer path and destination.
4. Inspect native exposure of all six exact `agent_type` names. Use public native spawn/details metadata first. It must identify the selected role. Compare exposed
   model and effort with the table. If either is omitted and the local rollout is
   accessible, resolve `../../scripts/inspect-agent-runtime.sh` relative to this file
   and run it with the native thread id. Public and local values must agree. Stop on
   missing, inconsistent, unavailable, or unobservable routing.
5. For the reviewer and consultant, capture actual sandbox policy and permission
   profile types. Both request read-only. Call isolation enforced only when the observed
   sandbox policy is `read-only`; stop if the required isolation is unobservable or a
   mutation occurs.

Never silently substitute a role, model, or effort, and never attach per-spawn model or
reasoning overrides. The role files pin model and effort.
