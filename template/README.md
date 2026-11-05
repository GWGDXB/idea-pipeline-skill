# Idea Pipeline — how to run it

> **Who is B?** Every file in this repo calls the pipeline's owner "B": the one human who answers the gates. If you installed this, B is you.

Spec: `BUILD.md`. This file: operation only.

## One-time setup (Mac or VM, ≈ 10 min)

```bash
git clone <your GitHub remote> idea-pipeline && cd idea-pipeline
cp .env.example .env          # fill DRIVE_DIR at least
chmod +x *.sh system/lib/*.sh tests/*.sh .claude/hooks/*.sh
claude /login                 # Max account (needed for Remote Control)
```

## Daily use

| You want | Run |
| --- | --- |
| Start the control room (once, leave it running) | `./control-room.sh` → in it: `/config` → "Push when actions required" |
| Add an idea | `./new-idea.sh "slug" brief.md` or `./new-idea.sh "slug" -` (paste, Ctrl-D). Triage runs immediately. |
| Add ideas dropped in Drive | `./new-idea.sh --inbox` (reads `Drive/Idea Pipeline/_inbox/*.md`) |
| Push an idea on until it needs you | `./run.sh <id> --loop` |
| Step everything once (what cron does) | `./run.sh --all` |
| See where everything is | `./run.sh --status` |
| Answer gates | In the control room: `/gates` — or just type anything; open gates are injected. From the iPhone: Code tab → the control room session. |
| Poll for gates automatically | In the control room: `/loop 20m /gates` |

Gate answers can also be written by hand: copy `system/templates/decision.md` to `.worktrees/<id>/ideas/<id>/gates/NN.decision.md`, set `verdict:`, run `./run.sh <id>`.

## Where things are

- One idea = one branch `idea/<id>` = one worktree `.worktrees/<id>/` = one folder `ideas/<id>/` inside it. `main` holds the system, `gates/INBOX.md` and learnings.
- Drive exports: `$DRIVE_DIR/Idea Pipeline/<id>/`. Backups: `$DRIVE_DIR/Idea Pipeline/_backup/`. Inbox: `$DRIVE_DIR/Idea Pipeline/_inbox/`.
- Models and budgets per stage: `tools/current.md` (config block). Thresholds: `system/gates.md`.

## Scheduling (cron-style, same on Mac and VM)

```cron
*/30 * * * *  cd /path/to/idea-pipeline && ./run.sh --all        >> run.log 2>&1
15 6 * * *    cd /path/to/idea-pipeline && ./scout.sh daily      >> scout.log 2>&1
45 6 * * 1    cd /path/to/idea-pipeline && ./scout.sh weekly     >> scout.log 2>&1
30 2 * * *    cd /path/to/idea-pipeline && ./backup.sh           >> backup.log 2>&1
```

On a Mac that sleeps, cron doesn't fire; `run.sh` wraps Claude in `caffeinate -i` while it runs, but cannot wake the machine. Keep the lid open on power, or move to Phase 2.

## Acceptance checks (BUILD.md § Build order)

| Step | Command | Passes when |
| --- | --- | --- |
| 1 | `tests/probe-01.sh` | 4/4 checks |
| 2 | `./new-idea.sh --no-run test-brief tests/briefs/01-build-invoice-bot.md && ./run.sh --status` | idea folder with IDEA.md + progress.md on its own branch |
| 3 | `tests/triage-check.sh` | 5/5 briefs in the expected playbook, ≥3 kill criteria, budget line |
| 4–5 | `tests/probe-01.sh --keep` then open `.worktrees/<id>/ideas/<id>/panel.md` and `gates/01.md` | independent seat files, resolved objections, one-page gate |
| 6 | answer that gate from the iPhone via `/gates` | decision file written, `run.sh` advanced the idea, Drive folder has the gate page |
| 7 | `./scout.sh daily && ./backup.sh` | `learnings/executive.md` updated, bundle on Drive |

## Moving to a VM (≈ 1 h)

Install Claude Code; clone; copy `.env`; `claude /login`; `./control-room.sh`; add the cron lines. Nothing else.

## Restore from Drive alone

`git clone "$DRIVE_DIR/Idea Pipeline/_backup/idea-pipeline-<date>.bundle" idea-pipeline`
