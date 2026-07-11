# Grok CLI invocation reference (from Claude Code / MAP)

Claude (or any MAP orchestrator) can dispatch **Grok Build CLI** as an
**executor** the same way it dispatches Codex: packet on disk → headless agent →
REPORT → orchestrator pass gate → commit.

This is **not** “run the MAP session inside Grok.” It is **Claude plans, Grok
types** (or Codex types — prefer Codex when available).

Codex flags remain in `codex-invocation.md`. This file is only the Grok CLI glue.

## When to use Grok vs Codex

| Priority | Executor | Use when |
|----------|----------|----------|
| 1 | **Codex** `gpt-5.6-sol` | Default. Cheapest bulk implementation. |
| 2 | **Grok CLI** `grok-4.5` | Codex unavailable (permission deny, sandbox dead after fallback, not installed/auth), or the MAP decision register explicitly picks Grok for a task. |
| 3 | **Opus 4.8 subagent** | Only if both CLI executors fail. Never Fable. Never main-session impl. |

Do not run Codex and Grok on the **same** task in parallel (conflict risk).
Parallel tasks still require file-disjoint scopes and separate `-o` / out files.

## Prerequisites

- `grok` on PATH (common: `~/.grok/bin/grok` or `%USERPROFILE%\.grok\bin\grok.exe`)
- Authenticated: `grok login` or `XAI_API_KEY`
- Verify once: `grok --version` and a tiny `grok -p "ping" --cwd <repo> --yolo`

## The working command (headless)

Prompt **always from the MAP packet file** (audit trail + no arg-length pain):

```bash
command grok \
  --prompt-file ".map/tasks/NN-<slug>.md" \
  --cwd "<absolute repo path>" \
  -m grok-4.5 \
  --reasoning-effort high \
  --yolo \
  --no-subagents \
  --deny "Bash(git*)" \
  --deny "Bash(*git *)" \
  --output-format plain \
  > ".map/out/NN.md" 2> ".map/out/NN.stderr.log"
```

Windows (PowerShell), same idea:

```powershell
$grok = "$env:USERPROFILE\.grok\bin\grok.exe"
$repo = "C:\Users\Name\IdeaProjects\repo"
& $grok `
  --prompt-file "$repo\.map\tasks\01-slug.md" `
  --cwd $repo `
  -m grok-4.5 `
  --reasoning-effort high `
  --yolo `
  --no-subagents `
  --deny "Bash(git*)" `
  --output-format plain `
  > "$repo\.map\out\01.md" `
  2> "$repo\.map\out\01.stderr.log"
```

### Why these flags

| Flag | Why |
|------|-----|
| `--prompt-file` | Packet body; same contract as Codex stdin file. Prefer over huge `-p "..."`. |
| `--cwd` | Repo root. Always absolute. |
| `-m grok-4.5` | House pin for MAP fallback (frontier). Do not omit (avoids weaker defaults). `grok-build` is the product default agent profile name in some docs — for MAP pin **`grok-4.5`**. |
| `--reasoning-effort high` | Aligns with Codex house effort default (speed). Escalate only if quality fails. |
| `--yolo` / `--always-approve` | Required for unattended headless (auto-approve tools). **Scoped by packet HARD RULES + denylists below.** |
| `--no-subagents` | Blocks Grok from spawning its own subagent fan-out (MAP owns parallelism). **Use this, not `--disallowed-tools "Agent"`** (see gotcha). |
| `--deny "Bash(git*)"` | Reinforces HARD RULES: no git from the executor. |
| stdout → `.map/out/NN.md` | Audit trail + REPORT capture (Grok prints the final message to stdout). |

### Claude Code auto-mode note

Claude Code may classify `--yolo` / `--always-approve` as dangerous (same family as
Codex `--yolo`). If the plain sanctioned dispatch is denied:

1. Do **not** keep tweaking bypass flags.
2. Fall through to **Opus 4.8** subagent executor (see SKILL.md), or ask the user
   to allowlist `Bash(grok:*)` / `Bash(grok.exe:*)` in `permissions.allow`.
3. Suggested allowlist entry (user-level, merge into existing file):

```json
{ "permissions": { "allow": ["Bash(grok:*)", "Bash(grok.exe:*)"] } }
```

## Packet contract (same as Codex)

Every packet still includes the HARD RULES block from SKILL.md (no git, no deps,
scope only, REPORT shape). Grok does not get a looser contract.

Optional one-liner at the top of the packet when dispatching to Grok:

```markdown
You are the MAP executor (Grok CLI). Obey HARD RULES. No git. End with ## REPORT.
```

## Pass gate (orchestrator, always Claude / host)

Identical to Codex:

1. REPORT present; `STATUS: done` when work was required.
2. Diff only in-scope; non-empty for real implementation tasks.
3. Orchestrator re-runs the verify bar.

Grok’s own claims in PROOF are advisory.

## Resume / follow-up

For strike-1 on a **Grok** dispatch, prefer a **fresh** headless run with the
sharpened `.map/tasks/NN-<slug>-r2.md` packet (clearer than session resume for
MAP audit). If you must resume:

```bash
# capture sessionId from a prior --output-format json run if needed
command grok --prompt-file ".map/tasks/NN-slug-r2.md" --cwd "<repo>" \
  -m grok-4.5 --reasoning-effort high --yolo --no-subagents \
  --deny "Bash(git*)" \
  -r "<session-id>" > ".map/out/NN-r2.md" 2> ".map/out/NN-r2.stderr.log"
```

## Logging

- Codex path: normal task line; `sandbox-retry` if Windows sandbox fallback ran.
- Grok path: `executor-switch (grok-4.5)` when Grok was used because Codex could
  not, **or** when the PLAN decision register chose Grok for that task.
- Never log a Fable executor.

## Decision register examples

```markdown
- D10 Executor primary = codex gpt-5.6-sol
- D11 Executor fallback = grok CLI grok-4.5 (then Opus 4.8 subagent)
```

Or per-task override:

```markdown
- D12 Task 03 executor = grok-4.5 (explicit)
```

## Gotchas

1. **Headless does not read piped stdin as the prompt.** Use `--prompt-file`, not
   only shell redirects into grok without the flag.
2. **`--yolo` is full tool autonomy** within what tools remain after denylist.
   Packet scope + pass gate are the real safety net.
3. **Do not let Grok commit.** HARD RULES + `--deny Bash(git*)`; orchestrator owns git.
4. **WSL vs Windows:** call the Windows `grok.exe` from Git Bash with a Windows
   path, or use PowerShell. Mixing WSL paths with a Windows binary fails.
5. **Model pin:** use `-m grok-4.5` explicitly for MAP so a machine default of
   composer/fast models does not steal the run.
6. **`--disallowed-tools "Agent"` breaks agent building (Grok 0.2.93, verified).**
   Error looks like:
   `agent building failed: ... auto_background_on_timeout requires enabled_background to be true`.
   That is **not** a model strike and **not** a packet defect. Re-dispatch with
   **`--no-subagents`** instead (same intent: no executor fan-out). Do not thrash
   other flags first.
7. **Nested multi-agent:** `--no-subagents` keeps MAP owning parallelism. Packet
   HARD RULES still win even if skills load inside Grok.

## Minimal smoke (Claude session)

```bash
command grok --version
command grok --prompt-file ".map/tasks/01-smoke.md" --cwd "$PWD" \
  -m grok-4.5 --reasoning-effort high --yolo --no-subagents \
  --deny "Bash(git*)" \
  > ".map/out/01.md" 2> ".map/out/01.stderr.log"
# then: pass gate + commit as MAP
```
