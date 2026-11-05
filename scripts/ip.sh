#!/usr/bin/env bash
# ip.sh — the Idea Pipeline control room, callable from any folder.
#
#   bash scripts/ip.sh <command> [args]        ·  bash scripts/ip.sh help
#
# Finds the pipeline through $IDEA_PIPELINE_DIR, then ~/.config/idea-pipeline/root, then the current
# folder's ancestors. Every pipeline script is started with the CLAUDECODE variables unset so the
# nested headless `claude -p` can start from inside a Claude Code session. Bash 3.2 compatible (macOS).
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$SKILL_DIR/template"
POINTER="${XDG_CONFIG_HOME:-$HOME/.config}/idea-pipeline/root"
VERDICTS="go iterate park no-go accept send-back"
ROOT=""

say()  { printf '%s\n' "$*"; }
ok()   { say "  OK    $*"; }
wrn()  { say "  WARN  $*"; }
warn() { printf 'ip: %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

usage() { cat <<'USAGE'
ip.sh — Idea Pipeline control room

Setup
  install [dir] [--from <git-url>] [--drive <path>] [--no-pointer]
                          create a pipeline (default ~/idea-pipeline) from the bundled template or a git repo
  use <dir>               point this skill at an existing pipeline
  root                    print the pipeline folder in use
  doctor                  prerequisites, .env, git identity, failed ideas, stuck locks, running jobs

Operate
  status                  one line per idea + the last run.log lines
  gates                   open gates waiting for a decision (prints nothing when none)
  show <id> <what>        print a file: gate | progress | idea | plan | panel | <path relative to the worktree>
  new <slug> [brief-file|-] [--title "T"] [--no-run]
                          create an idea and run triage (stage 0, Sonnet, ≈ USD 1–2); --no-run only creates it
  new --inbox             create ideas from briefs dropped in $DRIVE_DIR/Idea Pipeline/_inbox/
  decide <id> <NN> <verdict> [--answer "…"]... [--notes "…"] [--force]
                          write gates/NN.decision.md and apply it · verdicts: go iterate park no-go accept send-back
  run <id|--all> [--once] launch the loop in the background; it stops at the next gate
  step <id>               one foreground step (apply a decision, advance a stage); refuses paid iterations
  advance <id>            mark the current stage complete and move on (after a 'go' on a non-standard gate id)
  resume <id>             set a failed idea back to running and launch it
  jobs                    running headless jobs
  log [n]                 last n lines of run.log (default 20)
  backup                  git bundle → $DRIVE_DIR/Idea Pipeline/_backup/ (no model call)
  scout daily|weekly      condense learnings / research tool swaps (one cheap model call)
USAGE
}

# ---- locating the pipeline --------------------------------------------------------------------
is_pipeline() { [[ -n "${1:-}" && -f "$1/run.sh" && -f "$1/system/lib/common.sh" && -d "$1/playbooks" ]]; }

find_root() {
  if [[ -n "${IDEA_PIPELINE_DIR:-}" ]]; then
    is_pipeline "$IDEA_PIPELINE_DIR" && { printf '%s' "$IDEA_PIPELINE_DIR"; return 0; }
    die "IDEA_PIPELINE_DIR=$IDEA_PIPELINE_DIR is not an idea pipeline"
  fi
  if [[ -f "$POINTER" ]]; then
    local r; r="$(head -1 "$POINTER")"
    is_pipeline "$r" && { printf '%s' "$r"; return 0; }
    warn "pointer $POINTER → '$r' is not a pipeline (ignored)"
  fi
  local d="$PWD"
  while [[ "$d" != "/" ]]; do is_pipeline "$d" && { printf '%s' "$d"; return 0; }; d="$(dirname "$d")"; done
  return 1
}

need_root() {
  ROOT="$(find_root)" || {
    warn "no idea pipeline found."
    warn "install one:    bash \"$SKILL_DIR/scripts/ip.sh\" install [dir]"
    warn "or point here:  bash \"$SKILL_DIR/scripts/ip.sh\" use <dir>"
    exit 2
  }
}

set_pointer() {
  if mkdir -p "$(dirname "$POINTER")" 2>/dev/null && printf '%s\n' "$1" > "$POINTER" 2>/dev/null; then
    say "remembered: $POINTER → $1"
  else
    warn "could not write $POINTER (sandboxed?). Use the env var instead:  export IDEA_PIPELINE_DIR=\"$1\""
  fi
}

# ---- helpers ----------------------------------------------------------------------------------
pipe() { ( cd "$ROOT" && env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT "$ROOT/$1" "${@:2}" ); }

list_ideas() {
  [[ -d "$ROOT/.worktrees" ]] || return 0
  find "$ROOT/.worktrees" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}
wt_of()  { printf '%s/.worktrees/%s' "$ROOT" "$1"; }
dir_of() { printf '%s/.worktrees/%s/ideas/%s' "$ROOT" "$1" "$1"; }
pm_of()  { printf '%s/progress.md' "$(dir_of "$1")"; }

pm() { # pm <id> <key> — read a progress.md front-matter value
  local f; f="$(pm_of "$1")"
  [[ -f "$f" ]] || die "no such idea: $1  (bash scripts/ip.sh status lists them)"
  awk -v k="$2" '/^---[[:space:]]*$/ { fm++; next } fm==1 && $0 ~ "^"k":" { sub("^"k":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }' "$f"
}
set_pm() { # set_pm <id> <key> <value> [log line]
  ( source "$ROOT/system/lib/common.sh"; pm_set "$(pm_of "$1")" "$2" "$3"; [[ -n "${4:-}" ]] && pm_log "$(pm_of "$1")" "$4" || true )
}

PIDDIR() { printf '%s/.run-pids' "$ROOT"; }
job_alive() { # job_alive <id|all> → prints the pid and returns 0 when a run.sh launched by ip.sh is still alive
  local f pid; f="$(PIDDIR)/$1.pid"
  [[ -f "$f" ]] || return 1
  pid="$(cat "$f")"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then printf '%s' "$pid"; return 0; fi
  rm -f "$f"; return 1
}
claude_running_for() { # fallback for jobs started outside ip.sh; silent where pgrep is blocked
  pgrep -f "Idea Pipeline iteration\. Idea: $1\." >/dev/null 2>&1
}
guard_job() {
  local pid
  if pid="$(job_alive "$1")"; then die "a job is running for $1 (run.sh pid $pid) — wait for it: bash scripts/ip.sh jobs"; fi
  if pid="$(job_alive all)"; then die "a --all job is running (pid $pid) — wait for it"; fi
  if claude_running_for "$1"; then die "a headless iteration for $1 is running (started outside ip.sh) — wait for it"; fi
}

# ---- commands: setup ----------------------------------------------------------------------------
cmd_install() {
  local dir="$HOME/idea-pipeline" from="" drive="" pointer=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from="$2"; shift 2 ;;
      --drive) drive="$2"; shift 2 ;;
      --no-pointer) pointer=0; shift ;;
      -*) die "unknown option $1" ;;
      *) dir="$1"; shift ;;
    esac
  done
  dir="${dir/#\~/$HOME}"
  if is_pipeline "$dir"; then
    say "already a pipeline: $dir"
    [[ $pointer -eq 1 ]] && set_pointer "$dir"
    IDEA_PIPELINE_DIR="$dir" cmd_doctor; return 0
  fi
  if [[ -e "$dir" && -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
    die "$dir exists and is not empty — choose another folder, or 'use' it if it is a pipeline"
  fi
  if [[ -n "$from" ]]; then
    git clone -q "$from" "$dir" || die "git clone failed: $from"
  else
    [[ -d "$TEMPLATE/system" ]] || die "no template at $TEMPLATE"
    mkdir -p "$dir"
    cp -R "$TEMPLATE/." "$dir/"
  fi
  (
    cd "$dir"
    # .claude/ = slash commands + open-gate hook for sessions started inside the pipeline folder
    if [[ -d setup/dot-claude ]]; then
      mkdir -p .claude
      cp -R setup/dot-claude/. .claude/ 2>/dev/null || warn "could not write .claude/ (sandboxed?) — later: cd \"$dir\" && bash setup.sh"
    fi
    chmod +x ./*.sh system/lib/*.sh tests/*.sh setup/dot-claude/hooks/*.sh .claude/hooks/*.sh 2>/dev/null || true
    [[ -f .env ]] || cp .env.example .env
    if [[ -n "$drive" ]]; then
      drive="${drive/#\~/$HOME}"
      awk -v v="$drive" '/^DRIVE_DIR=/ { print "DRIVE_DIR=\"" v "\""; done=1; next } { print } END { if (!done) print "DRIVE_DIR=\"" v "\"" }' .env > .env.tmp && mv .env.tmp .env
    fi
    local ver; ver="$(sed -n 's/^source_commit: //p' .template-version 2>/dev/null || true)"
    printf '\n## %s — installed\n- Created from the idea-pipeline skill template%s. No ideas run yet.\n' "$(date +%F)" "${ver:+ (source commit $ver)}" >> learnings/full.md
    if [[ ! -d .git ]]; then
      git init -q -b main 2>/dev/null || { git init -q; git symbolic-ref HEAD refs/heads/main; }
    fi
    if [[ -z "$(git config user.email 2>/dev/null || true)" ]]; then
      git config user.name "Idea Pipeline"; git config user.email "idea-pipeline@localhost"
      warn "no git identity on this machine — set a repo-local one (change with: git config user.name / user.email)"
    fi
    git add -A >/dev/null
    git commit -q -m "idea-pipeline: installed from the idea-pipeline skill template" >/dev/null 2>&1 || true
  )
  say "installed: $dir"
  [[ $pointer -eq 1 ]] && set_pointer "$dir"
  say ""
  IDEA_PIPELINE_DIR="$dir" cmd_doctor
  say ""
  say "next:  fill DRIVE_DIR in $dir/.env if you want gate pages and backups on Google Drive (optional)"
  say "       bash scripts/ip.sh new <slug> <brief-file>     — first idea (triage ≈ USD 1–2)"
}

cmd_use() {
  local dir="${1:?usage: use <dir>}"; dir="${dir/#\~/$HOME}"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || die "no such folder: $1"
  is_pipeline "$dir" || die "$dir is not an idea pipeline (needs run.sh, system/lib/common.sh, playbooks/)"
  set_pointer "$dir"
}

cmd_root() { need_root; say "$ROOT"; }

cmd_doctor() {
  need_root
  say "pipeline: $ROOT"
  [[ -f "$ROOT/.env" ]] && ok ".env present" || wrn ".env missing — cp .env.example .env"
  local cbin ddir
  cbin="$( (source "$ROOT/system/lib/common.sh"; printf '%s' "$CLAUDE_BIN") 2>/dev/null || echo claude)"
  ddir="$( (source "$ROOT/system/lib/common.sh"; printf '%s' "$DRIVE_DIR") 2>/dev/null || true)"
  local t; for t in git python3; do command -v "$t" >/dev/null 2>&1 && ok "$t on PATH" || wrn "$t not on PATH"; done
  if command -v "$cbin" >/dev/null 2>&1 || [[ -x "$cbin" ]]; then
    ok "claude: $cbin $("$cbin" --version 2>/dev/null | head -1)"
  else
    wrn "claude not found ('$cbin') — install Claude Code or set CLAUDE_BIN in .env; the pipeline cannot run without it"
  fi
  if [[ -z "$ddir" ]]; then wrn "DRIVE_DIR unset — gate pages stay in the repo; Drive exports, inbox and backups are off (optional)"
  elif [[ -d "$ddir" ]]; then ok "DRIVE_DIR → $ddir"
  else wrn "DRIVE_DIR does not exist: $ddir"; fi
  [[ -n "$(git -C "$ROOT" config user.email 2>/dev/null || true)" ]] && ok "git identity set" || wrn "git identity missing — commits fail silently: git config user.name / user.email"
  if [[ -d "$ROOT/.claude/commands" && -n "$(ls -A "$ROOT/.claude/commands" 2>/dev/null)" ]]; then ok ".claude/ slash commands installed (sessions started inside the pipeline)"
  else wrn ".claude/ slash commands missing — optional; this skill works without them (cd into the pipeline && bash setup.sh)"; fi
  command -v caffeinate >/dev/null 2>&1 && ok "caffeinate present — jobs keep the Mac awake while they run" || say "  INFO  no caffeinate (not macOS) — fine"
  local n=0 failed="" id
  for id in $(list_ideas); do n=$((n+1)); [[ "$(pm "$id" status)" == "failed" ]] && failed="$failed $id"; done
  say "  INFO  $n idea(s)"
  [[ -n "$failed" ]] && wrn "failed:$failed — read the last log lines (show <id> progress), fix the cause, then: resume <id>"
  local locks; locks="$(ls -d "$ROOT"/.run-lock-* 2>/dev/null || true)"
  [[ -n "$locks" ]] && wrn "lock folder(s) present — stuck if no job is running: $locks"
  cmd_jobs
}

# ---- commands: operate --------------------------------------------------------------------------
cmd_status() {
  need_root
  if [[ -z "$(list_ideas)" ]]; then
    say "no ideas yet — create one:  bash scripts/ip.sh new <slug> <brief-file>"
  else
    pipe run.sh --status 2>&1 || true
  fi
  if [[ -f "$ROOT/run.log" ]]; then say ""; say "run.log (last 5):"; tail -n 5 "$ROOT/run.log" | sed 's/^/  /'; fi
}

cmd_gates() {
  need_root
  local inbox="$ROOT/gates/INBOX.md"; [[ -f "$inbox" ]] || return 0
  local open; open="$(grep -E '^\| [0-9]{4}-' "$inbox" | grep -v '→ decided' || true)"
  [[ -n "$open" ]] || return 0
  say "| Idea | Gate | When | Page | Drive |"
  say "$open"
  say ""
  say "page:  bash scripts/ip.sh show <id> gate    decide:  bash scripts/ip.sh decide <id> <NN> <verdict> --answer \"…\" --notes \"…\""
}

cmd_show() {
  need_root
  local id="${1:?usage: show <id> <gate|progress|idea|plan|panel|path>}" what="${2:-gate}" wt p nn
  wt="$(wt_of "$id")"; [[ -d "$wt" ]] || die "no such idea: $id"
  case "$what" in
    gate)      nn="$(pm "$id" gate)"; [[ -n "$nn" ]] || die "$id has no open gate (status: $(pm "$id" status))"; p="ideas/$id/gates/$nn.md" ;;
    progress)  p="ideas/$id/progress.md" ;;
    idea|brief) p="ideas/$id/IDEA.md" ;;
    plan)      p="ideas/$id/plan.md" ;;
    panel)     p="ideas/$id/panel.md" ;;
    *)         p="$what" ;;
  esac
  [[ -f "$wt/$p" ]] || die "no file $p for $id"
  say "--- $id / $p ---"
  cat "$wt/$p"
}

cmd_new() {
  need_root
  local slug="" src="" title="" norun=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --inbox) pipe new-idea.sh --inbox; return 0 ;;
      --title) title="$2"; shift 2 ;;
      --no-run) norun=1; shift ;;
      -) src="-"; shift ;;
      -*) die "unknown option $1" ;;
      *) if [[ -z "$slug" ]]; then slug="$1"; else src="$1"; fi; shift ;;
    esac
  done
  [[ -n "$slug" ]] || die "usage: new <slug> [brief-file|-] [--title \"T\"] [--no-run]"
  [[ -n "$title" ]] || title="$(printf '%s' "$slug" | tr '-' ' ' | awk '{ for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2) } 1')"
  [[ -n "$src" ]] || warn "paste the brief, end with Ctrl-D"
  if [[ $norun -eq 1 ]]; then
    pipe new-idea.sh --no-run --title "$title" "$slug" ${src:+"$src"}
  else
    say "creating $slug and running triage (stage 0, foreground, usually 1–3 min) …"
    pipe new-idea.sh --title "$title" "$slug" ${src:+"$src"}
  fi
}

cmd_decide() {
  need_root
  local id="${1:?usage: decide <id> <NN> <verdict> [--answer …]... [--notes …]}" nn="${2:?gate id NN}" verdict="${3:?verdict}"
  shift 3
  local answers=() notes="" force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --answer) answers+=("$2"); shift 2 ;;
      --notes) notes="$2"; shift 2 ;;
      --force) force=1; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  verdict="$(printf '%s' "$verdict" | tr '[:upper:]' '[:lower:]')"
  [[ " $VERDICTS " == *" $verdict "* ]] || die "verdict '$verdict' — must be one of: $VERDICTS"
  local dir; dir="$(dir_of "$id")"; [[ -d "$dir" ]] || die "no such idea: $id"
  local cur st; cur="$(pm "$id" gate)"; st="$(pm "$id" status)"
  if [[ $force -eq 0 ]]; then
    [[ "$st" == "awaiting-gate" ]] || die "$id is not waiting for a decision (status: $st)"
    [[ "$cur" == "$nn" ]] || die "$id is waiting on gate '$cur', not '$nn'"
    [[ ! -f "$dir/gates/$nn.decision.md" ]] || die "a decision for gate $nn exists already (--force overwrites)"
  fi
  guard_job "$id"
  {
    printf 'verdict: %s\nby: B\ndate: %s\ngate: %s\n\n# Answers to calibration questions\n\n' "$verdict" "$(date +%F)" "$nn"
    if [[ ${#answers[@]} -gt 0 ]]; then
      local i=1 a; for a in ${answers[@]+"${answers[@]}"}; do printf '%d. %s\n' "$i" "$a"; i=$((i+1)); done
    else
      printf '1. \n2. \n'
    fi
    printf '\n# Notes for the next iteration (optional)\n\n%s\n' "$notes"
  } > "$dir/gates/$nn.decision.md"
  say "wrote ideas/$id/gates/$nn.decision.md (verdict: $verdict) — applying …"
  pipe run.sh "$id" 2>&1 | sed 's/^/  /'
  say ""
  case "$verdict" in
    go|iterate|send-back) say "continue:  bash scripts/ip.sh run $id" ;;
    *) say "$id is now $(pm "$id" status)." ;;
  esac
}

cmd_step() {
  need_root
  local id="${1:?usage: step <id>}" st
  st="$(pm "$id" status)"
  guard_job "$id"
  if [[ "$st" == "running" && "${2:-}" != "--iterate" ]]; then
    die "$id is 'running' — a step now would run a paid model iteration in the foreground. Use:  bash scripts/ip.sh run $id   (background). To insist: step $id --iterate"
  fi
  pipe run.sh "$id" 2>&1 | sed 's/^/  /'
}

cmd_run() {
  need_root
  local target="${1:?usage: run <id|--all> [--once]}" once=0 pid
  [[ "${2:-}" == "--once" ]] && once=1
  mkdir -p "$(PIDDIR)"
  if [[ "$target" == "--all" ]]; then
    if pid="$(job_alive all)"; then die "a --all job is already running (pid $pid)"; fi
  else
    local st nn; st="$(pm "$target" status)"
    case "$st" in
      done|parked|no-go) die "$target is $st — nothing to run" ;;
      failed) die "$target is failed — read:  bash scripts/ip.sh show $target progress   · fix the cause, then:  bash scripts/ip.sh resume $target" ;;
      awaiting-gate)
        nn="$(pm "$target" gate)"
        [[ -f "$(dir_of "$target")/gates/$nn.decision.md" ]] || die "$target waits for gate $nn — decide first:  bash scripts/ip.sh decide $target $nn <verdict> …" ;;
    esac
    guard_job "$target"
  fi
  local pidf flags=""
  pidf="$(PIDDIR)/${target#--}.pid"
  [[ $once -eq 1 ]] || flags="--loop"
  ( cd "$ROOT" && env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT nohup "$ROOT/run.sh" "$target" $flags >> "$ROOT/run.log" 2>&1 & echo $! > "$pidf" )
  say "launched: run.sh $target $flags (pid $(cat "$pidf")) → $ROOT/run.log"
  say "it stops on its own at the next gate.  watch:  bash scripts/ip.sh log   ·   bash scripts/ip.sh status   ·   bash scripts/ip.sh jobs"
}

cmd_advance() {
  need_root
  local id="${1:?usage: advance <id>}" st; st="$(pm "$id" status)"
  guard_job "$id"
  [[ "$st" == "running" ]] || die "advance needs status 'running' (now: $st). It is for a 'go' on a non-standard gate id that left the idea in the same stage."
  set_pm "$id" status stage-complete "operator: stage $(pm "$id" stage) marked complete by ip.sh advance"
  pipe run.sh "$id" 2>&1 | sed 's/^/  /'
}

cmd_resume() {
  need_root
  local id="${1:?usage: resume <id>}" st; st="$(pm "$id" status)"
  [[ "$st" == "failed" ]] || die "resume is for failed ideas (status now: $st)"
  guard_job "$id"
  set_pm "$id" status running "operator: status failed → running by ip.sh resume"
  cmd_run "$id"
}

cmd_jobs() {
  need_root
  local found=0 f pid id pg
  if [[ -d "$(PIDDIR)" ]]; then
    for f in "$(PIDDIR)"/*.pid; do
      [[ -f "$f" ]] || continue
      id="$(basename "${f%.pid}")"; pid="$(cat "$f")"
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        say "  RUNNING  $id  (run.sh pid $pid, launched $(date -r "$f" '+%Y-%m-%d %H:%M'))"; found=1
      else
        rm -f "$f"
      fi
    done
  fi
  pg="$(pgrep -fl 'Idea Pipeline iteration\. Idea: ' 2>/dev/null || true)"
  if [[ -n "$pg" ]]; then
    printf '%s\n' "$pg" | sed -E 's/.*Idea: ([^.]+)\. Stage: ([0-9]+).*/  CLAUDE   \1  (headless iteration, stage \2)/' | sort -u; found=1
  fi
  [[ $found -eq 1 ]] || say "  no jobs running"
}

cmd_log()    { need_root; [[ -f "$ROOT/run.log" ]] && tail -n "${1:-20}" "$ROOT/run.log" || say "no run.log yet"; }
cmd_backup() { need_root; pipe backup.sh; }
cmd_scout()  { need_root; local m="${1:?usage: scout daily|weekly}"; [[ "$m" == daily || "$m" == weekly ]] || die "scout daily|weekly"; pipe scout.sh "$m"; }

# ---- dispatch -----------------------------------------------------------------------------------
cmd="${1:-help}"; [[ $# -gt 0 ]] && shift
case "$cmd" in
  install) cmd_install "$@" ;;   use) cmd_use "$@" ;;   root) cmd_root ;;   doctor) cmd_doctor ;;
  status|ideas) cmd_status ;;    gates) cmd_gates ;;    show) cmd_show "$@" ;;   new) cmd_new "$@" ;;
  decide) cmd_decide "$@" ;;     run) cmd_run "$@" ;;   step) cmd_step "$@" ;;   advance) cmd_advance "$@" ;;
  resume) cmd_resume "$@" ;;     jobs) cmd_jobs ;;      log) cmd_log "$@" ;;     backup) cmd_backup ;;
  scout) cmd_scout "$@" ;;       help|-h|--help) usage ;;
  *) warn "unknown command: $cmd"; usage; exit 1 ;;
esac
