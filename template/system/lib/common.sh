#!/usr/bin/env bash
# Shared helpers for run.sh, new-idea.sh, scout.sh, backup.sh. Source, don't execute.
# Everything is relative to ROOT (the repo). No Mac-specific paths.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT

# ---- env -------------------------------------------------------------------
if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT/.env"; set +a
fi
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
DEFAULT_MAX_BUDGET_USD="${DEFAULT_MAX_BUDGET_USD:-5}"
DEFAULT_MAX_TURNS="${DEFAULT_MAX_TURNS:-40}"
TRIAGE_BUDGET_GATE_USD="${TRIAGE_BUDGET_GATE_USD:-10}"
DRIVE_DIR="${DRIVE_DIR:-}"
DRIVE_SUBDIR="Idea Pipeline"

log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }
today(){ date '+%Y-%m-%d'; }
now()  { date '+%Y-%m-%d %H:%M'; }

# ---- idea paths ------------------------------------------------------------
# An idea <id> lives on branch idea/<id>, checked out as a worktree in .worktrees/<id>.
# Its folder inside that worktree is ideas/<id>/. Scripts always address the worktree copy.
wt_dir()    { printf '%s/.worktrees/%s' "$ROOT" "$1"; }
idea_dir()  { printf '%s/ideas/%s' "$(wt_dir "$1")" "$1"; }
idea_branch(){ printf 'idea/%s' "$1"; }

require_idea() {
  local id="$1"
  [[ -d "$(idea_dir "$id")" ]] || die "no such idea worktree: $id (run new-idea.sh first)"
}

list_ideas() {
  [[ -d "$ROOT/.worktrees" ]] || return 0
  find "$ROOT/.worktrees" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

# ---- progress.md front matter ---------------------------------------------
# Front matter is simple "key: value" lines between the first two '---' lines.
pm_get() { # pm_get <progress.md> <key>
  awk -v k="$2" '
    /^---[[:space:]]*$/ { fm++; next }
    fm==1 && $0 ~ "^"k":" { sub("^"k":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }
  ' "$1"
}
pm_set() { # pm_set <progress.md> <key> <value>
  local f="$1" k="$2" v="$3" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/idea-pipeline.XXXXXX")"
  awk -v k="$k" -v v="$v" '
    /^---[[:space:]]*$/ { fm++; print; next }
    fm==1 && $0 ~ "^"k":" { print k": "v; done=1; next }
    fm==2 && !done && !printed { printed=1 }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
  # key missing → insert before closing ---
  if ! grep -q "^$k:" "$f"; then
    awk -v k="$k" -v v="$v" '/^---[[:space:]]*$/ { fm++; if (fm==2) print k": "v } { print }' "$f" > "$tmp" && mv "$tmp" "$f"
  fi
}
pm_log() { # pm_log <progress.md> <text>  — appends a dated line under "## Log"
  printf -- '- %s — %s\n' "$(now)" "$2" >> "$1"
}

# ---- tools/current.md machine block ---------------------------------------
# Lines in tools/current.md of the form:  stage1: model=opus turns=40 budget=8 tools=Read,Write,...
cfg_line() { grep -m1 -E "^$1:" "$ROOT/tools/current.md" || true; }
cfg_get()  { # cfg_get <section> <key> [default]
  local line v
  line="$(cfg_line "$1")"
  v="$(printf '%s' "$line" | tr ' ' '\n' | grep -m1 -E "^$2=" | cut -d= -f2- || true)"
  printf '%s' "${v:-${3:-}}"
}

# ---- playbook section extraction (technique 4) -----------------------------
# Writes the "## Stage N ..." section of a playbook to a file. Also includes "## Always" if present.
extract_stage() { # extract_stage <playbook.md> <stage-number> <out-file>
  awk -v s="$2" '
    /^## / { on = ($0 ~ "^## Stage "s"([^0-9]|$)") || ($0 ~ /^## Always/) }
    on { print }
  ' "$1" > "$3"
  [[ -s "$3" ]] || die "playbook $1 has no section for stage $2"
}

# ---- locking for shared files (INBOX, main branch) -------------------------
with_lock() { # with_lock <name> <command...>
  local lock="$ROOT/.run-lock-$1" i=0
  until mkdir "$lock" 2>/dev/null; do
    i=$((i+1)); [[ $i -lt 600 ]] || die "lock $1 held too long"
    sleep 0.5
  done
  trap 'rmdir "'"$lock"'" 2>/dev/null || true' RETURN
  "${@:2}"
  rmdir "$lock" 2>/dev/null || true
}

# ---- git helpers -----------------------------------------------------------
git_root() { git -C "$ROOT" "$@"; }
git_wt()   { git -C "$(wt_dir "$1")" "${@:2}"; }

commit_idea() { # commit_idea <id> <message>  — commits only the idea folder in its worktree
  local id="$1" msg="$2"
  git_wt "$id" add -A -- "ideas/$id" >/dev/null
  if ! git_wt "$id" diff --cached --quiet; then
    git_wt "$id" commit -q -m "$msg" || true
  fi
}

revert_outside_idea() { # enforce ground rule 6: anything changed outside ideas/<id>/ is reverted
  local id="$1" wt; wt="$(wt_dir "$id")"
  local bad
  bad="$(git -C "$wt" status --porcelain | awk '{print $2}' | grep -v -E "^ideas/$id/" || true)"
  if [[ -n "$bad" ]]; then
    log "RULE 6 VIOLATION in $id — reverting: $(echo "$bad" | tr '\n' ' ')"
    echo "$bad" | while read -r p; do
      [[ -z "$p" ]] && continue
      git -C "$wt" checkout -q -- "$p" 2>/dev/null || rm -rf "$wt/$p"
    done
    pm_log "$(idea_dir "$id")/progress.md" "run.sh reverted writes outside the idea folder: $(echo "$bad" | tr '\n' ' ')"
  fi
}

# ---- caffeinate (Mac only, harmless elsewhere) ------------------------------
keep_awake() { if command -v caffeinate >/dev/null 2>&1; then caffeinate -i "$@"; else "$@"; fi; }
