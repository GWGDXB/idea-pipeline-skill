#!/usr/bin/env bash
# run.sh <id>              run one step for an idea: apply a pending decision, advance a stage, or run one headless iteration
# run.sh <id> --loop       keep stepping until the idea waits for a gate, parks, finishes or fails
# run.sh --all [--loop]    step every idea once (for cron), or loop each in turn
# run.sh --status          one line per idea
#
# The loop owns: branches/worktrees, commits, model and budget flags, Drive exports, the INBOX, decisions.
# The headless Claude run owns: the stage's content and progress.md. It never sees another idea.

source "$(dirname "${BASH_SOURCE[0]}")/system/lib/common.sh"

STAGE_NAMES=(Triage Validate Plan Prototype Build Review)
usage() { sed -n '2,6p' "$0"; exit 1; }

# ---------------------------------------------------------------------------
status_line() {
  local id="$1" pm; pm="$(idea_dir "$id")/progress.md"
  printf '%-40s stage %s %-9s status %-15s iter %-3s gate %-4s spent $%s\n' "$id" \
    "$(pm_get "$pm" stage)" "${STAGE_NAMES[$(pm_get "$pm" stage)]:-?}" "$(pm_get "$pm" status)" \
    "$(pm_get "$pm" iteration)" "$(pm_get "$pm" gate)" "$(pm_get "$pm" budget_usd_spent)"
}

# ---------------------------------------------------------------------------
run_iteration() {
  local id="$1" dir pm stage pb iter model turns budget tools prompt wt cost
  dir="$(idea_dir "$id")"; pm="$dir/progress.md"; wt="$(wt_dir "$id")"
  stage="$(pm_get "$pm" stage)"; pb="$(pm_get "$pm" playbook)"
  [[ "$stage" == "0" ]] && pb="_meta"
  [[ -f "$ROOT/playbooks/$pb.md" ]] || { pm_set "$pm" status failed; pm_log "$pm" "no playbook file for '$pb'"; die "$id: no playbook $pb"; }

  mkdir -p "$dir/.run"
  {
    printf '<!-- stage %s of playbook %s · triage budget gate threshold: USD %s for Validate+Plan -->\n\n' "$stage" "$pb" "$TRIAGE_BUDGET_GATE_USD"
    extract_stage "$ROOT/playbooks/$pb.md" "$stage" /dev/stdout
  } > "$dir/.run/stage.md"

  model="$(cfg_get "stage$stage" model opus)"
  turns="$(cfg_get "stage$stage" turns "$DEFAULT_MAX_TURNS")"
  budget="$(cfg_get "stage$stage" budget "$DEFAULT_MAX_BUDGET_USD")"
  local factor; factor="$(pm_get "$pm" budget_factor)"; [[ -n "$factor" ]] || factor=1
  budget="$(python3 -c 'import sys; print(round(float(sys.argv[1])*float(sys.argv[2]),2))' "$budget" "$factor")"
  tools="$(cfg_get "stage$stage" tools "Read,Write,Edit,Glob,Grep")"
  iter=$(( $(pm_get "$pm" iteration) + 1 )); pm_set "$pm" iteration "$iter"

  local last_dec; last_dec="$(ls "$dir/gates/"*.decision.md 2>/dev/null | tail -1 || true)"
  prompt="Idea Pipeline iteration. Idea: $id. Stage: $stage (${STAGE_NAMES[$stage]}). Iteration: $iter. Playbook: $pb.
Read, in this order: CLAUDE.md, system/ground-rules.md, system/token-discipline.md, learnings/executive.md, ideas/$id/progress.md, ideas/$id/.run/stage.md.
Then do exactly what ideas/$id/.run/stage.md says for stage $stage. Write only inside ideas/$id/. Update ideas/$id/progress.md (front matter + log + 'Next iteration should'). Stop when the stage section says to stop."
  [[ -n "$last_dec" ]] && prompt="$prompt
B's latest decision and notes: ideas/$id/gates/$(basename "$last_dec") — read it before anything else in the idea folder."

  log "$id: stage $stage (${STAGE_NAMES[$stage]}) iteration $iter · model=$model turns=$turns budget=\$$budget"
  pm_log "$pm" "run.sh start stage $stage iter $iter model=$model turns=$turns budget=\$$budget"

  set +e
  ( cd "$wt" && keep_awake "$CLAUDE_BIN" -p "$prompt" \
      --model "$model" --max-turns "$turns" --max-budget-usd "$budget" \
      --allowedTools "$tools" --permission-mode acceptEdits \
      --output-format json > "$dir/.run/last.json" 2> "$dir/.run/last.err" )
  local rc=$?
  set -e

  cost="$(python3 -c 'import json,sys
try: print(round(float(json.load(open(sys.argv[1])).get("total_cost_usd",0)),4))
except Exception: print(0)' "$dir/.run/last.json" 2>/dev/null || echo 0)"
  local spent; spent="$(python3 -c 'print(round(float(__import__("sys").argv[1])+float(__import__("sys").argv[2]),4))' "$(pm_get "$pm" budget_usd_spent)" "$cost" 2>/dev/null || echo 0)"
  pm_set "$pm" budget_usd_spent "$spent"

  local subtype iserr; read -r subtype iserr < <(python3 -c 'import json,sys
try: d=json.load(open(sys.argv[1])); print(d.get("subtype","?"), d.get("is_error",False))
except Exception: print("no-json", True)' "$dir/.run/last.json" 2>/dev/null || echo "no-json True")
  if [[ "$subtype" == "error_max_budget_usd" || "$subtype" == "error_max_turns" ]]; then
    # A cap is a checkpoint, not a failure: the next iteration continues from the files on disk.
    local stops; stops="$(pm_get "$pm" cap_stops)"; stops=$(( ${stops:-0} + 1 )); pm_set "$pm" cap_stops "$stops"
    if [[ "$(pm_get "$pm" status)" == "running" || -z "$(pm_get "$pm" status)" ]]; then
      if [[ $stops -lt 3 ]]; then
        pm_log "$pm" "CAP HIT ($subtype, \$$cost) — iteration $iter cut off mid-work. Next iteration: inventory ideas/$id/ and continue from what exists; do not redo finished files. (stop $stops/3)"
        log "$id: cap hit ($subtype) — continuing next iteration ($stops/3)"
      else
        write_budget_gate "$id" "$stage" "$subtype"
      fi
    fi
  elif [[ $rc -ne 0 || "$iserr" == "True" ]]; then
    local why; why="$(python3 -c 'import json,sys
try: print(str(json.load(open(sys.argv[1])).get("result",""))[:400].replace("\n"," "))
except Exception: print("")' "$dir/.run/last.json" 2>/dev/null)"; [[ -n "$why" ]] || why="$(tail -c 400 "$dir/.run/last.err" | tr '\n' ' ')"
    pm_log "$pm" "run.sh: claude ended rc=$rc subtype=$subtype — $why"
    log "$id: claude ended rc=$rc subtype=$subtype — $why"
    [[ "$(pm_get "$pm" status)" == "running" ]] && pm_set "$pm" status failed
  else
    pm_set "$pm" cap_stops 0
    pm_log "$pm" "run.sh end stage $stage iter $iter · cost \$$cost · status now: $(pm_get "$pm" status)"
  fi

  revert_outside_idea "$id"
  commit_idea "$id" "idea($id): stage $stage iter $iter [$(pm_get "$pm" status)]"

  [[ "$(pm_get "$pm" status)" == "awaiting-gate" ]] && handle_gate "$id"
  return 0
}

# ---------------------------------------------------------------------------
write_budget_gate() { # three consecutive cap stops → ask B instead of failing
  local id="$1" stage="$2" why="$3" dir pm nn
  dir="$(idea_dir "$id")"; pm="$dir/progress.md"; nn="B$stage"
  local factor; factor="$(pm_get "$pm" budget_factor)"; [[ -n "$factor" ]] || factor=1
  cat > "$dir/gates/$nn.md" <<EOF
# Gate $nn — budget checkpoint (written by run.sh)

**Idea:** $id · **Stage:** $stage (${STAGE_NAMES[$stage]}) · **Date:** $(today) · **Gate type:** budget

## Verdict recommended

\`go\` — three consecutive iterations of stage $stage were cut off by the per-iteration cap (\`$why\`). The work so far is in the idea folder; nothing is lost. \`go\` doubles this idea's cap (factor $factor → $(python3 -c "print(float('$factor')*2)")) and continues. \`park\` parks it.

## Where it stands

- Spent so far: \$$(pm_get "$pm" budget_usd_spent) · planned at triage: \$$(pm_get "$pm" budget_usd_planned)
- Last log lines:
$(tail -4 "$pm" | sed 's/^/  /')

## Calibration questions for B (1–3)

1. Is this stage doing too much per iteration (should the playbook split it), or is the cap in tools/current.md simply too low for this kind of idea?

## Drive

(run.sh fills this line after export)

## Known unknowns

- Whether the cut-off iterations left partial files that the next iteration will misread as finished.
EOF
  pm_set "$pm" status awaiting-gate; pm_set "$pm" gate "\"$nn\""; pm_set "$pm" cap_stops 0
  pm_log "$pm" "three cap stops in a row — budget gate $nn opened for B"
  log "$id: budget gate $nn opened"
}

# ---------------------------------------------------------------------------
handle_gate() {
  local id="$1" dir pm nn gate dest
  dir="$(idea_dir "$id")"; pm="$dir/progress.md"
  nn="$(pm_get "$pm" gate)"; gate="$dir/gates/$nn.md"
  if [[ -z "$nn" || ! -f "$gate" ]]; then
    pm_set "$pm" status failed; pm_log "$pm" "status awaiting-gate but gates/$nn.md missing"
    commit_idea "$id" "idea($id): gate page missing"; log "$id: gate page missing"; return 0
  fi
  # already announced?
  grep -q "^| $id | $nn |" "$ROOT/gates/INBOX.md" 2>/dev/null && return 0

  dest="$("$ROOT/system/lib/export.sh" "$id" "$gate" "$dir/IDEA.md" "$dir/progress.md")"
  if grep -q '(run.sh fills this line after export)' "$gate"; then
    local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/idea-pipeline.XXXXXX")"
    awk -v d="$dest" '{ sub(/\(run\.sh fills this line after export\)/, d); print }' "$gate" > "$tmp" && mv "$tmp" "$gate"
  else
    printf '\n## Drive\n\n%s\n' "$dest" >> "$gate"
  fi
  commit_idea "$id" "idea($id): gate $nn ready"

  announce() {
    printf '| %s | %s | %s | %s | %s |\n' "$id" "$nn" "$(now)" "ideas/$id/gates/$nn.md" "$dest" >> "$ROOT/gates/INBOX.md"
    git_root add gates/INBOX.md >/dev/null 2>&1 || true
    git_root commit -q -m "inbox: gate $nn for $id" -- gates/INBOX.md >/dev/null 2>&1 || true
  }
  with_lock inbox announce
  log "$id: GATE $nn waiting for B → ideas/$id/gates/$nn.md · Drive: $dest"
}

# ---------------------------------------------------------------------------
apply_decision() {
  local id="$1" dir pm nn dec verdict stage
  dir="$(idea_dir "$id")"; pm="$dir/progress.md"
  nn="$(pm_get "$pm" gate)"; dec="$dir/gates/$nn.decision.md"
  verdict="$(grep -m1 -E '^verdict:' "$dec" | sed -E 's/^verdict:[[:space:]]*//; s/[[:space:]]+$//' | tr '[:upper:]' '[:lower:]')"
  stage="$(pm_get "$pm" stage)"
  log "$id: decision on gate $nn → $verdict"
  pm_log "$pm" "B decided gate $nn: $verdict"
  "$ROOT/system/lib/export.sh" "$id" "$dec" >/dev/null

  case "$verdict" in
    go)
      case "$nn" in
        00) pm_set "$pm" stage 1 ;;
        01) pm_set "$pm" stage 2 ;;
        02) pm_set "$pm" stage 3 ;;
        B*) local f; f="$(pm_get "$pm" budget_factor)"; [[ -n "$f" ]] || f=1
            pm_set "$pm" budget_factor "$(python3 -c "print(float('$f')*2)")"; pm_log "$pm" "budget factor now $(pm_get "$pm" budget_factor)" ;;
        *)  : ;;   # spend/contact/final-build gates: same stage continues; the run reads the decision file
      esac
      pm_set "$pm" status running; pm_set "$pm" iteration 0; pm_set "$pm" gate '""' ;;
    accept)  pm_set "$pm" status done; pm_set "$pm" gate '""' ;;
    iterate) pm_set "$pm" status running; pm_set "$pm" gate '""' ;;
    send-back) pm_set "$pm" stage 4; pm_set "$pm" status running; pm_set "$pm" iteration 0; pm_set "$pm" gate '""' ;;
    park)    pm_set "$pm" status parked ;;
    no-go)   pm_set "$pm" status no-go ;;
    *) pm_log "$pm" "unknown verdict '$verdict' in gates/$nn.decision.md — waiting"; log "$id: unknown verdict '$verdict'"; return 0 ;;
  esac
  commit_idea "$id" "idea($id): gate $nn decided: $verdict"

  mark() {
    local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/idea-pipeline.XXXXXX")"
    awk -v id="$id" -v nn="$nn" -v v="$verdict" '
      $0 ~ "^\\| "id" \\| "nn" \\|" && $0 !~ /→ decided/ { sub(/\|[[:space:]]*$/, "→ decided " v " |") }
      { print }' "$ROOT/gates/INBOX.md" > "$tmp" && mv "$tmp" "$ROOT/gates/INBOX.md"
    git_root add gates/INBOX.md >/dev/null 2>&1 || true
    git_root commit -q -m "inbox: gate $nn for $id decided $verdict" -- gates/INBOX.md >/dev/null 2>&1 || true
  }
  with_lock inbox mark

  if [[ "$verdict" == "no-go" ]]; then
    git_root worktree remove --force "$(wt_dir "$id")" >/dev/null 2>&1 || true
    log "$id: no-go — worktree removed, branch $(idea_branch "$id") kept"
  fi
}

# ---------------------------------------------------------------------------
step() { # one step for one idea; returns 0 if more steps may follow, 1 if the idea is waiting/terminal
  local id="$1" pm status stage
  require_idea "$id"
  pm="$(idea_dir "$id")/progress.md"
  status="$(pm_get "$pm" status)"; stage="$(pm_get "$pm" stage)"
  case "$status" in
    done|parked|no-go|failed) log "$id: $status — nothing to do"; return 1 ;;
    awaiting-gate)
      if [[ -f "$(idea_dir "$id")/gates/$(pm_get "$pm" gate).decision.md" ]]; then apply_decision "$id"; return 0
      else handle_gate "$id"; log "$id: waiting for gates/$(pm_get "$pm" gate).decision.md"; return 1; fi ;;
    stage-complete)
      if [[ "$stage" -ge 5 ]]; then pm_set "$pm" status done; commit_idea "$id" "idea($id): done"; return 1; fi
      pm_set "$pm" stage $((stage+1)); pm_set "$pm" status running; pm_set "$pm" iteration 0
      pm_log "$pm" "run.sh advanced to stage $((stage+1))"; commit_idea "$id" "idea($id): advance to stage $((stage+1))"; return 0 ;;
    running) run_iteration "$id"; return 0 ;;
    *) log "$id: unknown status '$status'"; return 1 ;;
  esac
}

run_idea() { # run_idea <id> <loop 0|1>
  local id="$1" loop="$2" n=0
  if [[ "$loop" == "1" ]]; then
    while step "$id"; do n=$((n+1)); [[ $n -lt 50 ]] || { log "$id: 50 steps in one loop — stopping"; break; }; done
  else
    step "$id" || true
  fi
  [[ -d "$(idea_dir "$id")" ]] && status_line "$id" || log "$id: closed (no-go); branch $(idea_branch "$id") kept"
}

# ---------------------------------------------------------------------------
[[ $# -ge 1 ]] || usage
LOOP=0; ALL=0; STATUS=0; ID=""
for a in "$@"; do
  case "$a" in
    --loop) LOOP=1 ;; --all) ALL=1 ;; --status) STATUS=1 ;; -h|--help) usage ;;
    *) ID="$a" ;;
  esac
done
touch "$ROOT/gates/INBOX.md"
if [[ $STATUS -eq 1 ]]; then for id in $(list_ideas); do status_line "$id"; done; exit 0; fi
if [[ $ALL -eq 1 ]]; then for id in $(list_ideas); do run_idea "$id" "$LOOP"; done; exit 0; fi
[[ -n "$ID" ]] || usage
run_idea "$ID" "$LOOP"
