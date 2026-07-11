# Grok Build invocation reference

How to run MAP when the **orchestrator** is [Grok Build](https://x.ai) (this TUI),
not Claude Code. Codex is still the preferred **executor**. Grok only plans,
dispatches, pass-gates, and commits — same split as Claude.

Flags, model pins, sandbox fallback, and REPORT rules for Codex itself live in
`codex-invocation.md`. This file is host-specific: shells, tools, and executor
fallback on Grok.

## Roles on Grok

| Role | Who | Model / tool |
|------|-----|----------------|
| Orchestrator | Main Grok chat | Grok 4.5 (session) — plan, packets, pass gate, git |
| Preferred executor | Codex CLI | `gpt-5.6-sol`, effort `high` (see codex-invocation) |
| Fallback executor | Grok subagent | `spawn_subagent` → `general-purpose` (Grok 4.5 stack) |

**Never** implement packet work in the main Grok thread (token discipline + audit).
**Never** use Fable (Claude-only concern) — N/A on Grok, but still do not dump
impl into the parent chat.

## Dispatching Codex from Grok

### Preferred: Git Bash (Windows)

Same command shape as Claude Code. Use the real Git Bash binary, **not** WSL:

```text
"C:/Program Files/Git/bin/bash.exe"
```

```bash
command codex exec -s workspace-write -c approval_policy=never --skip-git-repo-check \
  -m gpt-5.6-sol -c model_reasoning_effort=high \
  -C "<absolute repo path with forward slashes>" \
  -o ".map/out/NN.md" - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

From Grok's shell tool (PowerShell), wrap Git Bash:

```powershell
$gitBash = "C:\Program Files\Git\bin\bash.exe"
$repo = "C:/Users/Name/IdeaProjects/repo"   # forward slashes inside bash
& $gitBash -lc "cd '$repo' && command codex exec -s workspace-write -c approval_policy=never --skip-git-repo-check -m gpt-5.6-sol -c model_reasoning_effort=high -C '$repo' -o '.map/out/01.md' - < '.map/tasks/01-slug.md' 2>'.map/out/01.stderr.log'; echo EXIT:`$?"
```

Capture stderr to `.map/out/NN.stderr.log` while debugging sandbox death; suppress
in steady state if noise floods the transcript.

### PowerShell-native (no Git Bash)

`codex` on Windows is often a `.cmd` shim — use the full path:

```powershell
$codex = "$env:APPDATA\npm\codex.cmd"
$repo  = "C:\Users\Name\IdeaProjects\repo"
Get-Content "$repo\.map\tasks\01-slug.md" -Raw | & $codex exec `
  -s workspace-write `
  -c approval_policy=never `
  --skip-git-repo-check `
  -m gpt-5.6-sol `
  -c model_reasoning_effort=high `
  -C $repo `
  -o "$repo\.map\out\01.md" `
  - 2> "$repo\.map\out\01.stderr.log"
```

Do **not** `Process.Start("codex")` without resolving `codex.cmd`.

### Background runs

Grok's shell tool may background long commands when they exceed the default
timeout. That is fine for codex (`high` often finishes in a few minutes):

1. Launch the dispatch (allow long timeout or background).
2. Wait with the task output tool until exit.
3. Read only `## REPORT` from `.map/out/NN.md`.
4. Run the orchestrator pass gate yourself.

Parallel tasks: separate `-o` files; prefer sequential on Windows if sandbox
spawn errors multiply under load.

## Sandbox fallback (same as Claude)

If stderr shows `CreateProcessAsUserW failed: 5` or `1312`, or the pass gate fails
after a blocked REPORT:

1. Run pass gate first — file edits may already be good.
2. If gate fails → re-dispatch once with `-s danger-full-access`.
3. Log `sandbox-retry`. Not a model strike.
4. If still dead → executor fallback (below).

Details: `codex-invocation.md` (Windows sandbox fallback + gotchas).

## Grok does not have Claude auto-mode

Claude Code may deny `codex exec` via the auto-mode classifier
(`[Create Unsafe Agents]`). Grok Build does **not** use that classifier.

You still need:

- Codex installed and authenticated (`codex --version`, working `codex exec`)
- Git Bash on Windows for the battle-tested path
- Writable workspace for codex sandbox / `danger-full-access`

If codex is simply missing or auth-broken, go to executor fallback — do not
fake a REPORT.

## Executor fallback on Grok (Grok 4.5 subagent)

When codex cannot run at all this session:

1. Record a decision in `.map/PLAN.md`:
   `Dxx Executor = Grok 4.5 subagent — codex unavailable (<reason>)`.
2. Dispatch with **`spawn_subagent`**:
   - `subagent_type`: `general-purpose`
   - `capability_mode`: `execute` (or host equivalent that allows file writes + shell verify)
   - `cwd`: absolute repo root
   - `prompt`: instruct the subagent to **read** `.map/tasks/NN-<slug>.md` and obey it
     verbatim (HARD RULES, scope, REPORT). Do not paste the whole packet if the
     path is enough — reference the file.
3. When the subagent returns, write its REPORT body to `.map/out/NN.md` (audit trail).
4. Orchestrator runs the **same pass gate** as for codex (REPORT + in-scope diff +
   re-run verify bar).
5. Log `executor-switch (grok-4.5)`.

Strike-1 retry: fresh subagent + `-r2` packet.  
Strike-2 takeover: still a Grok 4.5 subagent + takeover packet — **not** main chat.

### What to put in the subagent prompt (minimal)

```text
You are the MAP executor (not the orchestrator).
Working directory: <absolute repo root>
Read and obey this packet exactly: .map/tasks/NN-<slug>.md
HARD RULES in the packet are binding (no git, no deps, scope only).
When finished, end with the packet's ## REPORT block.
Do not commit. Do not touch files outside Scope.
```

## Pass gate (orchestrator, always)

Unchanged from SKILL.md — Grok must re-run verify commands itself:

1. REPORT `STATUS: done` (or accept blocked only with empty legitimate no-op).
2. Diff only in-scope paths (implementation diffs non-empty when work was required).
3. Orchestrator re-runs build/tests/flow from the MAP.

Codex/subagent PROOF is advisory.

## Git commits from Grok

Same authorship rules as Claude: user's name/email, conventional messages, **no**
AI attribution trailers. One verified task → one commit (+ optional LOG/PLAN
bookkeeping commit).

## Quick checklist (Grok session start)

- [ ] `codex --version` works
- [ ] Repo clean (or stash) before `map/<slug>` branch
- [ ] Git Bash path known on Windows
- [ ] `.map/tasks/` + `.map/out/` exist before dispatch
- [ ] Prompt via file / stdin closed (`- < packet` or PowerShell pipe)
- [ ] After return: pass gate before commit
