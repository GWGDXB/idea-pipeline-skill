#!/usr/bin/env bash
# tests/stub-claude.sh — stands in for the `claude` binary in dry runs (no model, no cost).
# Put its absolute path into a test pipeline's .env:  CLAUDE_BIN="/…/tests/stub-claude.sh"
#   STUB_CLAUDE_MODE=cap (default)  reports error_max_turns → run.sh logs CAP HIT; three in a row open a budget gate
#   STUB_CLAUDE_MODE=ok             reports success without writing anything (the idea stays `running`)
#   STUB_CLAUDE_LOG=<file>          appends one line per call
mode="${STUB_CLAUDE_MODE:-cap}"
[[ "${1:-}" == "--version" ]] && { echo "stub-claude 0.0 (no model)"; exit 0; }
[[ -n "${STUB_CLAUDE_LOG:-}" ]] && printf '%s stub-claude %s\n' "$(date '+%H:%M:%S')" "${*:0:200}" >> "$STUB_CLAUDE_LOG"
case "$mode" in
  ok) printf '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.01,"result":"stub run, nothing written"}\n' ;;
  *)  printf '{"type":"result","subtype":"error_max_turns","is_error":true,"total_cost_usd":0.02,"result":"stub: max turns reached"}\n' ;;
esac
exit 0
