# map — Massive Action Plan

**Claude plans. Codex executes. Claude verifies. Nothing merges unreviewed.**

`map` is a [Claude Code skill](https://code.claude.com/docs/en/skills) that splits
coding work by comparative advantage: the expensive frontier model in your session
handles judgment — recon, interviewing you, freezing decisions, writing specs,
reviewing diffs — while [Codex CLI](https://github.com/openai/codex) (pinned to
GPT-5.6-Sol) burns the cheap tokens actually typing the code.

```
you ──/map──▶ orchestrator                            codex
               │  triage (S/M/L)                        │
               │  recon + interview + decisions         │
               │  .map/PLAN.md on branch map/<slug>     │
               │                                        │
               │── task packet 01 ─────────────────────▶│ edits (no git, no deps)
               │◀───────────────────────── REPORT ──────│
               │  hostile verify: diff + re-run bar     │
               │  commit (your authorship)              │
               │── task packet 02 ─────────────────────▶│ …
               │     sandbox death → fallback, not strike
               │            two strikes → orchestrator takes over
               ▼
          final review · .map/ removed · handoff report
```

## Why

Frontier-model tokens are the scarce resource in an agentic session. Most of a
coding task's tokens go to *generation and bulk reading* — work a cheaper model does
fine when the spec is frozen. `map` makes the split systematic:

- **A real plan, not a prompt.** Ambiguity is resolved *with you* (batched interview
  rounds) before anything executes. Decisions get numbered and frozen into
  `.map/PLAN.md`, committed on the work branch — the plan travels with the code and
  any future session resumes from it.
- **Checkpointed execution.** Codex gets one verifiable task packet at a time. The
  orchestrator reviews the diff as a hostile code reviewer, re-runs the task's
  verify bar (build → tests → drive-the-flow), and commits per verified task.
  Codex PROOF is advisory only.
- **Two strikes / executor chain.** Prefer **Codex**; if Codex can't run, Claude
  dispatches **Grok CLI** headless (`grok-4.5`); last resort is an **Opus 4.8**
  subagent — never the main session, **never Fable**. Sandbox spawn failures are
  not model strikes.
- **Hard rules.** Codex never touches git, never changes dependencies, never edits
  outside the packet's scope. Commits are yours — clean authorship, no AI attribution.
- **Token discipline on the orchestrator side too.** Recon delegated to surveys,
  verification from diffs instead of file re-reads, codex output consumed via a
  bounded `## REPORT` section.

## Install

Requires an orchestrator (Claude Code, etc.) and an authenticated
[Codex CLI](https://github.com/openai/codex) with access to `gpt-5.6-sol`
(`codex exec -m gpt-5.6-sol` must work headlessly; Intel Macs currently need a
fallback model — see
[`skill/reference/codex-invocation.md`](skill/reference/codex-invocation.md)).

```bash
git clone https://github.com/andresleecom/map.git
cd map
./install.sh        # macOS / Linux
```

```powershell
git clone https://github.com/andresleecom/map.git
cd map
.\install.ps1       # Windows (junction, no admin needed)
```

Both link `skill/` into `~/.claude/skills/map`, so `git pull` updates the skill
in place.

On Windows, invoke codex from **Git Bash** (`C:\Program Files\Git\bin\bash.exe`),
not WSL bash.

Under a restricted Claude Code permission mode, the command classifier may deny
`codex exec` dispatches outright (the skill then falls back to Claude subagents —
see SKILL.md's Executor fallback). To keep codex-based execution available, add
`"Bash(codex exec:*)"` to the `permissions.allow` array in
`~/.claude/settings.json` — merge into your existing file (or use
`/permissions`); the entry's shape:

```json
{ "permissions": { "allow": ["Bash(codex exec:*)"] } }
```


## Use

```
/map migrate every date-fns call in packages/web to Temporal
```

Or just describe the task — the orchestrator suggests `/map` when work fits the
delegation profile (spec-locked implementation, refactors, migrations, test writing,
bulk mechanical edits) and asks before running it.

What stays with the orchestrator, always: design and API decisions, naming, anything
needing session tools or secrets, destructive operations, all git, and **all review**.

## Layout

```
skill/
  SKILL.md                      # the skill — flow, rules, contract
  reference/
    codex-invocation.md         # primary executor: Codex CLI
    grok-invocation.md          # secondary executor: Grok CLI from Claude/MAP
    templates.md                # PLAN / task packet / log templates
install.sh · install.ps1
```

## Notes from production use

The invocation encoded here differs from most codex-delegation write-ups for
reasons discovered the hard way:

- `codex exec` needs a **closed stdin** (`- < packet.md`). Open stdin can hang or
  exit with "No prompt provided".
- `--yolo` / `--dangerously-bypass-approvals-and-sandbox` get **blocked** by Claude
  Code's auto-mode classifier. Prefer `-s workspace-write -c approval_policy=never`.
- On some Windows hosts the managed sandbox dies with
  `CreateProcessAsUserW failed: 5` (or transient `1312`). That is **not** a model
  strike — re-dispatch with `-s danger-full-access` (sandbox mode flag, not the
  long bypass). Details in
  [`skill/reference/codex-invocation.md`](skill/reference/codex-invocation.md).
- Always re-run the verify bar yourself. Sol can overstate PROOF.

Inspired by [steipete's codex-first](https://github.com/steipete/agent-scripts/blob/main/skills/codex-first/SKILL.md);
`map` adds the interview-driven plan, the on-branch `.map/` state (resumable across
sessions), per-task verified commits, hard pass gates, and the token-discipline rules.

## License

MIT
