---
name: map
description: "MAP — Massive Action Plan. Claude plans, interviews, and verifies; codex CLI executes. Use when the user types /map, asks to delegate implementation to codex, or when a coding task fits the delegation profile: spec-locked implementation, refactors, migrations, test writing, bulk mechanical edits. Suggest it proactively when a substantive task fits (ask before running unless the user invoked it). Claude keeps all judgment: design, naming, review, git, anything destructive."
---

# MAP — Massive Action Plan

Claude thinks. Codex types. Claude verifies. Nothing merges unreviewed.

**Host rule:** MAP is for an orchestrator session (Claude Code, Grok, etc.) that can run git, review diffs, and invoke `codex exec`.
If you are already inside Codex (or another pure executor harness), do **not** self-delegate — implement or hand back to the orchestrator.

## Why this exists

The session model is the expensive, high-judgment resource.
Codex CLI running GPT-5.6-Sol is the cheap, tireless executor.
A MAP converts a vague request into a frozen, verifiable plan (where judgment tokens are worth spending), then drains execution tokens into codex (where they're nearly free).
Success = the orchestrator's context holds decisions, specs, and diffs — never bulk code generation or bulk file reading.

## Token discipline (binding rules for the orchestrator)

1. **Never bulk-read to "understand".** Read only what's needed to write the packet.
   For wide recon, dispatch a read-only codex survey (see Invocation) or an Explore
   subagent and consume only its report.
2. **Reference, don't paste.** Packets point at file paths; codex reads them locally
   for free. Only paste code when showing an exact pattern to replicate (≤15 lines).
3. **Verify from diffs.** `git diff --stat` first, then per-file diffs for what
   changed. Never re-read whole files a diff already shows.
4. **Read codex output by its REPORT.** Every packet requires codex to end with a
   `## REPORT` section (≤40 lines). Read that; open the full log only on failure.
   Codex PROOF is **advisory** — never trust it alone.
   Do **not** parse the JSONL session stream for results (session logs are only for
   finding a `session-id` on resume).
5. **Compact artifacts.** MAP ≤ ~150 lines. Packets ≤ ~60 lines. Batch interview
   questions (≤4 per round, as few rounds as the tier needs).

## Triage — decide before doing anything

**Heuristic:** if the request already reads as a work order with frozen decisions →
delegate; if writing the packet forces design choices → keep design in the
orchestrator, freeze decisions, then delegate build-out.

**Route to codex** (execution):
- Implementation from a locked spec; the design decisions are already made
- Refactors, renames, mechanical migrations, dead-code removal
- Bug fixes where the defect is already diagnosed
- Test writing / coverage expansion against existing behavior
- Bulk edits across many files; scaffolding from an established pattern
- Read-only surveys of large codebases (recon packets)

**Keep in the orchestrator** (judgment):
- Design, API shape, naming, UX decisions — anywhere the spec IS the work
- Tiny edits (<~20 lines, obvious) — packet overhead exceeds the task
- Anything needing session tools: MCP servers, secrets, authenticated services
- All git operations, releases, deploys, destructive commands
- **All review and verification — never delegated, no exceptions**

**Multi-repo / portfolio work:** do not stuff multiple repos into one MAP.
Orchestrate outside (one MAP per repo, or a higher-level plan).

**Pick a tier and announce it:**
- **S** — clear scope, ≤2 tasks: write the packet(s) directly, no interview.
- **M** — some ambiguity: one AskUserQuestion round to lock forks, then plan.
- **L** — significant scope: recon first, multi-round interview, decision
  register, phased task list. (Recon itself can be a codex survey packet.)

If the user typed `/map <task>`, triage that task.
If suggesting MAP on its own, ask first: "This fits /map — plan here, execute on codex. Run it?"

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
   `.map/out/NN.md`. Start with the default sandbox. If sandbox spawn death
   appears in stderr **and** the pass gate below would fail, re-dispatch with the
   documented fallback (not a model strike — see Failure protocol). If the pass
   gate is already green despite sandbox noise, do not re-dispatch — proceed.
3. **Verify** when it returns — hostile code review with a hard pass gate.
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
   Codex PROOF alone never counts as a pass.
4. **Commit** on pass: orchestrator writes the commit, user's authorship, clean
   conventional message. **Never any AI attribution.** One commit per verified task.
   In that same commit (or an immediate follow-up): set the task's Status in
   `.map/PLAN.md` to `done` and append the LOG line.
5. **Log** one line to `.map/LOG.md`: task, strikes used, verdict, commit sha
   (include `sandbox-retry` in the verdict when the Windows/sandbox fallback ran).
6. On fail → Failure protocol.

If the session denies an external write along the way (gh labels, issue comments,
anything outward-facing), queue the exact command verbatim in `.map/GH-QUEUE.md`
(template in `reference/templates.md`), commit it with the task's commit so it
travels with the branch, and move on — reconcile later instead of blocking the
loop. Drained in Phase 3.

## Failure protocol — two strikes

**Sandbox / infrastructure failures are not model strikes.**
If stderr or the REPORT shows `CreateProcessAsUserW failed`, Windows sandbox
spawn death (error **5** or **1312**), or the run did zero work because the shell
could not start: run the pass gate first. If it already passes (in-scope diff +
orchestrator verify green), accept the task and log a note — do not re-dispatch.
If the pass gate fails, re-dispatch once with the sandbox fallback from
`reference/codex-invocation.md` (`-s danger-full-access`).
Do not increment the strike counter for that retry.
If the fallback also cannot run, switch executors (see Executor fallback) or
take over in the orchestrator and log why.

**Model / quality failures use two strikes:**

- **Strike 1**: revert the task's changes to the last commit
  (`git checkout -- <task paths>` + `git clean -fd <task paths>`; never touch
  `.map/` — it holds uncommitted decisions and the queue). Re-dispatch with a
  sharpened packet —
  written to `.map/tasks/NN-<slug>-r2.md`, keeping the original for the audit
  trail — that names the exact defect ("your change broke X because Y; the fix
  must Z") and adds the missing context. If the failure was one of reasoning
  (not a spec gap), also escalate `model_reasoning_effort` to `max`. Prefer
  `codex exec resume <session-id>` for the retry — it keeps codex's session
  context and is cheaper than a fresh run — but resume takes different flags and
  forgets the model unless re-pinned (see reference).
- **Strike 2**: do **not** implement in the main session thread (and **never**
  under Fable). Dispatch a takeover packet to the pinned fallback executor
  (Claude Code: Opus 4.8 only; Grok Build: Grok 4.5 subagent — see Executor
  fallback). Orchestrator still runs the pass gate and commits. Log the
  takeover and why — patterns in the log teach what not to delegate next time.

Also treat as fail / strike material (not pass):
- Run exits without a REPORT.
- REPORT says `done` but the implementation diff is empty when work was required.
- REPORT says `done` while stderr shows sandbox death (re-dispatch as infrastructure, not pass).
- Orchestrator verify bar fails even if Codex PROOF looks green.

A quiet run does **not** count as hung: xhigh runs legitimately take up to ~30 min,
and a `max` retry can run longer (allow roughly double); only treat it as hung after that.

A `blocked` REPORT usually means the packet was underspecified — that's a spec
defect, not a codex defect. Fix the decision (record it in the MAP), then retry.

## Executor fallback — when codex is unavailable

Strikes are per task. This is different: codex can't run at all this session —
the permission classifier denies the plain `codex exec` dispatch, or the sandbox
fails every spawn even after a solo retry and the documented
`danger-full-access` fallback (reference, gotchas 2 and 6). The MAP
survives; only the executor changes.

### Hard rule: never dump implementation into the main session

When codex is unavailable, **do not** implement the packet in the orchestrator
thread (even if that thread is already Opus, Sonnet, Fable, or Grok).
Bulk generation in the main context is exactly what MAP exists to avoid.
Fallback execution always goes to a **pinned frontier subagent**.

### Banned for any MAP implementation path (absolute)

**Never** run packet implementation, strike-1 retry, strike-2 takeover, or
executor fallback on:

- **Fable** (any id: `claude-fable-*`, `fable`, session default Fable, etc.)
- Haiku / Sonnet (or other mid-tier aliases) as the *executor*
- The main session model via `inherit` / omitted `model`

Fable may remain the *orchestrator* (plan, interview, pass gate, commit) if the
user chose it for the session — that is fine. It must **never** be the model
that types product code for a MAP task. If the only available subagent would
inherit Fable, **stop** and tell the user to pin Opus 4.8 (or fix codex) rather
than implementing under Fable.

### Pinned fallback executor

House pins (update when a new frontier ships; do not drift to mid-tier models):

| Host | Fallback model | How to dispatch |
|------|----------------|-----------------|
| **Claude Code** | **Opus 4.8 only** | Agent/Task: `subagent_type=general-purpose`, **`model: claude-opus-4-8`** (required). Alias `opus` only if host docs still resolve it to 4.8 — prefer the full id. **Never** omit `model`. **Never** `fable` / `sonnet` / `haiku` / inherit. |
| **Grok Build** | **Grok 4.5** | `spawn_subagent` with `subagent_type=general-purpose` — Grok 4.5 agent stack. **Not** the main chat thread. |

Prefer **Codex (gpt-5.6-sol)** whenever it can run. Fallback is only when codex is
unavailable. Do not mix hosts mid-MAP: Claude Code sessions fall back to Opus 4.8;
Grok sessions fall back to Grok 4.5 subagents — not the other way around.

- A permission denial is a routing decision, not a flag problem. Swapping a
  blocked bypass flag (`--yolo`) for the sanctioned sandboxed form is fine;
  **never vary the sanctioned form after it is denied** — that reads as a
  bypass attempt. One denial of the plain dispatch → switch executors. (If only
  the subshell resume form is denied, codex is still available — retry as a
  fresh plain dispatch instead.)
- Record the switch as a numbered decision in `.map/PLAN.md`
  (e.g. `Dxx Executor = Opus 4.8 subagent — codex denied by auto-mode classifier`
  or `Dxx Executor = Grok 4.5 subagent — codex unavailable`).
- Dispatch the **same packets** to the pinned subagent. The packet and HARD
  RULES contract hold, REPORT format included; only the codex CLI invocation
  disappears — the subagent reads the packet file and returns its REPORT as its
  result. Save that REPORT to `.map/out/NN.md` to keep the audit trail.
  Log with `executor-switch (opus-4.8)` or `executor-switch (grok-4.5)`.
- The failure protocol applies minus the codex mechanics: a strike-1 retry is a
  **fresh pinned subagent** with the sharpened `-r2` packet (no codex resume, no
  effort escalation). Strike 2 is **also** a pinned subagent takeover — still
  **not** the main session typing the diff. The orchestrator only reviews, runs
  the pass gate, and commits. Strikes already accrued on a task carry across the
  switch.
- Review, verify bar, per-task commits: unchanged and **always** on the
  orchestrator. The discipline is the point, not the executor.
- If the trigger was the permission denial, suggest the user add
  `"Bash(codex exec:*)"` to `permissions.allow` in `~/.claude/settings.json`
  (user-level, holds across repos) — never edit that file yourself after a
  denial. Persistent sandbox spawn death (gotcha 6) has no settings fix after
  `danger-full-access` has already been tried.

## Phase 3 — Close

1. Review the whole branch diff once (`git diff <base>...HEAD --stat`, then anything
   not yet reviewed at task level). Prefer the host's review skill (`/review` or
   equivalent) on the branch when available.
2. Run the full verify bar for the plan (build + tests + flows named in the MAP).
3. Drain `.map/GH-QUEUE.md` if present: run the queued commands, or — if the
   session still can't — paste them verbatim into the step-5 report (and the PR
   description, if one exists) so they survive the next step.
4. Final commit removes `.map/` (`git rm -r .map`) so the PR is clean.
5. Report to the user: what shipped, task-by-task verdicts, strikes/takeovers,
   sandbox retries, executor switches, commits, and anything deliberately left out.

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

Full command reference, flags, sandbox fallback, and known gotchas:
`reference/codex-invocation.md`.

Default shape (Git Bash / macOS / Linux; prompt ALWAYS via file):

```bash
command codex exec -s workspace-write -c approval_policy=never --skip-git-repo-check \
  -m gpt-5.6-sol -c model_reasoning_effort=xhigh \
  -C "<absolute repo path>" -o ".map/out/NN.md" - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

Windows sandbox fallback (after sandbox spawn death, or when `workspace-write`
is known dead on this machine — see reference):

```bash
command codex exec -s danger-full-access -c approval_policy=never --skip-git-repo-check \
  -m gpt-5.6-sol -c model_reasoning_effort=xhigh \
  -C "<absolute repo path>" -o ".map/out/NN.md" - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

- `command codex` bypasses shell aliases/wrappers. If `codex` is missing from PATH
  under fnm/nvm, see the reference for recovery.
- On Windows, run under **Git Bash** (`"C:/Program Files/Git/bin/bash.exe"`), never WSL bash.
- stdin **must** be closed or redirected (`- < file`). Always pass the prompt via file
  (audit trail + arg-length limits). Some non-TTY hosts exit with "No prompt provided"
  instead of hanging — the file redirect is still mandatory.
- `2>/dev/null` keeps thinking noise out of context; drop it only to debug a run.
- `-m gpt-5.6-sol`: always pin the model — never ride the machine's config default.
- `model_reasoning_effort`: never omit it. `xhigh` for implementation, `medium` for
  trivial mechanical tasks and surveys, `max` for strike-1 retries of reasoning
  failures. Never `ultra` in packets.
- Do **not** use `--yolo` / `--dangerously-bypass-approvals-and-sandbox` (blocked by
  restricted auto-mode classifiers). Prefer `-s workspace-write` first.
  `-s danger-full-access` is the documented Windows fallback only — it is a sandbox
  mode flag, not the long bypass flag.
- Be patient: quiet runs under ~30 min are normal at xhigh. Parallel dispatches
  need separate working dirs and separate `-o` files.

## Resume

If `.map/PLAN.md` exists on the current branch, a MAP is in flight.
Read `PLAN.md` and `LOG.md`, announce where it stands (call out PLAN/LOG drift),
and continue from the next incomplete task.
