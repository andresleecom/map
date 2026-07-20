---
name: map
description: "MAP - Massive Action Plan. Orchestrator (prefer Fable 5; else Codex 5.6 Sol) plans, interviews, and verifies; Grok 4.5 CLI codes (fastest). Fallback coders: Codex Sol, then Opus 4.8. Use when the user types /map, asks to delegate implementation, or when a coding task fits the delegation profile: spec-locked implementation, refactors, migrations, test writing, bulk mechanical edits. Suggest it proactively when a substantive task fits (ask before running unless the user invoked it). Orchestrator keeps all judgment: design, naming, review, git, anything destructive. Never implement under Fable."
---

# MAP - Massive Action Plan

Orchestrator thinks. Grok types. Orchestrator verifies. Nothing merges unreviewed.

## House roles (binding)

You use **Claude Code**, **Grok Build / Grok CLI**, and **Codex CLI** together.
Pick the orchestrator session first; dispatch coding out of band.

| Role | Preferred | Fallback |
|------|-----------|----------|
| **Orchestrator** (plan, interview, pass gate, git, review) | **Fable 5** (Claude Code session) | **Codex 5.6 Sol** when Fable 5 is not available |
| **Coding executor** (packet implementation) | **Grok 4.5** CLI (fastest for coding) | **Codex 5.6 Sol** → **Opus 4.8** subagent |

**Absolute:** Fable (any id, including Fable 5) may **orchestrate** but must **never** type product code for a MAP task.

**Host rule:** MAP needs an orchestrator session that can run git, review diffs, and
dispatch a coding CLI (`grok` and/or `codex exec`).
- Prefer a **Claude Code** session on **Fable 5**.
- If Fable 5 is unavailable, use a **Codex 5.6 Sol** session as orchestrator (and still prefer headless **Grok 4.5** for packet coding when Grok is available).
- **Grok Build** may orchestrate too; still dispatch coding to a headless executor (Grok subagent or Codex), not silent main-thread bulk impl.
- If you are already inside a pure one-shot executor with no plan/review tools, do **not** pretend to MAP-orchestrate - implement a frozen packet or hand back to the orchestrator.

## Why this exists

The session model is the expensive, high-judgment resource (house: Fable 5).
Grok 4.5 is the fast coding executor; Codex 5.6 Sol is the strong coding fallback
(and the orchestrator fallback when Fable 5 is missing).
A MAP converts a vague request into a frozen, verifiable plan (where judgment tokens
are worth spending), then drains execution tokens into a coding CLI.
Success = the orchestrator's context holds decisions, specs, and diffs - never bulk
code generation or bulk file reading.

## Token discipline (binding rules for the orchestrator)

1. **Never bulk-read to "understand".** Read only what's needed to write the packet.
   For wide recon, dispatch a read-only coding survey (Grok or Codex - see Invocation)
   or an Explore subagent and consume only its report.
2. **Reference, don't paste.** Packets point at file paths; the executor reads them
   locally for free. Only paste code when showing an exact pattern to replicate (≤15 lines).
3. **Verify from diffs.** `git diff --stat` first, then per-file diffs for what
   changed. Never re-read whole files a diff already shows.
4. **Read executor output by its REPORT.** Every packet requires the executor to end
   with a `## REPORT` section (≤40 lines). Read that; open the full log only on failure.
   Executor PROOF is **advisory** - never trust it alone.
   Do **not** parse Codex JSONL session streams for results (session logs are only for
   finding a `session-id` on resume).
5. **Compact artifacts.** MAP ≤ ~150 lines. Packets ≤ ~60 lines. Batch interview
   questions (≤4 per round, as few rounds as the tier needs).

## Triage - decide before doing anything

**Heuristic:** if the request already reads as a work order with frozen decisions →
delegate; if writing the packet forces design choices → keep design in the
orchestrator, freeze decisions, then delegate build-out.

**Route to coding executor** (Grok 4.5 first):
- Implementation from a locked spec; the design decisions are already made
- Refactors, renames, mechanical migrations, dead-code removal
- Bug fixes where the defect is already diagnosed
- Test writing / coverage expansion against existing behavior
- Bulk edits across many files; scaffolding from an established pattern
- Read-only surveys of large codebases (recon packets)

**Keep in the orchestrator** (judgment - Fable 5 preferred):
- Design, API shape, naming, UX decisions - anywhere the spec IS the work
- Tiny edits (<~20 lines, obvious) - packet overhead exceeds the task
- Anything needing session tools: MCP servers, secrets, authenticated services
- All git operations, releases, deploys, destructive commands
- **All review and verification - never delegated, no exceptions**

**Multi-repo / portfolio work:** do not stuff multiple repos into one MAP.
Orchestrate outside (one MAP per repo, or a higher-level plan).

**Pick a tier and announce it:**
- **S** - clear scope, ≤2 tasks: write the packet(s) directly, no interview.
- **M** - some ambiguity: one AskUserQuestion round to lock forks, then plan.
- **L** - significant scope: recon first, multi-round interview, decision
  register, phased task list. (Recon itself can be a coding survey packet.)

If the user typed `/map <task>`, triage that task.
If suggesting MAP on its own, ask first: "This fits /map - plan here, execute on Grok 4.5. Run it?"

## Phase 0 - Prism (multi-perspective scope expansion)

For tier L (and recommended for M): before planning, fan the user's VERBATIM request out to 8-12 parallel read-only cheap-executor agents (Kimi/Grok CLI), each analyzing through ONE assigned lens (intent, minimal, maximal, adversarial, architecture, ux-product, ops-cost, interrogator), reports capped at 40 lines in `.map/prism/`. Lenses never see each other. The orchestrator then synthesizes `.map/PRISM.md`: converged scope, DIVERGENCES (each becomes a user question or a decision), <=4 distilled questions feeding the interview, and a scope statement the user can veto. Parallel dispatch is validated to 100 concurrent agents (see `research/parallelism/` in this repo); the real limits are file disjointness and review bandwidth, not CLI capacity. Full protocol + dispatch snippet: `reference/prism.md`.

## Phase 1 - Plan

1. **Recon** to the depth the tier requires. Prefer delegated recon for anything wide.
2. **Interview** per tier. Lock every fork as a numbered decision (D01, D02…).
3. **Branch**: create `map/<slug>` from the agreed base. Never plan on a dirty tree -
   stash or stop.
4. **Write the MAP** at `.map/PLAN.md` (template: `reference/templates.md`):
   goal, non-goals, decision register, constraints, and a task table where every
   task has: scope, files, hard limits, verify bar, proof required.
   Also write `.map/.gitignore` containing `out/`.
   Record house roles when non-default, e.g.
   `D01 Orchestrator = fable-5` / `D02 Executor primary = grok-4.5`.
5. **Commit the MAP** as the branch's first commit. The plan travels with the work;
   any future session resumes from it.
6. **Show the user the task table** and get a go (skippable if they said "just run it").

## Phase 2 - Execute (task loop)

For each task, in order (parallel only if tasks are provably file-disjoint, max 3):

1. **Packet**: write `.map/tasks/NN-<slug>.md` from the packet template. Include the
   contract (below) verbatim.
2. **Dispatch** the coding executor in the background (see Invocation), output to
   `.map/out/NN.md`. **Default: Grok 4.5 CLI.** If Grok cannot run, use Codex Sol.
   For Codex: start with the default sandbox. If sandbox spawn death appears in
   stderr **and** the pass gate below would fail, re-dispatch with the documented
   sandbox fallback (not a model strike - see Failure protocol). If the pass gate
   is already green despite sandbox noise, do not re-dispatch - proceed.
3. **Verify** when it returns - hostile code review with a hard pass gate.
   A task **passes only if all three hold**:
   1. REPORT has `STATUS: done` (and a real REPORT section exists).
   2. `git status -sb` + `git diff --stat` show only in-scope files changed;
      for an implementation task the diff must not be empty unless the packet
      explicitly allowed a no-op.
   3. The **orchestrator** re-runs the task's verify bar and it passes:
      - every task: build/typecheck
      - behavior-touching: + relevant tests
      - user-facing: + actually drive the affected flow
   Also judge correctness, style fit, and scope creep from the per-file diffs.
   Executor PROOF alone never counts as a pass.
4. **Commit** on pass: orchestrator writes the commit, user's authorship, clean
   conventional message. **Never any AI attribution.** One commit per verified task.
   In that same commit (or an immediate follow-up): set the task's Status in
   `.map/PLAN.md` to `done` and append the LOG line.
5. **Log** one line to `.map/LOG.md`: task, strikes used, verdict, commit sha
   (include `sandbox-retry` when the Windows/sandbox fallback ran;
   include `executor-switch (...)` when not on the primary).
6. On fail → Failure protocol.

If the session denies an external write along the way (gh labels, issue comments,
anything outward-facing), queue the exact command verbatim in `.map/GH-QUEUE.md`
(template in `reference/templates.md`), commit it with the task's commit so it
travels with the branch, and move on - reconcile later instead of blocking the
loop. Drained in Phase 3.

## Failure protocol - two strikes

**Sandbox / infrastructure failures are not model strikes.**
If stderr or the REPORT shows `CreateProcessAsUserW failed`, Windows sandbox
spawn death (error **5** or **1312**), Grok agent-build failures from bad flags
(e.g. broken `--disallowed-tools Agent`), or the run did zero work because the shell
could not start: run the pass gate first. If it already passes (in-scope diff +
orchestrator verify green), accept the task and log a note - do not re-dispatch.
If the pass gate fails on a Codex run, re-dispatch once with the sandbox fallback from
`reference/codex-invocation.md` (`-s danger-full-access`).
Do not increment the strike counter for that retry.
If the primary executor cannot run at all, switch executors (see Executor chain) or
take over per the Sol-as-orchestrator exception below and log why.

**Model / quality failures use two strikes:**

- **Strike 1**: revert the task's changes to the last commit
  (`git checkout -- <task paths>` + `git clean -fd <task paths>`; never touch
  `.map/` - it holds uncommitted decisions and the queue). Re-dispatch with a
  sharpened packet -
  written to `.map/tasks/NN-<slug>-r2.md`, keeping the original for the audit
  trail - that names the exact defect ("your change broke X because Y; the fix
  must Z") and adds the missing context. Escalate reasoning effort when the failure
  was reasoning (not a spec gap). Prefer session resume only when the executor
  supports it cleanly (Codex `resume` - see reference).
- **Strike 2**: do **not** implement under **Fable**. Dispatch a takeover packet to
  the next executor in the chain (Codex Sol if Grok failed quality; Opus 4.8 if both
  CLIs failed). Orchestrator still runs the pass gate and commits. Log the
  takeover and why - patterns in the log teach what not to delegate next time.

**Sol-as-orchestrator exception:** when the orchestrator session *is* Codex 5.6 Sol
(because Fable 5 was unavailable) **and** Grok CLI cannot run, Sol may implement the
packet in-session after logging `executor = codex-sol (orchestrator impl)`. That is
allowed only because Sol is a coding-class model. **Never** do this under Fable.

Also treat as fail / strike material (not pass):
- Run exits without a REPORT.
- REPORT says `done` but the implementation diff is empty when work was required.
- REPORT says `done` while stderr shows sandbox death (re-dispatch as infrastructure, not pass).
- Orchestrator verify bar fails even if executor PROOF looks green.

A quiet run does **not** count as hung: `high` runs usually finish in a few
minutes; if you escalated effort, allow longer (~30 min for `xhigh`/`max`);
only treat it as hung after that.

A `blocked` REPORT usually means the packet was underspecified - that's a spec
defect, not an executor defect. Fix the decision (record it in the MAP), then retry.

## Executor chain - Grok 4.5, then Codex Sol, then Opus

Strikes are per task. **Executor switches** are different: the preferred CLI
executor can't run (or the PLAN picks another). The MAP survives; only who types
the code changes.

### Order (binding)

1. **Grok CLI** `grok-4.5` - **default.** Fastest house coding model. See
   `reference/grok-invocation.md`.
2. **Codex** `gpt-5.6-sol` - when Grok is unavailable, denied, or the decision
   register assigns Sol for quality/depth. See `reference/codex-invocation.md`.
3. **Opus 4.8 subagent** - last resort only if both CLIs fail (and Sol is not the
   orchestrator implementing under the exception above). Agent/Task with
   `model: claude-opus-4-8`. **Never Fable.**

### Hard rule: never dump implementation into a judgment session

**Do not** implement the packet in a Fable (or other judgment-only) main thread.
Bulk generation in the orchestrator context is exactly what MAP exists to avoid -
except the narrow Sol-as-orchestrator exception above.

### Banned for any MAP implementation path (absolute)

**Never** run packet implementation, strike-1 retry, strike-2 takeover, or
executor fallback on:

- **Fable** (any id: `claude-fable-*`, `fable`, Fable 5, session default Fable, etc.)
- Haiku / Sonnet (or other mid-tier aliases) as the *executor*
- The main session model via `inherit` / omitted `model` when that model is Fable
  or another non-coding pin

Fable 5 is the **preferred orchestrator** (plan, interview, pass gate, commit).
It must **never** be the model that types product code for a MAP task. If the only
available subagent would inherit Fable, **stop** and tell the user to pin Opus 4.8
or fix Grok/Codex rather than implementing under Fable.

### Pinned CLI / subagent executors

| Priority | Executor | How the orchestrator dispatches |
|----------|----------|--------------------------------|
| 1 | Grok 4.5 CLI | `command grok --prompt-file .map/tasks/... --cwd <repo> -m grok-4.5 ...` - `reference/grok-invocation.md` |
| 2 | Codex Sol | `command codex exec ...` - `reference/codex-invocation.md` |
| 3 | Opus 4.8 | Agent/Task `general-purpose` + **`model: claude-opus-4-8`** (required; never inherit) |

If the orchestrator **is** Grok Build: still do not silently bulk-impl in the main
thread - use a Grok 4.5 `spawn_subagent` or Codex Sol for packets. See
`reference/grok-invocation.md`.

- A permission denial is a routing decision, not a flag problem. Swapping a
  blocked bypass flag for the documented sanctioned form is fine once;
  **never thrash flags after a denial** - that reads as a bypass attempt.
  One denial of the plain **Grok** dispatch → try **Codex Sol**, else Opus 4.8
  (or Sol-as-orchestrator impl if that is the session).
- Record the switch as a numbered decision in `.map/PLAN.md`
  (e.g. `Dxx Executor = codex gpt-5.6-sol - grok denied by auto-mode classifier`).
- Dispatch the **same packets**. HARD RULES and REPORT format hold; only the
  launcher changes. Save stdout / REPORT to `.map/out/NN.md`.
  Log `executor-switch (codex-sol)` or `executor-switch (opus-4.8)`.
- Strike-1 on any executor: fresh run with `-r2` packet when needed. Strike 2:
  next chain step - still **not** Fable typing the diff. Orchestrator only
  pass-gates and commits. Strikes carry across switches.
- Review, verify bar, per-task commits: always on the orchestrator.
- Permission denials: suggest user allowlist (never edit settings yourself after
  a denial). Rules must match the dispatch shape, which starts with `command `:
  `"Bash(command grok:*)"`, `"Bash(command grok.exe:*)"`, `"Bash(command kimi:*)"`,
  and/or `"Bash(command codex exec:*)"` in `permissions.allow`. Bare forms like
  `"Bash(grok:*)"` never match a real dispatch - keep them only for direct calls
  (`grok --version`). Codex sandbox spawn death: `danger-full-access` once,
  then switch executors.

## Phase 3 - Close

1. Review the whole branch diff once (`git diff <base>...HEAD --stat`, then anything
   not yet reviewed at task level). Prefer the host's review skill (`/review` or
   equivalent) on the branch when available.
2. Run the full verify bar for the plan (build + tests + flows named in the MAP).
3. Drain `.map/GH-QUEUE.md` if present: run the queued commands, or - if the
   session still can't - paste them verbatim into the step-5 report (and the PR
   description, if one exists) so they survive the next step.
4. Final commit removes `.map/` (`git rm -r .map`) so the PR is clean.
5. Report to the user: what shipped, task-by-task verdicts, strikes/takeovers,
   sandbox retries, executor switches, commits, and anything deliberately left out.

## The executor contract (include verbatim in every packet)

```
HARD RULES - violating any of these means your work is discarded:
- NO git commands of any kind (no commit, branch, push, reset, checkout, stash).
- NO dependency changes: no package installs, no lockfile edits, no tool installs.
- Edit ONLY within the scope listed above. If the fix requires touching anything
  else, STOP and explain in your REPORT instead of doing it.
- If blocked or uncertain, STOP and report - do not improvise around the spec.
- End your output with:
  ## REPORT
  STATUS: done | blocked
  FILES TOUCHED: <list>
  PROOF: <output of the verification commands you were asked to run>
  NOTES: <≤10 lines: decisions made, anything the reviewer must know>
```

## Invocation

**Grok CLI (primary coding executor):** `reference/grok-invocation.md`.

**Codex (secondary coding executor / Sol-as-orchestrator):** `reference/codex-invocation.md`.

### Default Grok shape (primary)

```bash
command grok \
  --prompt-file ".map/tasks/NN-<slug>.md" \
  --cwd "<absolute repo path>" \
  -m grok-4.5 \
  --reasoning-effort high \
  --yolo \
  --no-subagents \
  --deny "Bash(git*)" \
  --output-format plain \
  > ".map/out/NN.md" 2> ".map/out/NN.stderr.log"
```

### Codex shape (fallback coding; prompt ALWAYS via file)

```bash
command codex exec -s workspace-write -c approval_policy=never --skip-git-repo-check \
  -m gpt-5.6-sol -c model_reasoning_effort=high \
  -C "<absolute repo path>" -o ".map/out/NN.md" - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

Windows sandbox fallback for Codex (after sandbox spawn death, or when `workspace-write`
is known dead on this machine - see reference):

```bash
command codex exec -s danger-full-access -c approval_policy=never --skip-git-repo-check \
  -m gpt-5.6-sol -c model_reasoning_effort=high \
  -C "<absolute repo path>" -o ".map/out/NN.md" - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

- Prefer **Grok 4.5** for coding speed; use **Codex Sol** when Grok is down or the
  PLAN assigns Sol for depth.
- On Windows, run Codex under **Git Bash** (`"C:/Program Files/Git/bin/bash.exe"`), never WSL bash.
- Codex stdin **must** be closed or redirected (`- < file`). Always pass the prompt via file.
- Codex: do **not** use `--yolo` / `--dangerously-bypass-approvals-and-sandbox` (blocked by
  restricted auto-mode classifiers). Prefer `-s workspace-write` first.
- Grok: use `--no-subagents` (not `--disallowed-tools Agent` - broken on some Grok CLI builds).
- Be patient: quiet runs of a few minutes are normal at `high`; do not kill early.
  Parallel dispatches need separate working dirs and separate `-o` files.

## Resume

If `.map/PLAN.md` exists on the current branch, a MAP is in flight.
Read `PLAN.md` and `LOG.md`, announce where it stands (call out PLAN/LOG drift),
and continue from the next incomplete task.
