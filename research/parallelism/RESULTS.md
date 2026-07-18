# MAP executor parallelism - stress test results

2026-07-18, Windows 11 host (i9-13900K), Git Bash, one machine, one account per provider.
Method: `run-wave.sh` spawns N concurrent CLI processes per executor with a trivial one-line prompt (Grok `-p --reasoning-effort low`, Kimi `-m kimi-code/k3 -p`), waits for all children, and verifies each produced its unique token.

## Numbers

| Wave | Concurrent procs | Success | Wall time | Per-agent min/avg/max |
|---|---|---|---|---|
| grok x10 | 10 | **10/10** | 12 s | - |
| kimi x10 | 10 | **10/10** | 19 s | - |
| both x30 | **60** | **60/60** | 33 s | 10.7 / 18.9 / 31.5 s |
| both x50 | **100** | **100/100** | 41 s | 9.1 / 25.6 / 33.5 s |

Zero rate-limit errors, zero spawn failures, zero auth throttles, on either provider, at any scale tested.
Latency degrades gracefully (avg 18.9 s at 60 procs -> 25.6 s at 100), consistent with local process contention rather than API pushback.

## Findings for the MAP skill

1. **The bottleneck is not the CLIs or the APIs.** Both providers absorbed 50 concurrent sessions each without complaint. The skill's historical "max 3 parallel" cap is far below the real capacity.
2. **The real limits are orchestration-side**: task DISJOINTNESS (parallel tasks must touch provably disjoint files in one working tree) and the orchestrator's review bandwidth (every task still needs a hostile gate). Those, not concurrency, should size a wave.
3. **Recommended production guidance**: file-disjoint implementation packets in waves of up to ~10-15 per executor (heavier packets hold connections for minutes - unverified at that duration beyond 2x2; trivial calls verified to 50x2). Scale-out beyond one wave = sequential waves, exactly like CI shards.
4. **Launch pattern (hard-won on Windows/Git Bash)**: one runner script that spawns children with `&`, records per-agent out/err files, and `wait`s for every PID - a bare `cmd &` inside a compound backgrounded command is orphaned and killed when its parent shell exits. Never dispatch that way.
5. Per-agent artifacts (out/err/CSV) make failure attribution trivial; keep them out of git (out/ is ignored) and surface only the summary.

## Cost

Entire experiment (130 agent invocations): trivial - one-line prompts, low reasoning effort, ~a few hundred output tokens per agent.
