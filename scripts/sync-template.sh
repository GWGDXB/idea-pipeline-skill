#!/usr/bin/env bash
# sync-template.sh — maintainer tool. Refreshes template/ from a live Idea Pipeline repo.
#
#   bash scripts/sync-template.sh <path-to-idea-pipeline-repo> [git-ref]      (default ref: main)
#
# Exports the committed tree of <ref> (so .env, .worktrees/, logs and anything uncommitted never
# leave the source machine), then resets the owner-specific state so the template is a clean start:
#   gates/INBOX.md       → header only (no gate lines, no Drive paths)
#   learnings/full.md    → header only (run observations belong to the owner, not the template)
#   learnings/executive.md → keeps [design] rules, drops [run <id>] lines
#   tests/briefs, tests/probe-01.sh → company name in the sample briefs generalised
#   .env.example         → home-relative example path
#   README.md            → one line explaining that "B" means the pipeline's owner
#   *.sh                 → bare mktemp calls get an explicit TMPDIR template (sandbox-safe)
#   .claude/             → not shipped; the installer copies setup/dot-claude/ → .claude/ (same content)
# Writes template/.template-version with the source commit and date.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$SKILL_DIR/template"
SRC="${1:?usage: sync-template.sh <idea-pipeline-repo> [ref]}"
REF="${2:-main}"

[[ -d "$SRC/.git" || -f "$SRC/.git" ]] || { echo "not a git repo: $SRC" >&2; exit 1; }
[[ -f "$SRC/run.sh" && -f "$SRC/system/lib/common.sh" ]] || { echo "not an idea-pipeline repo: $SRC" >&2; exit 1; }
commit="$(git -C "$SRC" rev-parse --short "$REF")"

rm -rf "$TEMPLATE"; mkdir -p "$TEMPLATE"
# The top-level .claude/ is NOT shipped: the pipeline re-creates it from setup/dot-claude/ at install time
# (and some sandboxes refuse to write */.claude/commands/* anywhere but the project they run in).
git -C "$SRC" archive "$REF" | tar -x -C "$TEMPLATE" --exclude '.claude' --exclude '.claude/*'

# --- resets -------------------------------------------------------------------------------------
# INBOX: keep everything up to and including the table separator line.
awk '{ print } /^\| --- /{ exit }' "$TEMPLATE/gates/INBOX.md" > "$TEMPLATE/gates/INBOX.md.tmp" && mv "$TEMPLATE/gates/INBOX.md.tmp" "$TEMPLATE/gates/INBOX.md"

# learnings/full.md: keep the header (everything before the first "## " entry).
awk '/^## /{ exit } { print }' "$TEMPLATE/learnings/full.md" > "$TEMPLATE/learnings/full.md.tmp" && mv "$TEMPLATE/learnings/full.md.tmp" "$TEMPLATE/learnings/full.md"

# learnings/executive.md: drop lines learned from the owner's own runs.
grep -v -E '^\- \[run ' "$TEMPLATE/learnings/executive.md" > "$TEMPLATE/learnings/executive.md.tmp" && mv "$TEMPLATE/learnings/executive.md.tmp" "$TEMPLATE/learnings/executive.md"

# Sample briefs: the owner's company name → neutral wording.
sed -i.bak 's/my Glaswerk mailbox/my company mailbox/' "$TEMPLATE/tests/briefs/01-build-invoice-bot.md"
sed -i.bak 's/Should Glaswerk register/Should my company register/' "$TEMPLATE/tests/probe-01.sh"
sed -i.bak 's#/Users/home/Library/CloudStorage#~/Library/CloudStorage#' "$TEMPLATE/.env.example"
find "$TEMPLATE" -name '*.bak' -delete

# README: say what "B" is, right under the title.
awk 'NR==1 { print; print ""; print "> **Who is B?** Every file in this repo calls the pipeline'"'"'s owner \"B\": the one human who answers the gates. If you installed this, B is you."; next } { print }' \
  "$TEMPLATE/README.md" > "$TEMPLATE/README.md.tmp" && mv "$TEMPLATE/README.md.tmp" "$TEMPLATE/README.md"

# mktemp: macOS's bare `mktemp` ignores TMPDIR and writes to /var/folders, which sandboxes refuse.
# Give every call an explicit template under TMPDIR (same behaviour everywhere else).
for f in "$TEMPLATE"/*.sh "$TEMPLATE"/system/lib/*.sh "$TEMPLATE"/tests/*.sh; do
  sed -i.bak 's|\$(mktemp)|$(mktemp "${TMPDIR:-/tmp}/idea-pipeline.XXXXXX")|g' "$f"
done
find "$TEMPLATE" -name '*.bak' -delete

# Scripts executable (git archive keeps modes, but be explicit for packagers that strip them).
chmod +x "$TEMPLATE"/*.sh "$TEMPLATE"/system/lib/*.sh "$TEMPLATE"/tests/*.sh "$TEMPLATE"/setup/dot-claude/hooks/*.sh 2>/dev/null || true

printf 'source_commit: %s\nsource_ref: %s\nsynced: %s\n' "$commit" "$REF" "$(date '+%Y-%m-%d')" > "$TEMPLATE/.template-version"

# --- leak check ---------------------------------------------------------------------------------
leaks="$(grep -r -n -i -E '@gmail|/Users/[a-z]+/|glaswerk|bjoernlauen' "$TEMPLATE" --exclude=BUILD.md || true)"
if [[ -n "$leaks" ]]; then echo "WARNING: owner-specific strings left in the template:" >&2; echo "$leaks" >&2; fi

echo "template synced from $SRC @ $commit ($(find "$TEMPLATE" -type f | wc -l | tr -d ' ') files)"
