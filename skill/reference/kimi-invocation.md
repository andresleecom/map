# Kimi CLI invocation reference (MAP coding executor + Kimi-as-orchestrator)

MAP house roles with Kimi in the mix:

| Seat | Kimi piece | Role |
|------|-----------|------|
| Orchestrator | **Kimi Code session on `kimi-code/k3`** (judgment) | Daily-driver orchestrator host alongside Fable 5. Plans, interviews, pass-gates, commits. **Never types packets.** |
| Coding executor | **Kimi CLI `-p` on `kimi-code/kimi-for-coding`** (K2.7 Coding) | Fast coding fallback after Grok 4.5, before Codex Sol. |

Full chain and binding rules: `skill/SKILL.md`.

## When to use Kimi vs Grok vs Codex (coding)

| Priority | Executor | Use when |
|----------|----------|----------|
| 1 | **Grok CLI** `grok-4.5` | **Default.** Fastest house model for coding. |
| 2 | **Kimi CLI** `kimi-code/kimi-for-coding` | Grok unavailable (not installed/auth, permission deny, infra failure after retry). Fast, cheap, agentic coding. |
| 3 | **Codex** `gpt-5.6-sol` | Depth / quality takeovers, or the MAP decision register assigns Sol. |
| 4 | **Opus 4.8 subagent** | Only if all CLI executors fail. Never Fable. Never main-session impl under Fable. |

Do not run two executors on the **same** task in parallel (conflict risk).
Parallel tasks still require file-disjoint scopes and separate out files.

## Prerequisites

- `kimi` on PATH (Windows: `%USERPROFILE%\.kimi-code\bin\kimi.exe`)
- Authenticated: `kimi login` (managed service) or a configured provider
- Verify once: `kimi --version` and a tiny `kimi -p "ping"` from the repo root

## The working command (headless)

Kimi has **no `--prompt-file` and no `--cwd`** - so don't paste the packet, point at
it (MAP packets reference paths; the executor reads them locally for free), and run
from a subshell cd'd to the repo:

```bash
(cd "<absolute repo path>" && command kimi \
  -m kimi-code/kimi-for-coding \
  -p "You are the MAP executor (Kimi CLI). Read the packet at .map/tasks/NN-<slug>.md
      and implement it exactly. Obey its HARD RULES: no git commands, no dependency
      changes, edit only within the listed scope. End your output with the ## REPORT
      section exactly as the packet specifies." \
  > ".map/out/NN.md" 2> ".map/out/NN.stderr.log")
```

### Why this shape

| Piece | Why |
|-------|-----|
| `-p "<prompt>"` | One-shot non-interactive mode. Prints the final assistant text to stdout and exits. |
| prompt references the packet path | No `--prompt-file` flag exists; the packet stays on disk as the audit trail and dodges Windows arg-length limits. |
| `(cd "<repo>" && ...)` | No `--cwd` flag; Kimi resolves the workspace from the process cwd. Subshell keeps the orchestrator's own cwd untouched. |
| `-m kimi-code/kimi-for-coding` | House pin for Kimi coding (K2.7 Coding). **Do not omit** - the machine default may be `k3` (the judgment seat), and a MAP must behave the same on every machine that resumes it. |
| no permission flags | `-p` mode runs under auto permission by default and **rejects** `--yolo` / `--auto` / `--plan` as conflicts. There is no CLI `--deny` flag; the git/dependency ban is enforced by the packet HARD RULES plus the orchestrator pass gate (static deny rules in `config.toml` also stay in effect). |
| stdout → `.map/out/NN.md` | Audit trail + REPORT capture. Thinking and tool progress go to stderr → `.map/out/NN.stderr.log`. |

Speed variant: `-m kimi-code/kimi-for-coding-highspeed` (K2.7 Coding Highspeed) is
the faster pin for trivial mechanical packets. Measure quality before relying on it.

`--output-format stream-json` exists for programmatic parsing; MAP reads the
`## REPORT` tail of the plain text output, so keep the default `text`. Do **not**
parse the JSONL stream for results.

## Packet contract (same for every executor)

Every packet still includes the HARD RULES block from SKILL.md (no git, no deps,
scope only, REPORT shape). Kimi does not get a looser contract - note that Kimi's
`-p` auto-approves regular tool calls, so the packet scope + the orchestrator pass
gate are the real safety net.

Optional one-liner at the top of the packet when dispatching to Kimi:

```markdown
You are the MAP executor (Kimi CLI). Obey HARD RULES. No git. End with ## REPORT.
```

## Pass gate (orchestrator, always)

Identical for every coding executor:

1. REPORT present; `STATUS: done` when work was required.
2. Diff only in-scope; non-empty for real implementation tasks.
3. Orchestrator re-runs the verify bar.

Kimi's own claims in PROOF are advisory.

## Resume / follow-up

For strike-1 on a **Kimi** dispatch, prefer a **fresh** headless run with the
sharpened `.map/tasks/NN-<slug>-r2.md` packet (clearer than session resume for MAP
audit; headless `-p` resume against a saved session is not a documented path).

## Logging

- Grok primary path: normal task line (no switch label required).
- Kimi path: `executor-switch (kimi-k2.7)` when K2.7 ran because Grok could not,
  or when the PLAN decision register chose Kimi for that task.
- Codex path: `executor-switch (codex-sol)`. Opus path: `executor-switch (opus-4.8)` / `takeover (opus-4.8)`.
- Kimi-orchestrator impl (exception below): `executor = kimi-code (orchestrator impl)`.
- Never log a Fable executor.

## Kimi as orchestrator

A **Kimi Code session** (house default model `kimi-code/k3`) is a first-class MAP
orchestrator host: it has the full tool surface (skills, interview questions, Bash
for `grok` / `codex exec` / `kimi -p` dispatches, plan mode, subagents, git).

Binding, same as Fable: when Kimi orchestrates it **never types product code** for a
MAP task - packets go to a headless coding CLI.

**Exception (mirrors Sol):** only if the session is pinned to a **coding-class**
model (`kimi-code/kimi-for-coding`) **and** no CLI executor can run at all, the
Kimi orchestrator may implement the packet in-session, logging
`executor = kimi-code (orchestrator impl)`. Never do this on the `k3` judgment pin.

## Gotchas

1. **`-p` conflicts with `--yolo` / `--auto` / `--plan`.** Don't pass them; auto
   permission is already the non-interactive behavior.
2. **No `--prompt-file`, no `--cwd`.** Reference the packet path in the prompt;
   subshell-cd into the repo. Pasting whole packets into `-p` hits Windows
   arg-length limits and loses the audit trail.
3. **Model pin travels on every dispatch.** Omitting `-m` rides the machine's
   `default_model` (often `k3`) - wrong seat, wrong price, and different behavior
   per machine.
4. **stdout/stderr split.** Assistant text (the REPORT) goes to stdout; thinking
   and tool progress to stderr. Redirect both; read only the REPORT tail.
5. **Quiet runs are normal.** A few minutes of silence on a real packet is fine;
   do not kill early. Check `.map/out/NN.stderr.log` if you need signs of life.
6. **Windows:** run from Git Bash, quote paths with spaces, forward slashes
   (`"C:/Users/Name With Spaces/IdeaProjects/repo"`). The Windows-native
   `kimi.exe` works from Git Bash; do not mix WSL paths with the Windows binary.
7. **Classifier denials.** Suggest the user allowlist `Bash(command kimi:*)` and
   `Bash(command kimi.exe:*)` in `permissions.allow` (plus bare `Bash(kimi *)`
   for the smoke checks below). Dispatches start with `command `, so bare rules
   alone never match them. The `(cd ... && command kimi ...)` wrapper is a
   compound command - the checker evaluates the `cd` and the `command kimi`
   parts separately, so the rule still applies.

## Minimal smoke (orchestrator session)

```bash
command kimi --version
(cd "<repo>" && command kimi -m kimi-code/kimi-for-coding \
  -p "Read .map/tasks/01-smoke.md and implement it. Obey HARD RULES. End with ## REPORT." \
  > ".map/out/01.md" 2> ".map/out/01.stderr.log")
# then: pass gate + commit as MAP
```
