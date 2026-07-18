# Phase 0 - Prism: multi-perspective scope expansion

Before planning, fan the user's RAW request out to independent cheap-executor agents, each reading it through ONE assigned lens, then synthesize. The user's words may under-describe the task; the prism recovers the full scope before any decision is frozen. Validated: 100 concurrent CLI agents, zero failures (research/parallelism).

## When

- Default ON for tier L, recommended for tier M, skip for S.
- Always when the request is one sentence, arrived mid-conversation, or the orchestrator catches itself guessing intent.

## Mechanics

1. Write the request **VERBATIM** to `.map/prism/REQUEST.md` (never paraphrase before fan-out - paraphrase is already an interpretation).
2. Dispatch ALL lenses in parallel (8-12; Kimi/Grok CLI, low/medium effort, READ-ONLY - no edits). Each agent gets: the verbatim request, the repo path, its single lens prompt, and a mandatory output shape written to `.map/prism/<lens>.md`, capped at 40 lines:
   - READING - what the request means through this lens (steelman it)
   - SCOPE - concrete items this lens adds to the work
   - RISKS - what goes wrong if this lens is ignored
   - QUESTIONS - max 3, ranked by how much the answer changes the build
3. Lenses never see each other's output (independence is the value).

## Default lens battery (swap up to 3 for task-specific ones)

| Lens | Assignment |
|---|---|
| intent | Steelman 3 distinct readings of the user's words; pick the most probable; say what they are ACTUALLY trying to achieve beyond the literal ask |
| minimal | The smallest shippable interpretation that honestly satisfies the request |
| maximal | The full vision this request points at; what the user will ask for next after v1 ships |
| adversarial | Failure modes, edge cases, abuse, security/privacy; what breaks at 10x scale |
| architecture | How it fits the existing codebase: reuse targets, blast radius, what NOT to touch |
| ux-product | The user-facing experience end to end: states, copy, discoverability, error paths |
| ops-cost | Deploy story, run cost, monitoring, rollback, who gets paged |
| interrogator | The questions that SHOULD have been asked before building anything; rank them |

## Synthesis (orchestrator judgment - never delegated)

Read only the 8-12 lens files. Produce `.map/PRISM.md`:

1. **Converged scope** - what every lens agrees the task includes.
2. **Divergences** - where lenses disagree. Each divergence becomes either a user question or a numbered decision. This section is the reason Prism exists.
3. **Distilled questions** - at most 4, merged and ranked from the lens QUESTIONS; feed them into the tier interview (AskUserQuestion round).
4. **Recommended scope statement** - one paragraph the user can veto.

Then proceed to Phase 1 (recon/interview/decisions) with PRISM.md as input. Cost: ~2-4 minutes and cents.

## Dispatch snippet (Git Bash; children MUST be waited on)

```bash
mkdir -p .map/prism && cp REQUEST.md .map/prism/
PIDS=()
for L in intent minimal maximal adversarial architecture ux-product ops-cost interrogator; do
  command kimi -m "kimi-code/k3" -p "Read .map/prism/REQUEST.md (the user's verbatim request) and this repo. Analyze ONLY through the '$L' lens per .map/prism/LENSES.md. Write your report to .map/prism/$L.md (<=40 lines, sections READING/SCOPE/RISKS/QUESTIONS). Read-only otherwise." \
    > ".map/prism/out-$L.log" 2>&1 & PIDS+=($!)
done
for p in "${PIDS[@]}"; do wait "$p"; done
```

(Grok equivalent: `grok -p "<same>" -m grok-4.5 --reasoning-effort medium --no-subagents --output-format plain`. Mixing executors across lenses is fine and adds model diversity.)
