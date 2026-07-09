# Codex CLI invocation reference

Tested against codex-cli 0.144.x, headless, from Claude Code's Bash tool (Git Bash
on Windows; identical on macOS/Linux, except Intel Macs — see the platform note).

## The working command

```bash
codex exec \
  -s workspace-write \
  -c approval_policy=never \
  --skip-git-repo-check \
  -m gpt-5.6-sol \
  -c model_reasoning_effort=xhigh \
  -C "<absolute repo path>" \
  -o ".map/out/NN.md" \
  - < ".map/tasks/NN-<slug>.md" 2>/dev/null
```

Run it with the Bash tool in background mode (`run_in_background: true`) — codex
runs take minutes (quiet xhigh runs up to ~30 min are normal, `max` retries
longer; don't kill early) and Claude gets notified on exit. Then read only the
`## REPORT` tail of the output file.

The prompt goes via file, always — never inline: files give an audit trail in
`.map/tasks/`, dodge shell-quoting bugs, and avoid Windows arg-length limits.
`2>/dev/null` suppresses codex's thinking noise (it bloats any context that peeks
at interim output); drop it only when debugging a failing run — the `-o` file
carries the result either way.

## The model: GPT-5.6-Sol, pinned

MAP delegates to `gpt-5.6-sol` — OpenAI's frontier agentic coding model in the
5.6 family (Sol = frontier, Terra = balanced, Luna = fast/cheap). Pin it with
`-m` on every dispatch; never ride the machine's `config.toml` default, because
a MAP must behave the same on every machine that resumes it.

Two traps in this setup:

1. **Sol's catalog default effort is `low`.** A dispatch that pins the model but
   forgets the effort flag falls back to the machine's config — or, absent that,
   to `low` — and nothing warns you. The model flag and the effort flag travel
   together, always.
2. **Effort tiers go beyond `xhigh`**: the 5.6 family adds `max` (deepest
   single-agent reasoning) and `ultra` (`max` + proactive delegation to parallel
   subagents). House defaults stay `xhigh` for implementation and `medium` for
   surveys — OpenAI recommends `xhigh` for asynchronous agentic tasks with long
   runs, and says most tasks don't need `max` or `ultra`. Reserve `max` for
   strike-1 retries of reasoning failures, and budget it more patience than
   xhigh's ~30-min ceiling. Never use `ultra` in packets: parallel subagents
   editing at once create the exact conflicts the packet's tight scoping exists
   to prevent, it burns 2-3× the tokens, and it's account-gated — three ways to
   lose for zero MAP upside.

Platform note: Sol has an open crash on Intel macOS — SIGTRAP on its first shell
call ([openai/codex#30861](https://github.com/openai/codex/issues/30861)); the
issue reports `gpt-5.5` working on the same machines and Sol fine on Linux
(Windows verified here). On x86_64 Macs pin `gpt-5.5` until it's fixed — and
since 5.5 tops out at `xhigh`, retries there stay at `xhigh`.

Verify the pin took effect (once per environment): the session log under
`~/.codex/sessions/` records `"model":"gpt-5.6-sol"` and the effective effort.

One early practitioner report says Sol overstates its own verification results
more readily than 5.5 did — one more reason the MAP rule that Claude re-runs the
verify bar itself is not optional.

## Follow-up runs: `resume`

For strike-1 retries, resuming the previous codex session keeps its context (it
already read the codebase) and is cheaper than a fresh run:

```bash
(cd "<repo>" && codex exec resume <session-id> \
  -m gpt-5.6-sol -c model_reasoning_effort=max \
  -c 'sandbox_mode="workspace-write"' -c approval_policy=never \
  -o ".map/out/NN-r2.md" - < ".map/tasks/NN-<slug>-r2.md" 2>/dev/null)
```

Caveats, verified on 0.144 with real resumed runs:

- `resume` rejects the `-s` and `-C` flags outright (`error: unexpected
  argument`, exit 2) — pass the sandbox as `-c 'sandbox_mode="workspace-write"'`
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
| `exec` | Non-interactive, single-shot execution mode. |
| `-s workspace-write` | Sandbox: codex may write inside the workspace, nothing outside. |
| `-c approval_policy=never` | Never pause to ask for approval (would hang headless). |
| `--skip-git-repo-check` | Don't refuse to run in odd repo states (worktrees, subdirs). |
| `-m gpt-5.6-sol` | Pin the delegate model; config defaults vary per machine. Works on `resume` too. |
| `-C <path>` | Working directory — always pass the repo root explicitly. |
| `-o <file>` | Write the final message to a file; keeps Claude's context clean. |
| `-` + `< packet.md` | Read the prompt from stdin (file), which also closes stdin. |
| `-c model_reasoning_effort=<level>` | Never omit — unpinned it falls back to machine config or Sol's `low` default. Tier policy: see The model. |
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

Codex is also the cheap way to survey a large codebase. Same invocation with the
effort dropped to `-c model_reasoning_effort=medium` (and `-s read-only` fits a
survey better than workspace-write), and a packet that asks only for analysis
and forbids edits:

```
Survey <area>. Do not modify any file.
Answer: <the specific questions>.
## REPORT — findings with file:line references, ≤60 lines.
```

Claude reads the report; the exploration tokens were codex's.
