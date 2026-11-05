#!/usr/bin/env bash
# tests/triage-check.sh — acceptance check for build step 3.
# Runs triage (stage 0 only) on the five sample briefs in tests/briefs/ and checks each lands in the expected playbook
# with kill criteria and a budget line. Cleans up unless --keep.
source "$(dirname "${BASH_SOURCE[0]}")/../system/lib/common.sh"
KEEP=0; [[ "${1:-}" == "--keep" ]] && KEEP=1
pass=0; fail=0
for f in "$ROOT"/tests/briefs/*.md; do
  expected="$(grep -m1 '^Expected playbook:' "$f" | awk '{print $3}')"
  brief="$(grep -v '^Expected playbook:' "$f")"
  slug="tri-$(basename "${f%.*}" | cut -c1-20)-$(date +%S)"
  id="$("$ROOT/new-idea.sh" --no-run "$slug" - <<<"$brief" 2>/dev/null)"
  "$ROOT/run.sh" "$id" >/dev/null 2>&1 || true           # exactly one step = triage
  dir="$(idea_dir "$id")"; pm="$dir/progress.md"
  got="$(pm_get "$pm" playbook)"
  kc="$(awk '/^## Kill criteria/{f=1;next} /^## /{f=0} f && /^[0-9]+\. ./' "$dir/IDEA.md" | wc -l | tr -d ' ')"
  bl="$(awk '/^## Budget line/{f=1;next} /^## /{f=0} f && /^\| 1 Validate \|/ && !/\|[[:space:]]*\|[[:space:]]*\|/' "$dir/IDEA.md" | wc -l | tr -d ' ')"
  if [[ "$got" == "$expected" && "$kc" -ge 3 && "$bl" -ge 1 ]]; then echo "  PASS  $(basename "$f") → $got · $kc kill criteria · budget line filled"; pass=$((pass+1))
  else echo "  FAIL  $(basename "$f") → got '$got' (expected $expected) · $kc kill criteria · budget filled: $bl"; fail=$((fail+1)); fi
  if [[ $KEEP -eq 0 ]]; then
    git_root worktree remove --force "$(wt_dir "$id")" >/dev/null 2>&1 || true
    git_root branch -D "$(idea_branch "$id")" >/dev/null 2>&1 || true
    tmp="$(mktemp "${TMPDIR:-/tmp}/idea-pipeline.XXXXXX")"; grep -v "^| $id |" "$ROOT/gates/INBOX.md" > "$tmp" && mv "$tmp" "$ROOT/gates/INBOX.md"
  fi
done
[[ $KEEP -eq 0 ]] && { git_root add gates/INBOX.md >/dev/null 2>&1; git_root commit -q -m "triage-check cleanup" >/dev/null 2>&1 || true; }
echo "triage-check: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
