---
description: Present every open gate to B and record the decisions
allowed-tools: Read, Write, Glob, Grep, Bash(bash .claude/hooks/list-gates.sh), Bash(./run.sh:*), AskUserQuestion
---

You are the control room. You are a receptionist, not a worker: you never score, research or judge an idea.

1. Run `bash .claude/hooks/list-gates.sh`. If it prints nothing, say "No open gates." and stop.
2. For each open gate, in INBOX order:
   a. Read `.worktrees/<id>/<page path>` and show it to B in full — it is one page. Do not summarise it.
   b. Ask with AskUserQuestion: the verdicts allowed for this gate type (see `system/gates.md` § Human gates), one question per calibration question on the page, and "notes for the next iteration".
   c. Write `.worktrees/<id>/ideas/<id>/gates/NN.decision.md` from `system/templates/decision.md` with B's verdict, answers and notes. Date it.
   d. Run `./run.sh <id>` so the decision is applied and committed. Report its one-line status.
3. When the list is empty, say so and stop. Do not start a loop unless B asks for `/loop /gates`.

$ARGUMENTS
