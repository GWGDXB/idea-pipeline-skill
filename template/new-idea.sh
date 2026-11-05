#!/usr/bin/env bash
# new-idea.sh "<slug>" [brief-file | -]        (- reads the brief from stdin)
# new-idea.sh --title "<Title>" "<slug>" [brief-file | -]
#
# Creates branch idea/<yyyy-mm-dd>-<slug>, a worktree in .worktrees/<id>, and ideas/<id>/ from templates,
# commits, then runs the triage iteration (stage 0) unless --no-run is given.
# Brief files may also be dropped into "$DRIVE_DIR/Idea Pipeline/_inbox/" and picked up with: new-idea.sh --inbox

source "$(dirname "${BASH_SOURCE[0]}")/system/lib/common.sh"

usage() { sed -n '2,7p' "$0"; exit 1; }

TITLE=""; RUN=1; INBOX=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --no-run) RUN=0; shift ;;
    --inbox) INBOX=1; shift ;;
    -h|--help) usage ;;
    *) break ;;
  esac
done

create_idea() { # create_idea <slug> <brief-text> [title]
  local slug="$1" brief="$2" title="${3:-}"
  slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  [[ -n "$slug" ]] || die "empty slug"
  local id="$(today)-$slug"
  [[ -n "$title" ]] || title="$(printf '%s' "$slug" | sed -E 's/-/ /g; s/\b(.)/\u\1/g')"
  local branch wt dir
  branch="$(idea_branch "$id")"; wt="$(wt_dir "$id")"; dir="$wt/ideas/$id"

  [[ -e "$wt" ]] && die "idea already exists: $id"
  git_root rev-parse --verify -q "$branch" >/dev/null && die "branch exists: $branch"

  mkdir -p "$ROOT/.worktrees"
  git_root worktree add -q -b "$branch" "$wt" HEAD
  mkdir -p "$dir/scores" "$dir/gates" "$dir/exports" "$dir/panel"

  # Fill templates. Brief inserted via awk to survive any characters.
  awk -v id="$id" -v title="$title" -v date="$(today)" '
    { gsub(/\{\{ID\}\}/, id); gsub(/\{\{TITLE\}\}/, title); gsub(/\{\{DATE\}\}/, date); print }
  ' "$ROOT/system/templates/progress.md" > "$dir/progress.md"

  local brieffile; brieffile="$(mktemp "${TMPDIR:-/tmp}/idea-pipeline.XXXXXX")"
  printf '%s\n' "$brief" > "$brieffile"
  awk -v title="$title" -v date="$(today)" -v brieffile="$brieffile" '
    /\{\{BRIEF\}\}/ { while ((getline line < brieffile) > 0) print line; next }
    { gsub(/\{\{TITLE\}\}/, title); gsub(/\{\{DATE\}\}/, date); print }
  ' "$ROOT/system/templates/brief.md" > "$dir/IDEA.md"
  rm -f "$brieffile"

  pm_log "$dir/progress.md" "created from brief ($(printf '%s' "$brief" | wc -w | tr -d ' ') words); branch $branch"
  commit_idea "$id" "idea($id): create from brief"
  log "created $id on $branch → $dir"
  echo "$id"
}

if [[ $INBOX -eq 1 ]]; then
  [[ -n "$DRIVE_DIR" ]] || die "DRIVE_DIR unset"
  inbox="$DRIVE_DIR/$DRIVE_SUBDIR/_inbox"; done_dir="$inbox/_processed"
  mkdir -p "$done_dir"
  shopt -s nullglob
  for f in "$inbox"/*.md "$inbox"/*.txt; do
    slug="$(basename "${f%.*}")"
    id="$(create_idea "$slug" "$(cat "$f")")"
    mv "$f" "$done_dir/$(today)-$(basename "$f")"
    if [[ $RUN -eq 1 ]]; then "$ROOT/run.sh" "$id" || true; fi
  done
  exit 0
fi

[[ $# -ge 1 ]] || usage
slug="$1"; src="${2:-}"
if [[ -z "$src" ]]; then
  log "paste the brief, end with Ctrl-D:"; brief="$(cat)"
elif [[ "$src" == "-" ]]; then
  brief="$(cat)"
else
  [[ -f "$src" ]] || die "brief file not found: $src"
  brief="$(cat "$src")"
fi
[[ -n "${brief// /}" ]] || die "empty brief"

id="$(create_idea "$slug" "$brief" "$TITLE")"
if [[ $RUN -eq 1 ]]; then exec "$ROOT/run.sh" "$id"; fi
echo "$id"
exit 0
