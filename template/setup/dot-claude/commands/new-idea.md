---
description: Create a new idea from a slug and a brief, run triage
allowed-tools: Bash(./new-idea.sh:*), Bash(./run.sh:*), Read
---

You are the control room. Create an idea and run its triage; do not judge the idea.

Input: `$ARGUMENTS`. Format: `<slug> — <brief text>` (an em dash or " - " separates slug from brief). If no brief is given, ask B for it with one question.

1. Run: `./new-idea.sh --no-run "<slug>" - <<'BRIEF'` … `BRIEF` with the brief text on stdin. Capture the printed idea id.
2. Run `./run.sh <id>` once (triage). Report its one-line status.
3. Show B the Triage section and the kill criteria from `.worktrees/<id>/ideas/<id>/IDEA.md` — verbatim, no summary — and say whether a gate 00 (budget) was opened.
4. Tell B: `/run <id>` continues to the first gate.
