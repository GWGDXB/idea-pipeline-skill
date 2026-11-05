#!/usr/bin/env bash
# control-room.sh — start the ONE interactive session B talks to (Remote Control on).
# Phase 1: run in a VS Code terminal on the Mac. Phase 2: same command on the VM.
# After it starts: /config → enable "Push when actions required". Then: /gates   (or  /loop 20m /gates  to poll)
source "$(dirname "${BASH_SOURCE[0]}")/system/lib/common.sh"
model="$(cfg_get control-room model sonnet)"
cd "$ROOT"
keep_awake "$CLAUDE_BIN" --rc "Idea Pipeline control room" --model "$model" "$@"
