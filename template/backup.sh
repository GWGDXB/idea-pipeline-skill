#!/usr/bin/env bash
# backup.sh — daily git bundle of the whole repo (all branches) to "$DRIVE_DIR/Idea Pipeline/_backup/".
# Restore from Drive alone:  git clone idea-pipeline-<date>.bundle idea-pipeline
# Keeps the last 14 bundles.
source "$(dirname "${BASH_SOURCE[0]}")/system/lib/common.sh"
[[ -n "$DRIVE_DIR" ]] || die "DRIVE_DIR unset in .env"
dest="$DRIVE_DIR/$DRIVE_SUBDIR/_backup"; mkdir -p "$dest"
out="$dest/idea-pipeline-$(today).bundle"
git_root bundle create "$out" --all >/dev/null
git_root bundle verify "$out" >/dev/null && log "bundle ok: $out ($(du -h "$out" | cut -f1))"
ls -1t "$dest"/idea-pipeline-*.bundle 2>/dev/null | tail -n +15 | while read -r old; do rm -f "$old"; done
