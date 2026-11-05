#!/usr/bin/env bash
# UserPromptSubmit hook for the control-room session.
# Prints the open gates (INBOX lines without "→ decided") so they land in context whenever B types anything.
# Prints nothing when there is nothing open, so idle chat costs nothing.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
inbox="$ROOT/gates/INBOX.md"
[[ -f "$inbox" ]] || exit 0
open="$(grep -E '^\| [0-9]{4}-' "$inbox" | grep -v '→ decided' || true)"
[[ -n "$open" ]] || exit 0
n="$(printf '%s\n' "$open" | wc -l | tr -d ' ')"
cat <<EOF
[Idea Pipeline] $n open gate(s) waiting for B. For each: read the page at the path given, present it in full (it is one page), then ask B for a verdict with AskUserQuestion and write gates/NN.decision.md from system/templates/decision.md into the idea's worktree folder (.worktrees/<id>/ideas/<id>/gates/). Do not score or judge the idea yourself.
| Idea | Gate | When | Page | Drive |
$open
Paths are relative to the worktree: .worktrees/<id>/<page path>.
EOF
