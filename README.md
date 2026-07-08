# map — Massive Action Plan

**Claude plans. Codex executes. Claude verifies. Nothing merges unreviewed.**

`map` is a [Claude Code skill](https://code.claude.com/docs/en/skills) that splits
coding work by comparative advantage: the expensive frontier model in your session
handles judgment — recon, interviewing you, freezing decisions, writing specs,
reviewing diffs — while [Codex CLI](https://github.com/openai/codex) burns the cheap
tokens actually typing the code.

```
you ──/map──▶ Claude                                  codex
               │  triage (S/M/L)                        │
               │  recon + interview + decisions         │
               │  .map/PLAN.md on branch map/<slug>     │
               │                                        │
               │── task packet 01 ─────────────────────▶│ edits (sandboxed,
               │◀───────────────────────── REPORT ──────│  no git, no deps)
               │  review diff · run verify bar          │
               │  commit (your authorship)              │
               │── task packet 02 ─────────────────────▶│ …
               │            two strikes → Claude takes over
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
- **Checkpointed execution.** Codex gets one verifiable task packet at a time. Claude
  reviews the diff as a hostile code reviewer, runs the task's verify bar
  (build → tests → drive-the-flow, declared per task), and commits per verified task.
  A bad task is one revert, not a poisoned branch.
- **Two strikes.** One sharpened retry that names the exact defect; then Claude
  implements it itself and logs why. The log teaches you what not to delegate.
- **Hard rules.** Codex never touches git, never changes dependencies, never edits
  outside the packet's scope. Commits are yours — clean authorship, no AI attribution.
- **Token discipline on the Claude side too.** Recon delegated to read-only codex
  surveys, verification from diffs instead of file re-reads, codex output consumed
  via a bounded `## REPORT` section.

## Install

Requires Claude Code and an authenticated [Codex CLI](https://github.com/openai/codex)
(`codex exec` must work headlessly).

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

## Use

```
/map migrate every date-fns call in packages/web to Temporal
```

Or just describe the task — Claude suggests `/map` when work fits the delegation
profile (spec-locked implementation, refactors, migrations, test writing, bulk
mechanical edits) and asks before running it.

What stays with Claude, always: design and API decisions, naming, anything needing
session tools or secrets, destructive operations, all git, and **all review**.

## Layout

```
skill/
  SKILL.md                      # the skill — flow, rules, contract
  reference/
    codex-invocation.md         # battle-tested flags + the gotchas that cost hours
    templates.md                # PLAN / task packet / log templates
install.sh · install.ps1
```

## Notes from production use

The invocation encoded here differs from most codex-delegation write-ups for
reasons discovered the hard way: `codex exec` **hangs forever on open stdin**
(prompts are passed via `- < packet.md`), and `--yolo`-style sandbox bypasses get
**blocked by Claude Code's auto-mode classifier** — `-s workspace-write
-c approval_policy=never` is the working equivalent that keeps codex's own sandbox
on. See [`skill/reference/codex-invocation.md`](skill/reference/codex-invocation.md).

Inspired by [steipete's codex-first](https://github.com/steipete/agent-scripts/blob/main/skills/codex-first/SKILL.md);
`map` adds the interview-driven plan, the on-branch `.map/` state (resumable across
sessions), per-task verified commits, and the token-discipline rules.

## License

MIT
