# MAP templates

Copy these shapes; keep them compact. The MAP ≤ ~150 lines, packets ≤ ~60.

## `.map/PLAN.md`

```markdown
# MAP: <title>

**Goal:** <one sentence — what is true when this MAP is done>
**Base:** <branch/sha> · **Branch:** map/<slug> · **Tier:** S|M|L
**Non-goals:** <what we are deliberately NOT doing>

## Decisions
- D01 <decision> — <one-line rationale>
- D02 …

## Constraints
- <project-wide rules codex must honor: style, patterns, files that are off-limits>

## Verify commands
- build/typecheck: `<command>`
- tests: `<command>`
- flow check: <how to drive the affected behavior, if user-facing>

## Tasks
| # | Task | Scope (files/areas) | Bar | Status |
|---|------|---------------------|-----|--------|
| 01 | <verb phrase> | <paths> | build | pending |
| 02 | <verb phrase> | <paths> | build+tests | pending |

Bar legend: build = diff review + build/typecheck · +tests = also relevant tests ·
+flow = also drive the affected flow.

Status values: `pending` · `done` · `blocked` · `takeover`.
Update Status in the same commit as the verified task (or the immediate log commit).
```

## `.map/tasks/NN-<slug>.md` (the packet)

```markdown
# Task NN: <title>

## Goal
<2-4 sentences. What must be true when you finish.>

## Context — read these first
- <file path> — <why it matters>
- Pattern to follow: <file path or ≤15-line snippet>

## Scope — you may edit
- <explicit paths/globs>

## Out of scope — do not touch
- <paths, and anything not listed under Scope>

## Steps
1. <only if ordering matters; otherwise omit>

## Verify before reporting
Run: `<build/typecheck command>` <and tests if the bar requires>
Paste the output in your REPORT under PROOF.

HARD RULES — violating any of these means your work is discarded:
- NO git commands of any kind (no commit, branch, push, reset, checkout, stash).
- NO dependency changes: no package installs, no lockfile edits, no tool installs.
  If your solution needs a library the module does not declare, STOP and say so
  in NOTES instead of writing code that cannot compile.
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

## `.map/LOG.md`

```markdown
# MAP log: <title>

| # | Task | Strikes | Verdict | Commit |
|---|------|---------|---------|--------|
| 01 | <task> | 0 | pass | <sha> |
| 02 | <task> | 0 | pass (sandbox-retry) | <sha> |
| 03 | <task> | 1 | pass (retry: <defect named>) | <sha> |
| 04 | <task> | 2 | takeover (<why codex failed>) | <sha> |
```

Verdict notes: use `sandbox-retry` when the Windows/sandbox fallback ran;
use `takeover (opus-4.8)` or `takeover (codex-sol)` when a pinned fallback
implemented after two strikes - never a silent Fable impl and **never Fable**
as an executor label;
use `executor-switch (codex-sol)` when Sol ran because Grok could not (or PLAN
assigned Sol); use `executor-switch (opus-4.8)` for last-resort Opus;
use `executor = codex-sol (orchestrator impl)` only when Fable 5 was unavailable
so Sol was the orchestrator and Grok could not run.

## `.map/GH-QUEUE.md` (only if a session denies external writes)

```markdown
# GH queue: external writes denied this session — run verbatim to reconcile

gh issue edit 42 --add-label wip
gh issue comment 42 --body "Verified: <what was checked, residual risks>"
```

One ready-to-paste command per line, exact arguments. Committed with the task's
commit; drained (run or handed to the user) in Phase 3 before `.map/` is removed.


## `.map/.gitignore`

```
out/
```
