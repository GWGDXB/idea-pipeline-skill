#!/usr/bin/env bash
# scout.sh daily    condense new learnings (finished/parked ideas, decision files) → learnings/full.md, refresh executive.md
# scout.sh weekly   research tools/sources.md against tools/criteria.md → tools/pending-swaps.md
# Never touches a running idea. Commits on main.

source "$(dirname "${BASH_SOURCE[0]}")/system/lib/common.sh"
mode="${1:-}"; [[ "$mode" == "daily" || "$mode" == "weekly" ]] || { sed -n '2,4p' "$0"; exit 1; }

cfg="scout-$mode"
model="$(cfg_get "$cfg" model sonnet)"; turns="$(cfg_get "$cfg" turns 30)"; budget="$(cfg_get "$cfg" budget 2)"
tools="$(cfg_get "$cfg" tools "Read,Write,Edit,Glob,Grep")"

# Daily: build a manifest of what changed since the last pass so the run reads only that (technique 3/6).
manifest="$ROOT/learnings/.daily-manifest.md"
if [[ "$mode" == "daily" ]]; then
  {
    echo "# Daily manifest $(now)"
    echo "## Ideas and their state"
    for id in $(list_ideas); do
      pm="$(idea_dir "$id")/progress.md"
      echo "- $id · stage $(pm_get "$pm" stage) · $(pm_get "$pm" status) · spent \$$(pm_get "$pm" budget_usd_spent) · planned \$$(pm_get "$pm" budget_usd_planned)"
    done
    echo "## Decision files (B's calibration answers)"
    find "$ROOT/.worktrees" -path '*/gates/*.decision.md' -newer "$ROOT/learnings/full.md" 2>/dev/null | sed "s|$ROOT/||" | sed 's/^/- /'
    echo "## Score files changed since last pass"
    find "$ROOT/.worktrees" -path '*/scores/*.md' -newer "$ROOT/learnings/full.md" 2>/dev/null | sed "s|$ROOT/||" | sed 's/^/- /'
  } > "$manifest"
  prompt="Scout daily pass. Read learnings/.daily-manifest.md, then only the files it lists. Append dated entries to learnings/full.md (what worked, what failed, score deltas, tokens spent vs planned, recurring calibration answers). Keep full.md ≤ 250 lines: when over, merge the oldest entries into one dated summary line each — nothing deleted without a summary. Then rewrite learnings/executive.md (≤ 50 lines): only rules that changed an outcome — always do, never do, which tool for which step. Propose threshold or anchor changes as a line in tools/pending-swaps.md, never by editing system/. Write nothing outside learnings/ and tools/pending-swaps.md."
else
  prompt="Scout weekly pass. Read tools/current.md, tools/criteria.md, tools/sources.md. Fetch each source (WebFetch/WebSearch) — do not recall. For any tool or model that beats a current one on the criteria, add a row to tools/pending-swaps.md with dated evidence and which criteria it meets. Refresh the token→USD rates in tools/current.md's config block only if you fetched the pricing page today; note the date. Append a dated 3-line visit log to learnings/full.md. Write nothing outside tools/pending-swaps.md, tools/current.md (rates only) and learnings/full.md."
fi

log "scout $mode · model=$model turns=$turns budget=\$$budget"
( cd "$ROOT" && keep_awake "$CLAUDE_BIN" -p "$prompt" --model "$model" --max-turns "$turns" --max-budget-usd "$budget" \
    --allowedTools "$tools" --permission-mode acceptEdits --output-format json > "$ROOT/learnings/.scout-$mode.json" 2> "$ROOT/learnings/.scout-$mode.err" ) || log "scout $mode: claude exited non-zero (see learnings/.scout-$mode.err)"

# Enforce caps mechanically, whatever the model did.
if [[ $(wc -l < "$ROOT/learnings/executive.md") -gt 50 ]]; then log "executive.md over 50 lines — truncating"; head -50 "$ROOT/learnings/executive.md" > "$ROOT/learnings/.tmp" && mv "$ROOT/learnings/.tmp" "$ROOT/learnings/executive.md"; fi

git_root add learnings/executive.md learnings/full.md tools/pending-swaps.md tools/current.md >/dev/null 2>&1 || true
git_root commit -q -m "scout: $mode pass $(today)" >/dev/null 2>&1 || true
log "scout $mode done"
