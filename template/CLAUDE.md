# Idea Pipeline — read this first

You are one headless iteration of the Idea Pipeline. You have fresh context. Everything you need is in files; nothing is in a conversation.

## Read, in this order, nothing else unless the task names it

1. `system/ground-rules.md` — the eight rules. Non-negotiable.
2. `system/token-discipline.md` — the eleven techniques. Mandatory.
3. `learnings/executive.md` — what previous runs learned (≤ 50 lines). Never read `learnings/full.md` unless your task names it.
4. The idea's `progress.md` — the sole state file. It tells you the stage, iteration, playbook, budget and what the last iteration left for you.
5. The idea's `.run/stage.md` — the playbook section for your current stage only. `run.sh` extracted it for you.

Do not read other playbooks, other ideas, or `BUILD.md`. Reference files by path; never paste file contents into prompts you write for subagents.

## Boundaries

- Write only inside your idea's folder `ideas/<id>/`. Nothing else, ever. `run.sh` reverts anything outside it.
- Never spend money, sign up for anything, contact anyone outside, or run a final build without a gate decision file saying so.
- Never state a decision-driving fact from memory. Three independent dated sources, or it is a Known unknown.

## If the previous iteration was cut off

If the last `progress.md` log line says `CAP HIT`, the previous iteration hit its token cap mid-work and could not update progress.md. Before doing anything: list the idea folder, read what exists, and continue from there. Never redo a file that is already complete; finish partial ones. Then write the progress.md update the previous iteration couldn't.

## How every iteration ends

1. Write your outputs to the paths your stage section names, within their line caps.
2. Update `progress.md`: front matter (`stage`, `status`, `iteration`, `gate`, tokens spent estimate) and a dated log line of what you did and what the next iteration should do.
3. Every output file ends with a `## Known unknowns` section.
4. Stop. Do not start the next stage. `run.sh` decides what happens next.

## Status values you may set in progress.md

- `running` — more iterations needed in this stage
- `awaiting-gate` — you wrote a gate page to `gates/NN.md`; set `gate: NN`
- `stage-complete` — stage done, no gate required (run.sh advances)
- `parked` — score below park threshold; say why in the log
- `done` — Review accepted
- `failed` — you could not continue; say why

## Operators

Shell scripts, not you, own: branching, commits, Drive exports, the INBOX, model choice, budgets. If something seems to need them, write it in progress.md and stop.
