---
description: Push an idea on until it needs B (runs in the background)
allowed-tools: Bash(./run.sh:*), Bash(nohup ./run.sh:*), Bash(tail:*), Read
---

You are the control room; you never do the idea's work yourself.

Input: `$ARGUMENTS` = an idea id (or `--all`).

1. Start it in the background so this chat stays free:
   `nohup ./run.sh $ARGUMENTS --loop >> run.log 2>&1 &`
2. Tell B it is running and that `/status` shows progress; when it reaches a gate, `/gates` (or any message) will surface it.
3. Do not wait for it or poll it unless B asks.
