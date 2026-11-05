#!/usr/bin/env bash
# tests/probe-01.sh — acceptance check for build step 1 (compliance probe, not recall).
# Creates a throwaway idea from a 3-line brief whose answer depends on one decision-driving fact, runs triage + validate
# with run.sh, then greps the outputs. Four checks, no judgment call. Cleans up its worktree and branch.
#
#   (a) ≥3 dated sources for the decision-driving fact      (research.md has ≥3 lines with a URL and a year)
#   (b) every output ends with a Known unknowns section
#   (c) kill criteria exist in IDEA.md before any research line in the log
#   (d) the run stops at gate 01 (status awaiting-gate, gates/01.md exists, no plan.md)
#
# Usage: tests/probe-01.sh [--keep]            create a probe idea, run it, check it
#        tests/probe-01.sh --check <id>       only run the four checks on an existing idea (e.g. after a resumed run)

source "$(dirname "${BASH_SOURCE[0]}")/../system/lib/common.sh"
KEEP=0; CHECK_ID=""
[[ "${1:-}" == "--keep" ]] && KEEP=1
[[ "${1:-}" == "--check" ]] && { CHECK_ID="${2:?idea id}"; KEEP=1; }
pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

brief="Should my company register for UAE corporate tax this year? We are a Shams free-zone LLC with revenue below AED 3m. The answer depends on the current small-business relief threshold and whether free-zone qualifying income rules apply to media production services. Decide yes/no."
if [[ -n "$CHECK_ID" ]]; then
  id="$CHECK_ID"; require_idea "$id"
else
  slug="probe-$(date +%H%M%S)"
  echo "probe-01: creating idea $slug"
  id="$("$ROOT/new-idea.sh" --no-run "$slug" - <<<"$brief" 2>/dev/null)"
  echo "probe-01: running until the first gate (triage → validate)"
  "$ROOT/run.sh" "$id" --loop >/dev/null 2>&1 || true
fi
dir="$(idea_dir "$id")"; pm="$dir/progress.md"

echo "probe-01: checks for $id"
# (a)
if [[ -f "$dir/research.md" ]]; then
  n="$(cat "$dir/research.md" "$dir"/research/*.md 2>/dev/null | grep -c -E 'https?://' || true)"
  y="$(cat "$dir/research.md" "$dir"/research/*.md 2>/dev/null | grep -c -E '\b20[0-9]{2}\b' || true)"
  [[ "${n:-0}" -ge 3 && "${y:-0}" -ge 3 ]] && ok "(a) $n source URLs, $y dated lines in research.md + research/" || bad "(a) only ${n:-0} source URLs / ${y:-0} dated lines in research.md + research/"
else bad "(a) research.md missing"; fi
# (b)
missing=""
for f in "$dir/IDEA.md" "$dir/research.md" "$dir/panel.md" "$dir/scores/round-1.md" "$dir/gates/01.md"; do
  [[ -f "$f" ]] || { missing="$missing $(basename "$f")(absent)"; continue; }
  grep -q -i '^## *Known unknowns' "$f" || missing="$missing $(basename "$f")"
done
[[ -z "$missing" ]] && ok "(b) every output has a Known unknowns section" || bad "(b) no Known unknowns in:$missing"
# (c)
# the commit run.sh made at the end of stage 0 must already contain filled kill criteria (research starts in stage 1)
c0="$(git_wt "$id" log --format=%H --grep='stage 0 iter' | tail -1)"
if [[ -n "$c0" ]]; then
  k0="$(git_wt "$id" show "$c0:ideas/$id/IDEA.md" 2>/dev/null | awk '/^## Kill criteria/{f=1;next} /^## /{f=0} f && /^[0-9]+\. ./' | wc -l | tr -d ' ')"
  [[ "${k0:-0}" -ge 3 ]] && ok "(c) $k0 kill criteria committed at end of stage 0, before any research" || bad "(c) only ${k0:-0} kill criteria in the stage-0 commit"
else bad "(c) no stage-0 commit found"; fi
# (d)
st="$(pm_get "$pm" status)"; gt="$(pm_get "$pm" gate)"
if [[ "$st" == "awaiting-gate" && "$gt" == "01" && -f "$dir/gates/01.md" && ! -f "$dir/plan.md" ]]; then ok "(d) stopped at gate 01, no plan.md"
else bad "(d) status=$st gate=$gt plan.md=$([[ -f "$dir/plan.md" ]] && echo present || echo absent)"; fi

echo "probe-01: $pass passed, $fail failed · spent \$$(pm_get "$pm" budget_usd_spent)"
if [[ $fail -gt 0 ]]; then
  KEEP=1
  echo "probe-01: kept for inspection → $dir"
  echo "  progress log:"; tail -6 "$pm" | sed 's/^/    /'
  if [[ -f "$dir/.run/last.err" && -s "$dir/.run/last.err" ]]; then echo "  last.err (tail):"; tail -c 600 "$dir/.run/last.err" | sed 's/^/    /'; echo; fi
  if [[ -f "$dir/.run/last.json" ]]; then echo "  last.json summary:"; python3 -c '
import json,sys
try:
    d=json.load(open(sys.argv[1])); print("   ", {k:d.get(k) for k in ("subtype","is_error","num_turns","total_cost_usd","duration_ms")}); print("    result:", str(d.get("result",""))[:500].replace("\n"," "))
except Exception as e: print("    (unreadable:", e, ")")' "$dir/.run/last.json"; fi
  echo "  clean up later with:  git worktree remove --force $(wt_dir "$id") && git branch -D $(idea_branch "$id")"
fi
if [[ $KEEP -eq 0 ]]; then
  git_root worktree remove --force "$(wt_dir "$id")" >/dev/null 2>&1 || true
  git_root branch -D "$(idea_branch "$id")" >/dev/null 2>&1 || true
  # drop the probe's INBOX lines
  tmp="$(mktemp "${TMPDIR:-/tmp}/idea-pipeline.XXXXXX")"; grep -v "^| $id |" "$ROOT/gates/INBOX.md" > "$tmp" && mv "$tmp" "$ROOT/gates/INBOX.md"
  git_root add gates/INBOX.md >/dev/null 2>&1; git_root commit -q -m "probe-01 cleanup" >/dev/null 2>&1 || true
else echo "kept: $dir"; fi
[[ $fail -eq 0 ]]
