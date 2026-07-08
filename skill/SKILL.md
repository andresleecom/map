---
name: map
description: "MAP — Massive Action Plan. Claude plans, interviews, and verifies; codex CLI executes. Use when the user types /map, asks to delegate implementation to codex, or when a coding task fits the delegation profile: spec-locked implementation, refactors, migrations, test writing, bulk mechanical edits. Suggest it proactively when a substantive task fits (ask before running unless the user invoked it). Claude keeps all judgment: design, naming, review, git, anything destructive."
---

# MAP — Massive Action Plan

Claude thinks. Codex types. Claude verifies. Nothing merges unreviewed.

## Why this exists

The session model (Claude) is the expensive, high-judgment resource. Codex CLI is the
cheap, tireless executor. A MAP converts a vague request into a frozen, verifiable plan
(where Claude's tokens are worth spending), then drains execution tokens into codex
(where they're nearly free). Success = Claude's context holds decisions, specs, and
diffs — never bulk code generation or bulk file reading.

## Token discipline (binding rules for Claude)

1. **Never bulk-read to "understand".** Read only what's needed to write the packet.
   For wide recon, dispatch a read-only codex survey (see Invocation) or an Explore
   subagent and consume only its report.
2. **Reference, don't paste.** Packets point at file paths; codex reads them locally
   for free. Only paste code when showing an exact pattern to replicate (≤15 lines).
3. **Verify from diffs.** `git diff --stat` first, then per-file diffs for what
   changed. Never re-read whole files a diff already shows.
4. **Read codex output by its REPORT.** Every packet requires codex to end with a
   `## REPORT` section (≤40 lines). Read that; open the full log only on failure.
5. **Compact artifacts.** MAP ≤ ~150 lines. Packets ≤ ~60 lines. Batch interview
   questions (≤4 per round, as few rounds as the tier needs).

## Triage — decide before doing anything

**Route to codex** (execution):
- Implementation from a locked spec; the design decisions are already made
- Refactors, renames, mechanical migrations, dead-code removal
- Bug fixes where the defect is already diagnosed
- Test writing / coverage expansion against existing behavior
- Bulk edits across many files; scaffolding from an established pattern
- Read-only surveys of large codebases (recon packets)

**Keep in Claude** (judgment):
- Design, API shape, naming, UX decisions — anywhere the spec IS the work
- Tiny edits (<~20 lines, obvious) — packet overhead exceeds the task
- Anything needing session tools: MCP servers, secrets, authenticated services
- All git operations, releases, deploys, destructive commands
- **All review and verification — never delegated, no exceptions**

**Pick a tier and announce it:**
- **S** — clear scope, ≤2 tasks: write the packet(s) directly, no interview.
- **M** — some ambiguity: one AskUserQuestion round to lock forks, then plan.
- **L** — significant scope: recon first, multi-round interview, decision
  register, phased task list. (Recon itself can be a codex survey packet.)

If the user typed `/map <task>`, triage that task. If Claude is suggesting MAP
on its own, ask first: "This fits /map — plan here, execute on codex. Run it?"

## Phase 1 — Plan

1. **Recon** to the depth the tier requires. Prefer delegated recon for anything wide.
2. **Interview** per tier. Lock every fork as a numbered decision (D01, D02…).
3. **Branch**: create `map/<slug>` from the agreed base. Never plan on a dirty tree —
   stash or stop.
4. **Write the MAP** at `.map/PLAN.md` (template: `reference/templates.md`):
   goal, non-goals, decision register, constraints, and a task table where every
   task has: scope, files, hard limits, verify bar, proof required.
   Also write `.map/.gitignore` containing `out/`.
5. **Commit the MAP** as the branch's first commit. The plan travels with the work;
   any future session resumes from it.
6. **Show the user the task table** and get a go (skippable if they said "just run it").

## Phase 2 — Execute (task loop)

For each task, in order (parallel only if tasks are provably file-disjoint, max 3):

1. **Packet**: write `.map/tasks/NN-<slug>.md` from the packet template. Include the
   contract (below) verbatim.
2. **Dispatch** codex in the background (see Invocation), output to
   `.map/out/NN.md`.
3. **Verify** when it returns — this is Claude acting as a hostile code reviewer:
   - `git status -sb` + `git diff --stat`: only in-scope files changed?
   - Read the per-file diffs. Judge correctness, style fit, scope creep.
   - Run the task's verify bar (from the MAP):
     - every task: build/typecheck
     - behavior-touching: + relevant tests
     - user-facing: + actually drive the affected flow
4. **Commit** on pass: Claude writes the commit, user's authorship, clean
   conventional message. **Never any AI attribution.** One commit per verified task.
5. **Log** one line to `.map/LOG.md`: task, strikes used, verdict, commit sha.
6. On fail → Failure protocol.

## Failure protocol — two strikes

- **Strike 1**: revert the working tree to the last commit (`git checkout -- .` +
  `git clean -fd` scoped to affected paths). Re-dispatch with a sharpened packet that
  names the exact defect ("your change broke X because Y; the fix must Z") and adds
  the missing context. Prefer `codex exec resume --last` for the retry — it keeps
  codex's session context and is cheaper than a fresh run — IF it accepts the
  sandbox flags in your environment (verify once; see reference). Else fresh dispatch.
- **Strike 2**: Claude implements the task itself. Log the takeover and why —
  patterns in the log teach what not to delegate next time.
- A run that exits without a REPORT counts as a strike. A quiet run does NOT —
  xhigh runs legitimately take up to ~30 min; only treat it as hung after that.
- A `blocked` REPORT usually means the packet was underspecified — that's a spec
  defect, not a codex defect. Fix the decision (record it in the MAP), then retry.

## Phase 3 — Close

1. Review the whole branch diff once (`git diff <base>...HEAD --stat`, then anything
   not yet reviewed at task level).
2. Run the full verify bar for the plan (build + tests + flows named in the MAP).
3. Final commit removes `.map/` (`git rm -r .map`) so the PR is clean.
4. Report to the user: what shipped, task-by-task verdicts, strikes/takeovers,
   commits, and anything deliberately left out.

## The codex contract (include verbatim in every packet)

```
HARD RULES — violating any of these means your work is discarded:
- NO git commands of any kind (no commit, branch, push, reset, checkout, stash).
- NO dependency changes: no package installs, no lockfile edits, no tool installs.
- Edit ONLY within the scope listed above. If the fix requires touching anything
  else, STOP and explain in your REPORT instead of doing it.
- If blocked or uncertain, STOP and report — do not improvise around the spec.
- End your output with:
  ## REPORT
  STATUS: done | blocked
  FILES TOUCHED: <list>
  PROOF: <output of the verification commands you were asked to run>
  NOTES: <≤10 lines: decisions made, anything the reviewer must know>
```

## Invocation

Full command reference, flags, and known gotchas: `reference/codex-invocation.md`.
The battle-tested shape (Git Bash, run in background, prompt ALWAYS via file):

```bash
codex exec -s workspace-write -c approval_policy=never --skip-git-repo-check \
  -c model_reasoning_effort=xhigh \
  -C "<absolute repo path>" -o ".map/out/NN.md" - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

- stdin **must** be closed or redirected (`- < file`) — codex waits on stdin
  forever otherwise. Never pass the prompt inline (audit trail + arg-length limits).
- `2>/dev/null` keeps thinking noise out of context; drop it only to debug a run.
- `model_reasoning_effort`: xhigh for implementation, `medium` for trivial
  mechanical tasks and surveys.
- Do **not** use `--yolo` / `--dangerously-bypass-approvals-and-sandbox` (blocked
  by restricted auto-mode classifiers, and they disable codex's own sandbox — a
  layer the hard-rules contract relies on). The flags above are the working
  equivalent.
- Be patient: quiet runs under ~30 min are normal at xhigh. Parallel dispatches
  need separate working dirs and separate `-o` files.

## Resume

If `.map/PLAN.md` exists on the current branch, a MAP is in flight. Read `PLAN.md`
and `LOG.md`, announce where it stands, and continue from the next incomplete task.
