# Codex CLI invocation reference

Tested against codex-cli 0.142.x, headless, from Claude Code's Bash tool (Git Bash
on Windows; identical on macOS/Linux).

## The working command

```bash
codex exec \
  -s workspace-write \
  -c approval_policy=never \
  --skip-git-repo-check \
  -c model_reasoning_effort=xhigh \
  -C "<absolute repo path>" \
  -o ".map/out/NN.md" \
  - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

Run it with the Bash tool in background mode (`run_in_background: true`) — codex
runs take minutes (quiet xhigh runs up to ~30 min are normal; don't kill early)
and Claude gets notified on exit. Then read only the `## REPORT` tail of the
output file.

The prompt goes via file, always — never inline: files give an audit trail in
`.map/tasks/`, dodge shell-quoting bugs, and avoid Windows arg-length limits.
`2>/dev/null` suppresses codex's thinking noise (it bloats any context that peeks
at interim output); drop it only when debugging a failing run — the `-o` file
carries the result either way.

## Follow-up runs: `resume`

For strike-1 retries, resuming the previous codex session keeps its context (it
already read the codebase) and is cheaper than a fresh run:

```bash
(cd "<repo>" && codex exec resume --last \
  -s workspace-write -c approval_policy=never \
  -o ".map/out/NN-r2.md" - < ".map/tasks/NN-<slug>.md" 2>/dev/null)
```

Caveats: `resume` does not accept `-C` — you must cd into the repo. Verify ONCE
in your environment that resume accepts the sandbox flags (`codex exec resume
--help`); write-ups that use resume typically pass
`--dangerously-bypass-approvals-and-sandbox` instead, which restricted auto-mode
classifiers block. If sandbox flags don't work with resume, use a fresh dispatch —
correctness beats the token saving. Also: `--last` grabs the most recent session;
never use it while another codex run is in flight.

## Flags explained

| Flag | Why |
|---|---|
| `exec` | Non-interactive, single-shot execution mode. |
| `-s workspace-write` | Sandbox: codex may write inside the workspace, nothing outside. |
| `-c approval_policy=never` | Never pause to ask for approval (would hang headless). |
| `--skip-git-repo-check` | Don't refuse to run in odd repo states (worktrees, subdirs). |
| `-C <path>` | Working directory — always pass the repo root explicitly. |
| `-o <file>` | Write the final message to a file; keeps Claude's context clean. |
| `-` + `< packet.md` | Read the prompt from stdin (file), which also closes stdin. |
| `-c model_reasoning_effort=<level>` | House default `xhigh` for implementation; `medium` for trivial mechanical tasks and read-only surveys. |
| `2>/dev/null` | Suppress thinking-noise on stderr; remove only to debug. |

## Gotchas (each one cost a debugging session — respect them)

1. **Open stdin hangs forever.** `codex exec` reads "additional input" from stdin.
   Without `- < file` or `< /dev/null` it waits silently — the symptom is a run
   that produces nothing and never exits.
2. **`--yolo` / `--dangerously-bypass-approvals-and-sandbox` get blocked** by
   Claude Code's auto-mode command classifier (they bypass codex's sandbox, which
   the harness treats as unauthorized). `-s workspace-write -c approval_policy=never`
   is the working equivalent and keeps codex's own sandbox on.
3. **Non-fatal MCP auth noise.** A misconfigured MCP server in codex's own config
   (e.g. github-copilot) may print an auth error at startup. It does not affect the
   run — ignore it; don't burn a strike on it.
4. **Build staleness across branches.** After switching branches or creating a
   worktree, compiled artifacts (`dist/`, build caches) are stale. Rebuild affected
   packages before typechecking, or verification fails on ghosts codex didn't cause.
5. **Windows paths.** From Git Bash, prefer forward slashes and quote every path —
   `"C:/Users/Name With Spaces/..."`.
6. **Transient Windows sandbox death: `CreateProcessAsUserW failed: 1312`.**
   Occasionally codex's sandbox cannot create its logon session; the run exits
   "cleanly" having done zero work (an honest REPORT will say so). Not a model
   failure and not a strike — just re-dispatch. If it repeats, stop running
   codex instances concurrently and retry solo.
7. **Sandbox network is asymmetric.** localhost TCP (a local Postgres, a dev
   server) tends to work inside `workspace-write`; external HTTPS (Gradle plugin
   portals, package registries) gets blocked or TLS-broken (`PKIX path building
   failed`). Consequence: JS/TS builds against local caches usually self-verify,
   JVM/Gradle builds usually cannot — expect UNRUN proofs and verify those
   outside the sandbox.

## Recon packets (read-only surveys)

Codex is also the cheap way to survey a large codebase. Same invocation, but the
packet asks only for analysis and forbids edits:

```
Survey <area>. Do not modify any file.
Answer: <the specific questions>.
## REPORT — findings with file:line references, ≤60 lines.
```

Claude reads the report; the exploration tokens were codex's.
