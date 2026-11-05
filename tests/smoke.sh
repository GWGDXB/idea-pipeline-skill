#!/usr/bin/env bash
# tests/smoke.sh — offline check of the wrapper: install → idea → fake gate → decide → advance → park.
# No model calls, no network, nothing written outside a temp folder. Run:  bash tests/smoke.sh
set -u   # no pipefail: checks pipe into grep -q, which may close the pipe early
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ip() { bash "$SKILL_DIR/scripts/ip.sh" "$@"; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/ip-smoke.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/config"      # keep the real ~/.config/idea-pipeline/root untouched
unset IDEA_PIPELINE_DIR
pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }
fm()  { awk -v k="$2" '/^---[[:space:]]*$/ { f++; next } f==1 && $0 ~ "^"k":" { sub("^"k":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$1"; }

echo "1 install"
out="$(ip install "$tmp/pipe" --no-pointer 2>&1)" || { echo "$out"; bad "install exited non-zero"; }
[[ -f "$tmp/pipe/run.sh" && -f "$tmp/pipe/.env" && -f "$tmp/pipe/system/lib/common.sh" ]] && ok "files in place" || bad "files missing"
git -C "$tmp/pipe" rev-parse -q --verify HEAD >/dev/null 2>&1 && ok "first commit made" || bad "no first commit"
grep -q 'installed' "$tmp/pipe/learnings/full.md" && ok "install logged in learnings/full.md" || bad "learnings not logged"
[[ -z "$(ls -A "$tmp/pipe/.worktrees" 2>/dev/null)" ]] && ok "no ideas shipped with the template" || bad "template carried ideas"
grep -q 'bjoernlauen\|/Users/home' "$tmp/pipe/gates/INBOX.md" && bad "INBOX carries owner data" || ok "INBOX clean"
export IDEA_PIPELINE_DIR="$tmp/pipe"
[[ "$(ip root 2>/dev/null)" == "$tmp/pipe" ]] && ok "root resolves via IDEA_PIPELINE_DIR" || bad "root did not resolve"
ip doctor >/dev/null 2>&1 && ok "doctor runs" || bad "doctor failed"
ip status 2>/dev/null | grep -q 'no ideas yet' && ok "status: no ideas yet" || bad "status without ideas"

echo "2 new idea (no triage)"
id="$(printf 'A tool that turns meeting notes into tasks for a five-person studio.\n' | ip new smoke-idea - --no-run 2>/dev/null | tail -1)"
[[ -n "$id" && -d "$tmp/pipe/.worktrees/$id/ideas/$id" ]] && ok "created $id" || bad "new --no-run (got '$id')"
pm="$tmp/pipe/.worktrees/$id/ideas/$id/progress.md"
ip status 2>/dev/null | grep -q "$id" && ok "status lists it" || bad "status does not list it"
[[ "$(fm "$pm" title)" == "Smoke Idea" ]] && ok "title cased portably" || bad "title: $(fm "$pm" title)"
[[ -z "$(ip gates 2>/dev/null)" ]] && ok "gates: nothing open" || bad "gates should print nothing"
ip step "$id" >/dev/null 2>&1 && bad "step should refuse a paid iteration on a running idea" || ok "step refuses a paid iteration"

echo "3 gate announced"
sed -e "s/{{NN}}/01/; s/{{TITLE}}/hard gate/; s/{{ID}}/$id/" "$tmp/pipe/system/templates/gate.md" > "$tmp/pipe/.worktrees/$id/ideas/$id/gates/01.md"
( source "$tmp/pipe/system/lib/common.sh"; pm_set "$pm" stage 1; pm_set "$pm" status awaiting-gate; pm_set "$pm" gate '"01"' )
ip step "$id" >/dev/null 2>&1
ip gates 2>/dev/null | grep -q "| $id | 01 |" && ok "gate 01 in INBOX" || bad "gate not announced"
ip show "$id" gate 2>/dev/null | grep -q '^# Gate 01' && ok "show <id> gate prints the page" || bad "show gate"
grep -q 'EXPORT FAILED: DRIVE_DIR unset' "$tmp/pipe/.worktrees/$id/ideas/$id/gates/01.md" && ok "export failure visible on the page" || bad "export line missing"
ip run "$id" >/dev/null 2>&1 && bad "run should refuse while a gate waits" || ok "run refuses while a gate waits"
ip decide "$id" 02 go >/dev/null 2>&1 && bad "decide should refuse the wrong gate id" || ok "decide refuses a wrong gate id"
ip decide "$id" 01 maybe >/dev/null 2>&1 && bad "decide should refuse an unknown verdict" || ok "decide refuses an unknown verdict"

echo "4 decide go"
ip decide "$id" 01 go --answer "6 is right" --answer "three sources fine" --notes "focus on pricing" >/dev/null 2>&1 || bad "decide exited non-zero"
dec="$tmp/pipe/.worktrees/$id/ideas/$id/gates/01.decision.md"
grep -q '^verdict: go' "$dec" && grep -q '^1\. 6 is right' "$dec" && grep -q '^2\. three sources fine' "$dec" && grep -q 'focus on pricing' "$dec" && ok "decision file written" || bad "decision file wrong"
grep -q "| $id | 01 |.*→ decided go" "$tmp/pipe/gates/INBOX.md" && ok "INBOX marked decided" || bad "INBOX not marked"
[[ "$(fm "$pm" stage)" == "2" && "$(fm "$pm" status)" == "running" ]] && ok "go on 01 → stage 2, running" || bad "after go: stage $(fm "$pm" stage) status $(fm "$pm" status)"
[[ -z "$(ip gates 2>/dev/null)" ]] && ok "gates empty again" || bad "gates still open"
ip decide "$id" 01 go >/dev/null 2>&1 && bad "decide should refuse when no gate waits" || ok "decide refuses when no gate waits"

echo "5 advance"
ip advance "$id" >/dev/null 2>&1
[[ "$(fm "$pm" stage)" == "3" && "$(fm "$pm" status)" == "running" ]] && ok "advance → stage 3, running" || bad "advance: stage $(fm "$pm" stage) status $(fm "$pm" status)"
grep -q 'ip.sh advance' "$pm" && ok "advance logged in progress.md" || bad "advance not logged"

echo "6 jobs / log"
ip jobs 2>/dev/null | grep -q 'no jobs running' && ok "jobs: none" || bad "jobs"
ip log >/dev/null 2>&1 && ok "log runs" || bad "log"

echo "7 park"
cp "$tmp/pipe/.worktrees/$id/ideas/$id/gates/01.md" "$tmp/pipe/.worktrees/$id/ideas/$id/gates/02.md"
( source "$tmp/pipe/system/lib/common.sh"; pm_set "$pm" status awaiting-gate; pm_set "$pm" gate '"02"' )
ip step "$id" >/dev/null 2>&1
ip decide "$id" 02 park >/dev/null 2>&1
[[ "$(fm "$pm" status)" == "parked" ]] && ok "park → parked" || bad "park: status $(fm "$pm" status)"
ip run "$id" >/dev/null 2>&1 && bad "run should refuse a parked idea" || ok "run refuses a parked idea"
ip resume "$id" >/dev/null 2>&1 && bad "resume should refuse a non-failed idea" || ok "resume refuses a non-failed idea"

echo "8 git state"
n_idea="$(git -C "$tmp/pipe" log --oneline "idea/$id" 2>/dev/null | wc -l | tr -d ' ')"; n_main="$(git -C "$tmp/pipe" log --oneline main | wc -l | tr -d ' ')"
[[ "$n_idea" -ge 4 && "$n_main" -ge 3 ]] && ok "commits: $n_idea on idea/$id, $n_main on main (INBOX)" || bad "commits: $n_idea on the idea branch, $n_main on main"
git -C "$tmp/pipe" status --porcelain | grep -q . && bad "main working tree dirty after the run" || ok "main working tree clean"
ip use "$tmp/nowhere" >/dev/null 2>&1 && bad "use should refuse a non-pipeline" || ok "use refuses a non-pipeline"

echo "9 background run with the stub claude (no model, no cost)"
awk -v v="$SKILL_DIR/tests/stub-claude.sh" '/^CLAUDE_BIN=/ { print "CLAUDE_BIN=\"" v "\""; next } { print }' "$tmp/pipe/.env" > "$tmp/pipe/.env.tmp" && mv "$tmp/pipe/.env.tmp" "$tmp/pipe/.env"
id2="$(printf 'A second brief.\n' | ip new dry-idea - --no-run 2>/dev/null | tail -1)"
pm2="$tmp/pipe/.worktrees/$id2/ideas/$id2/progress.md"
ip run "$id2" >/dev/null 2>&1 && ok "run launched" || bad "run did not launch"
ip run "$id2" >/dev/null 2>&1 && bad "run should refuse a duplicate launch" || ok "run refuses a duplicate launch"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [[ "$(fm "$pm2" status)" == "awaiting-gate" ]] && break; sleep 1; done
[[ "$(fm "$pm2" status)" == "awaiting-gate" && "$(fm "$pm2" gate)" == "B0" ]] && ok "three stub cap hits → budget gate B0 (took ${i}s)" || bad "background run: status $(fm "$pm2" status) gate $(fm "$pm2" gate) after ${i}s — $(tail -2 "$tmp/pipe/run.log" | tr '\n' ' ')"
sleep 1; ip jobs 2>/dev/null | grep -q 'no jobs running' && ok "job finished and pid file cleared" || bad "job still listed: $(ip jobs 2>/dev/null)"
ip gates 2>/dev/null | grep -q "| $id2 | B0 |" && ok "budget gate in INBOX" || bad "budget gate not announced"
ip show "$id2" gate 2>/dev/null | grep -q 'budget checkpoint' && ok "budget gate page readable" || bad "budget gate page"
ip decide "$id2" B0 go >/dev/null 2>&1
[[ "$(fm "$pm2" budget_factor)" == "2.0" && "$(fm "$pm2" status)" == "running" ]] && ok "go on B0 doubles the cap factor" || bad "after B0 go: factor '$(fm "$pm2" budget_factor)' status $(fm "$pm2" status)"

echo; echo "smoke: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
