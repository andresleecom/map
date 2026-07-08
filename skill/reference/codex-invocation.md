# Codex CLI invocation reference

Tested against codex-cli 0.142.x, headless, from Claude Code's Bash tool (Git Bash
on Windows; identical on macOS/Linux).

## The working command

```bash
codex exec \
  -s workspace-write \
  -c approval_policy=never \
  --skip-git-repo-check \
  -C "<absolute repo path>" \
  -o ".map/out/NN.md" \
  - < ".map/tasks/NN-<slug>.md"
```

Run it with the Bash tool in background mode (`run_in_background: true`) — codex
runs take minutes and Claude gets notified on exit. Then read only the `## REPORT`
tail of the output file.

For very short prompts, the argument form also works — but stdin must still be
closed:

```bash
codex exec -s workspace-write -c approval_policy=never --skip-git-repo-check \
  -C "<repo>" -o "<outfile>" "<prompt>" < /dev/null
```

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
| `-c model_reasoning_effort=<level>` | Optional override; lower for trivial tasks, raise on a strike-1 retry. |

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

## Recon packets (read-only surveys)

Codex is also the cheap way to survey a large codebase. Same invocation, but the
packet asks only for analysis and forbids edits:

```
Survey <area>. Do not modify any file.
Answer: <the specific questions>.
## REPORT — findings with file:line references, ≤60 lines.
```

Claude reads the report; the exploration tokens were codex's.
