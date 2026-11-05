#!/usr/bin/env bash
# export.sh <id> <file> [<file>...]
# Copies files to "$DRIVE_DIR/Idea Pipeline/<id>/" and logs to ideas/<id>/exports/log.md.
# Prints the destination folder (or "EXPORT FAILED: reason") so callers can put it on the gate page.
# Phase 1 uses the local Drive sync folder; Phase 2 swaps this file for a Drive API call. Same interface.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

id="${1:?idea id}"; shift
dir="$(idea_dir "$id")"
mkdir -p "$dir/exports"
logf="$dir/exports/log.md"
[[ -f "$logf" ]] || printf '# Exports — %s\n\n| When | File | Destination |\n| --- | --- | --- |\n' "$id" > "$logf"

if [[ -z "$DRIVE_DIR" ]]; then
  for f in "$@"; do printf '| %s | %s | EXPORT FAILED: DRIVE_DIR unset |\n' "$(now)" "$(basename "$f")" >> "$logf"; done
  echo "EXPORT FAILED: DRIVE_DIR unset"; exit 0
fi
dest="$DRIVE_DIR/$DRIVE_SUBDIR/$id"
if ! mkdir -p "$dest" 2>/dev/null; then
  for f in "$@"; do printf '| %s | %s | EXPORT FAILED: cannot create %s |\n' "$(now)" "$(basename "$f")" "$dest" >> "$logf"; done
  echo "EXPORT FAILED: cannot create $dest"; exit 0
fi
for f in "$@"; do
  if cp "$f" "$dest/" 2>/dev/null; then
    printf '| %s | %s | %s |\n' "$(now)" "$(basename "$f")" "$dest/$(basename "$f")" >> "$logf"
  else
    printf '| %s | %s | EXPORT FAILED: copy error |\n' "$(now)" "$(basename "$f")" >> "$logf"
    echo "EXPORT FAILED: copy error for $f"; exit 0
  fi
done
echo "$dest"
