# Codex CLI invocation reference

MAP house roles: **Grok 4.5** is the default **coding** executor (speed), then
**Kimi K2.7** (`kimi-code/kimi-for-coding`) as the fast fallback.
**Codex `gpt-5.6-sol`** is the **depth/quality** coding step and
the **orchestrator fallback** when **Fable 5** and **Kimi k3** are unavailable.
Fable (and `k3`) orchestrate only - never implement under a judgment model.
Full chain: `skill/SKILL.md`.

Tested against codex-cli 0.144.x, headless, from Claude Code's Bash tool and
Grok Build (Git Bash on Windows; identical on macOS/Linux, except Intel Macs -
see the platform note).

## The working command (coding fallback / Sol path)

```bash
command codex exec \
  -s workspace-write \
  -c approval_policy=never \
  --skip-git-repo-check \
  -m gpt-5.6-sol \
  -c model_reasoning_effort=high \
  -C "<absolute repo path>" \
  -o ".map/out/NN.md" \
  - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

`command codex` bypasses interactive shell aliases/functions (zsh wrappers, etc.).
If `codex` is not on PATH because of a node version manager:

```bash
fnm exec --using default -- codex exec ...   # or: nvm exec default codex exec ...
```

Run it in background mode when the host supports it. Quiet `high` runs often
finish in a few minutes; only budget ~30 min if you escalated to `xhigh`/`max`.
Don't kill early. Then read only the `## REPORT` tail of the `-o` file.
Do **not** parse the JSONL session stream for results (session logs are only for
finding a `session-id` on resume).

The prompt goes via file, always — never inline: files give an audit trail in
`.map/tasks/`, dodge shell-quoting bugs, and avoid Windows arg-length limits.
`2>/dev/null` suppresses codex's thinking noise (it bloats any context that peeks
at interim output); drop it only when debugging a failing run — the `-o` file
carries the result either way.

## Windows sandbox fallback

On some Windows machines, codex's managed sandbox cannot spawn a shell:

```text
CreateProcessAsUserW failed: 5 (Access is denied.)
CreateProcessAsUserW failed: 1312
```

Symptoms: REPORT blocked or empty work, stderr full of `windows sandbox: runner
failed during SpawnChild`, sometimes a false `STATUS: done` with no real edits.

**This is not a model strike.** Re-dispatch with:

```bash
command codex exec \
  -s danger-full-access \
  -c approval_policy=never \
  --skip-git-repo-check \
  -m gpt-5.6-sol \
  -c model_reasoning_effort=high \
  -C "<absolute repo path>" \
  -o ".map/out/NN.md" \
  - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

Notes:

- `-s danger-full-access` is a **sandbox mode** value. It is **not** the same as
  `--yolo` / `--dangerously-bypass-approvals-and-sandbox` (those long flags stay
  forbidden under Claude Code's auto-mode classifier).
- Prefer `workspace-write` first on every machine. Use `danger-full-access` only
  after sandbox spawn death **and** a failed pass gate, or when this host is
  already known to need it for every run.
- File edits can still succeed when shell spawn fails (Codex may patch files
  without a shell). Always judge success by the orchestrator pass gate, not by
  whether `CreateProcessAsUserW` appeared in stderr.
- Log the retry as `sandbox-retry` in `.map/LOG.md`.
- For recon packets, prefer `read-only` first; if spawn fails, fall back to
  `danger-full-access` with a packet that still forbids edits.

### Windows shell host

Use **Git Bash**, not WSL:

```text
"C:/Program Files/Git/bin/bash.exe"
```

WSL `bash` loads the Linux codex package and fails with missing
`@openai/codex-linux-x64` when the install is the Windows npm binary.

Quote paths with spaces (forward slashes):

```bash
-C "C:/Users/Name With Spaces/IdeaProjects/repo"
```

### PowerShell-native dispatch (optional)

When the orchestrator is PowerShell and Git Bash is awkward:

```powershell
$codex = "$env:APPDATA\npm\codex.cmd"   # or (Get-Command codex).Source
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

Use `-s danger-full-access` if `workspace-write` sandbox-spawns fail.
Do not use `Process.Start("codex")` without the `.cmd` shim on Windows PATH layouts.

## The model: GPT-5.6-Sol, pinned

When MAP uses Codex for coding (or Sol is the orchestrator), pin `gpt-5.6-sol` -
OpenAI's frontier agentic coding model in the 5.6 family (Sol = frontier,
Terra = balanced, Luna = fast/cheap). Prefer **Grok 4.5** first for routine
packet coding; use Sol when Grok cannot run or the PLAN assigns Sol for depth.
Pin with `-m` on every Codex dispatch; never ride the machine's `config.toml`
default, because a MAP must behave the same on every machine that resumes it.

Two traps in this setup:

1. **Sol's catalog default effort is `low`.** A dispatch that pins the model but
   forgets the effort flag falls back to the machine's config — or, absent that,
   to `low` — and nothing warns you. The model flag and the effort flag travel
   together, always.
2. **Effort policy:** house default is **`high`** for implementation (speed) and
   **`medium`** for surveys / trivial mechanical work. Escalate to `xhigh` only
   when a task needs more depth and `high` quality was weak; reserve **`max`**
   for strike-1 reasoning-failure retries (budget more patience). The 5.6 family
   also has `ultra` (`max` + parallel subagents) — **never use `ultra` in
   packets**: concurrent editors fight the packet's tight scoping, burn 2-3×
   tokens, and are account-gated.

Optional: for trivial mechanical tasks only, some operators add
`--enable fast_mode` on top of `high`. Measure quality before relying on it.

Platform note: Sol has an open crash on Intel macOS — SIGTRAP on its first shell
call ([openai/codex#30861](https://github.com/openai/codex/issues/30861)); the
issue reports `gpt-5.5` working on the same machines and Sol fine on Linux
(Windows verified here). On x86_64 Macs pin `gpt-5.5` until it's fixed — and
since 5.5 tops out at `xhigh`, retries there stay at `xhigh`.

Verify the pin took effect (once per environment): the session log under
`~/.codex/sessions/` records `"model":"gpt-5.6-sol"` and the effective effort.

Sol can overstate its own verification results — one more reason the MAP rule
that the orchestrator re-runs the verify bar itself is not optional.
Treat Codex PROOF as advisory.

## Follow-up runs: `resume`

For strike-1 retries, resuming the previous codex session keeps its context (it
already read the codebase) and is cheaper than a fresh run:

```bash
(cd "<repo>" && command codex exec resume <session-id> \
  -m gpt-5.6-sol -c model_reasoning_effort=max \
  -c 'sandbox_mode="workspace-write"' -c approval_policy=never \
  -o ".map/out/NN-r2.md" - < ".map/tasks/NN-<slug>-r2.md" 2>/dev/null)
```

If the original run needed the Windows sandbox fallback, resume with:

```bash
-c 'sandbox_mode="danger-full-access"'
```

Caveats, verified on 0.144 with real resumed runs:

- `resume` rejects the `-s` and `-C` flags outright (`error: unexpected
  argument`, exit 2) — pass the sandbox as `-c 'sandbox_mode="…"'`
  and cd into the repo. It does accept `-m`. Write-ups that use resume typically
  reach for `--dangerously-bypass-approvals-and-sandbox` instead; that stays
  blocked (see Gotchas) and the form above is the working equivalent.
- A resumed session does **not** inherit the original run's model — codex
  restores only the cwd and resolves the model from the machine's config
  default. Re-pin model and effort on every resume. (`max` shown above fits a
  reasoning-failure retry; keep the original tier for a spec-gap retry.)
- Prefer an explicit session id over `--last` — any concurrent codex activity
  (a parallel MAP dispatch, the user's own codex session) can steal the
  newest-session slot. To find the id, grep the day's rollouts for a distinctive
  phrase from the packet body — `grep -l "<phrase>"
  ~/.codex/sessions/<yyyy>/<mm>/<dd>/*.jsonl` — the id is the UUID in the
  matching filename. (The filename has no task slug; only contents match.)

## Flags explained

| Flag | Why |
|---|---|
| `command codex` | Bypass shell aliases/wrappers. |
| `exec` | Non-interactive, single-shot execution mode. |
| `-s workspace-write` | Default sandbox: write inside the workspace, nothing outside. |
| `-s danger-full-access` | Windows fallback when managed sandbox cannot spawn shells. |
| `-c approval_policy=never` | Never pause to ask for approval (would hang headless). |
| `--skip-git-repo-check` | Don't refuse to run in odd repo states (worktrees, subdirs). |
| `-m gpt-5.6-sol` | Pin the delegate model; config defaults vary per machine. Works on `resume` too. |
| `-C <path>` | Working directory — always pass the repo root explicitly. |
| `-o <file>` | Write the final message to a file; keeps orchestrator context clean. |
| `-` + `< packet.md` | Read the prompt from stdin (file), which also closes stdin. |
| `-c model_reasoning_effort=<level>` | Never omit — unpinned it falls back to machine config or Sol's `low` default. |
| `2>/dev/null` | Suppress thinking-noise on stderr; remove only to debug. |

## Gotchas (each one cost a debugging session — respect them)

1. **Open / empty stdin.** Always use `- < packet.md`. On a TTY with open stdin,
   `codex exec` can hang waiting for input. On some non-TTY hosts it exits quickly
   with `No prompt provided via stdin` — still a failed dispatch. File redirect is
   mandatory either way.
2. **`--yolo` / `--dangerously-bypass-approvals-and-sandbox` get blocked** by
   Claude Code's auto-mode command classifier (they bypass codex's sandbox, which
   the harness treats as unauthorized). Prefer `-s workspace-write
   -c approval_policy=never`. Use `-s danger-full-access` only as the documented
   Windows fallback — not as a casual default. Stricter permission modes can deny
   even this sanctioned form — do not retry it with adjusted flags; one denial of
   the plain dispatch → switch executors (SKILL.md, Executor fallback, which also
   covers the settings remedy). The allowlist rule must be
   `Bash(command codex exec:*)` - dispatches start with `command `, so the bare
   `Bash(codex exec:*)` form never matches one. Even with the rule in place, the
   parenthesized resume form may still prompt; if only resume is denied,
   fall back to a fresh plain dispatch — not to another executor.
3. **Non-fatal MCP auth noise.** A misconfigured MCP server in codex's own config
   (e.g. github-copilot) may print an auth error at startup. It does not affect the
   run — ignore it; don't burn a strike on it.
4. **Build staleness across branches.** After switching branches or creating a
   worktree, compiled artifacts (`dist/`, build caches) are stale. Rebuild affected
   packages before typechecking, or verification fails on ghosts codex didn't cause.
5. **Windows paths.** From Git Bash, prefer forward slashes and quote every path —
   `"C:/Users/Name With Spaces/..."`. Never use WSL bash for the Windows codex binary.
6. **Windows sandbox spawn death: `CreateProcessAsUserW failed: 5` or `1312`.**
   Error **1312** is often transient (logon session). Error **5** (Access is denied)
   can be persistent on a given machine. Neither is a model failure or a strike.
   Run the orchestrator pass gate first — file edits can still succeed when shell
   spawn fails. If the pass gate fails, re-dispatch once with
   `-s danger-full-access`. If concurrent codex instances make it worse, stop them
   and retry solo. If every spawn still fails after the fallback (or the host
   cannot run codex at all), stop re-dispatching and switch executors
   (SKILL.md, Executor fallback).

7. **Sandbox network is asymmetric.** localhost TCP (a local Postgres, a dev
   server) tends to work inside `workspace-write`; external HTTPS (Gradle plugin
   portals, package registries) gets blocked or TLS-broken (`PKIX path building
   failed`). Consequence: JS/TS builds against local caches usually self-verify,
   JVM/Gradle builds usually cannot — expect UNRUN proofs and verify those
   outside the sandbox.
8. **False green REPORTs.** Sol may claim tests passed or "already implemented"
   when the sandbox blocked shells or when another process already fixed the file.
   The orchestrator always re-runs the verify bar and checks the diff.

## Recon packets (read-only surveys)

Codex is also the cheap way to survey a large codebase. Same invocation with the
effort dropped to `-c model_reasoning_effort=medium` (and `-s read-only` fits a
survey better than workspace-write when the sandbox works), and a packet that
asks only for analysis and forbids edits:

```
Survey <area>. Do not modify any file.
Answer: <the specific questions>.
## REPORT — findings with file:line references, ≤60 lines.
```

If `read-only` cannot spawn a shell on Windows, re-dispatch with
`-s danger-full-access` and the same "do not modify" packet.

The orchestrator reads the report; the exploration tokens were codex's.
