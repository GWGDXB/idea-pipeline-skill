#!/usr/bin/env bash
# setup.sh — one-time, run once from the repo root on the Mac (or VM):
#   bash setup.sh
# 1. installs .claude/ (hook, slash command, settings) from setup/dot-claude/
# 2. makes scripts executable
# 3. copies the spec in as BUILD.md if it sits next to the repo
# 4. git init + first commit (if not already a repo)
# 5. creates .env from .env.example if missing
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
if [[ -d setup/dot-claude ]]; then
  mkdir -p .claude
  cp -R setup/dot-claude/. .claude/
  echo "installed .claude/ ($(find .claude -type f | wc -l | tr -d ' ') files)"
fi
chmod +x *.sh system/lib/*.sh tests/*.sh .claude/hooks/*.sh 2>/dev/null || true
if [[ ! -f BUILD.md ]]; then
  spec="$(ls ../*BUILD.md 2>/dev/null | head -1 || true)"
  if [[ -n "$spec" ]]; then cp "$spec" BUILD.md; echo "copied spec → BUILD.md"; else echo "note: no BUILD.md found next to the repo; copy it in by hand"; fi
fi
[[ -f .env ]] || { cp .env.example .env; echo "created .env — fill DRIVE_DIR"; }
if [[ ! -d .git ]]; then
  git init -q -b main 2>/dev/null || git init -q
  git add -A
  git commit -q -m "idea-pipeline: initial build from BUILD.md rev 2"
  echo "git: initialised on main, first commit done"
else
  echo "git: already a repo, nothing done"
fi
for t in claude git python3; do command -v "$t" >/dev/null || echo "WARNING: $t not on PATH"; done
echo
echo "Next:  tests/probe-01.sh        (build step 1 acceptance check — uses real Claude, costs a few USD)"
echo "       ./control-room.sh        (then /config → Push when actions required)"
