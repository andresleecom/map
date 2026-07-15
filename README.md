# map - Massive Action Plan

**Orchestrator plans. Grok types. Orchestrator verifies. Nothing merges unreviewed.**

`map` is a skill for multi-tool agent work across [Claude Code](https://code.claude.com/docs/en/skills),
[Grok Build](https://grok.x.ai/), and [Codex CLI](https://github.com/openai/codex).
It splits coding by comparative advantage:

| Role | Preferred | Fallback |
|------|-----------|----------|
| **Orchestrator** (plan, interview, pass gate, git, review) | **Fable 5** (Claude Code) | **Codex 5.6 Sol** if Fable 5 is unavailable |
| **Coding executor** (type the packet) | **Grok 4.5** CLI (fastest) | **Codex 5.6 Sol** → **Opus 4.8** subagent |

Fable may **orchestrate** only. It must **never** implement MAP packets.

```
you --/map--> orchestrator (Fable 5 / Sol)              grok-4.5 (default coder)
                 |  triage (S/M/L)                         |
                 |  recon + interview + decisions          |
                 |  .map/PLAN.md on branch map/<slug>      |
                 |                                         |
                 |-- task packet 01 ---------------------->| edits (no git, no deps)
                 |<-------------------------- REPORT ------|
                 |  hostile verify: diff + re-run bar      |
                 |  commit (your authorship)               |
                 |-- task packet 02 ---------------------->| ...
                 |     sandbox death -> fallback, not strike
                 |            two strikes -> next executor
                 v
            final review · .map/ removed · handoff report
```

Coding fallback when Grok cannot run: **Codex Sol**, then **Opus 4.8** - never the
Fable main session.

## Why

Judgment tokens (orchestrator) and coding tokens (executor) should not share one
context. Most of a coding task's tokens go to *generation and bulk reading* - work
Grok 4.5 does quickly when the spec is frozen. `map` makes the split systematic:

- **A real plan, not a prompt.** Ambiguity is resolved *with you* (batched interview
  rounds) before anything executes. Decisions get numbered and frozen into
  `.map/PLAN.md`, committed on the work branch - the plan travels with the code and
  any future session resumes from it.
- **Checkpointed execution.** The coding executor gets one verifiable task packet
  at a time. The orchestrator reviews the diff as a hostile code reviewer, re-runs
  the task's verify bar (build -> tests -> drive-the-flow), and commits per verified
  task. Executor PROOF is advisory only.
- **Two strikes / executor chain.** Prefer **Grok 4.5**; if Grok can't run, dispatch
  **Codex Sol**; last resort **Opus 4.8** - never Fable for implementation.
  Infrastructure failures are not model strikes.
- **Hard rules.** Executors never touch git, never change dependencies, never edit
  outside the packet's scope. Commits are yours - clean authorship, no AI attribution.
- **Token discipline on the orchestrator side too.** Recon delegated to surveys,
  verification from diffs instead of file re-reads, executor output consumed via a
  bounded `## REPORT` section.

## When not to use MAP

Keep the work in the main session (or skip MAP) when:

- The task is mostly design, naming, or API shape - the spec *is* the work
- The edit is tiny (packet overhead exceeds the task)
- You need session-only tools, secrets, or authenticated MCP services for the edits
- You want bulk generation *in* the orchestrator context (MAP exists to avoid that)

## Install

Requires:

1. An orchestrator that can load skills (Claude Code and/or Grok Build). Prefer a
   **Fable 5** Claude Code session; if Fable 5 is unavailable, orchestrate with
   **Codex 5.6 Sol**.
2. Primary coder: authenticated [Grok CLI](https://grok.x.ai/) with `grok-4.5`
   (`grok -m grok-4.5` headless - see
   [`skill/reference/grok-invocation.md`](skill/reference/grok-invocation.md))
3. Fallback coder (and Sol-as-orchestrator): authenticated
   [Codex CLI](https://github.com/openai/codex) with `gpt-5.6-sol`
   (`codex exec -m gpt-5.6-sol` headlessly; Intel Macs currently need a fallback
   model - see
   [`skill/reference/codex-invocation.md`](skill/reference/codex-invocation.md))

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

By default both scripts link `skill/` into:

- `~/.claude/skills/map` (Claude Code)
- `~/.grok/skills/map` (Grok Build)

so `git pull` updates the skill in place. Install only one host:

```bash
MAP_INSTALL_TARGETS=claude ./install.sh
MAP_INSTALL_TARGETS=grok ./install.sh
```

```powershell
$env:MAP_INSTALL_TARGETS = "claude"; .\install.ps1
$env:MAP_INSTALL_TARGETS = "grok";   .\install.ps1
```

On Windows, invoke codex from **Git Bash** (`C:\Program Files\Git\bin\bash.exe`),
not WSL bash.

### Permission allowlists (Claude Code)

Under a restricted Claude Code permission mode, the command classifier may deny
executor dispatches. MAP then falls through the executor chain (see SKILL.md).
To keep CLI executors available, merge into `permissions.allow` in
`~/.claude/settings.json` (or use `/permissions`):

```json
{
  "permissions": {
    "allow": [
      "Bash(grok:*)",
      "Bash(grok.exe:*)",
      "Bash(codex exec:*)"
    ]
  }
}
```

`grok` is the primary coding path; `codex exec` matters when Grok is unavailable
or the PLAN assigns Sol.

## Use

```
/map migrate every date-fns call in packages/web to Temporal
```

Or just describe the task - the orchestrator suggests `/map` when work fits the
delegation profile (spec-locked implementation, refactors, migrations, test writing,
bulk mechanical edits) and asks before running it.

What stays with the orchestrator, always: design and API decisions, naming, anything
needing session tools or secrets, destructive operations, all git, and **all review**.

## Layout

```
skill/
  SKILL.md                      # the skill - flow, roles, contract
  reference/
    grok-invocation.md          # primary coding executor: Grok 4.5 CLI
    codex-invocation.md         # coding fallback + Sol-as-orchestrator
    templates.md                # PLAN / task packet / log templates
install.sh · install.ps1
```

## Notes from production use

The invocation encoded here differs from most codex-delegation write-ups for
reasons discovered the hard way:

- Prefer **Grok 4.5** for coding speed; keep **Codex Sol** for depth and for
  orchestration when Fable 5 is missing.
- `codex exec` needs a **closed stdin** (`- < packet.md`). Open stdin can hang or
  exit with "No prompt provided".
- `--yolo` / `--dangerously-bypass-approvals-and-sandbox` get **blocked** by Claude
  Code's auto-mode classifier on Codex. Prefer `-s workspace-write -c approval_policy=never`.
- On some Windows hosts the managed sandbox dies with
  `CreateProcessAsUserW failed: 5` (or transient `1312`). That is **not** a model
  strike - re-dispatch with `-s danger-full-access` (sandbox mode flag, not the
  long bypass). Details in
  [`skill/reference/codex-invocation.md`](skill/reference/codex-invocation.md).
- Always re-run the verify bar yourself. Executors can overstate PROOF.
- On Grok CLI, use `--no-subagents` (not `--disallowed-tools Agent`) -
  see [`skill/reference/grok-invocation.md`](skill/reference/grok-invocation.md).

### Verified against (house pins)

| Piece | Pin / version | Role |
|-------|---------------|------|
| Orchestrator | Fable 5 (Claude Code) | Preferred judgment session |
| Orchestrator fallback | `gpt-5.6-sol` | When Fable 5 unavailable |
| Coding primary | `grok-4.5` (Grok CLI 0.2.93+) | Fastest coding |
| Coding secondary | `gpt-5.6-sol` (Codex CLI 0.144.x) | Depth / Grok down |
| Coding last resort | `claude-opus-4-8` | Subagent only; never Fable |
| Platforms | Windows (Git Bash), macOS, Linux | Intel Macs: Sol SIGTRAP - pin `gpt-5.5` for Codex |

Pins and flags change; treat the table as a snapshot and re-check the reference
docs when a dispatch fails after a CLI upgrade.

Inspired by [steipete's codex-first](https://github.com/steipete/agent-scripts/blob/main/skills/codex-first/SKILL.md);
`map` adds the interview-driven plan, the on-branch `.map/` state (resumable across
sessions), per-task verified commits, hard pass gates, multi-host install, and
house roles across Claude / Grok / Codex.

## License

MIT
