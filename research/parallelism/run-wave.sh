#!/bin/bash
# Parallelism stress test for MAP executors (Grok / Kimi CLIs).
# Usage: run-wave.sh <grok|kimi|both> <N per executor> <wave-label>
# Spawns N concurrent CLI processes with a trivial prompt, waits for ALL
# children (they die with the parent shell otherwise), writes a CSV of
# per-agent timings plus a summary.
set -u
EXEC="$1"; N="$2"; WAVE="$3"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/out/$WAVE"
mkdir -p "$OUT"
CSV="$OUT/results.csv"
echo "executor,agent,exit,seconds,ok" > "$CSV"
KIMI_BIN="/c/Users/Andres Lee/.kimi-code/bin/kimi.exe"

run_one() { # $1 executor, $2 index
  local t0 t1 rc ok
  t0=$(date +%s.%N)
  if [ "$1" = "grok" ]; then
    command grok -p "Output exactly this token and nothing else: AGENT-$2-OK" \
      -m grok-4.5 --reasoning-effort low --no-subagents --output-format plain \
      > "$OUT/$1-$2.txt" 2> "$OUT/$1-$2.err"
  else
    "$KIMI_BIN" -m "kimi-code/k3" -p "Output exactly this token and nothing else: AGENT-$2-OK" \
      > "$OUT/$1-$2.txt" 2> "$OUT/$1-$2.err"
  fi
  rc=$?
  t1=$(date +%s.%N)
  grep -q "AGENT-$2-OK" "$OUT/$1-$2.txt" && ok=1 || ok=0
  echo "$1,$2,$rc,$(awk "BEGIN{printf \"%.1f\", $t1-$t0}"),$ok" >> "$CSV"
}

W0=$(date +%s)
PIDS=()
for i in $(seq 1 "$N"); do
  if [ "$EXEC" = "both" ]; then
    run_one grok "$i" & PIDS+=($!)
    run_one kimi "$i" & PIDS+=($!)
  else
    run_one "$EXEC" "$i" & PIDS+=($!)
  fi
done
for p in "${PIDS[@]}"; do wait "$p"; done
W1=$(date +%s)

PYTHONIOENCODING=utf-8 python - "$CSV" "$WAVE" "$EXEC" "$N" $((W1-W0)) <<'EOF' | tee "$OUT/SUMMARY.txt"
import csv, sys
rows = [r for r in csv.reader(open(sys.argv[1]))][1:]
ok = sum(1 for r in rows if r[4] == "1")
d = [float(r[3]) for r in rows]
per = {}
for r in rows:
    per.setdefault(r[0], []).append((r[4] == "1", float(r[3])))
print(f"WAVE={sys.argv[2]} exec={sys.argv[3]} n={sys.argv[4]} procs={len(rows)} ok={ok} wall={sys.argv[5]}s")
print(f"per-agent seconds: min={min(d):.1f} avg={sum(d)/len(d):.1f} max={max(d):.1f}")
for k, v in per.items():
    dd = [s for _, s in v]
    print(f"  {k}: ok={sum(1 for o,_ in v if o)}/{len(v)} min={min(dd):.1f} avg={sum(dd)/len(dd):.1f} max={max(dd):.1f}")
EOF
