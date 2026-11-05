# Idea Pipeline — operating reference

Read this when a question goes beyond the commands in `SKILL.md`. The pipeline's own spec is `BUILD.md` and its operations page `README.md`, both inside the installed pipeline folder.

## What it is

One idea = one git branch `idea/<id>` = one worktree `.worktrees/<id>/` = one folder `ideas/<id>/` with a single state file `progress.md`. `run.sh <id>` runs one headless `claude -p` per iteration with the model, turn cap and dollar cap for the current stage (from `tools/current.md`), commits the idea folder, and when the iteration wrote a gate page it exports the page to Drive (if configured) and appends a line to `gates/INBOX.md`. `run.sh <id> --loop` keeps stepping until the idea waits for a decision, parks, finishes or fails. `main` holds the system, the INBOX and the learnings; nothing an idea writes lands on `main`.

The owner is called **B** in every file of the pipeline. B judges the quality of the reasoning at the gates, not the domain.

## Stages

| Stage | Does | Output | Gate after |
| --- | --- | --- | --- |
| 0 Triage (Sonnet) | picks one playbook, writes kill criteria, estimates the budget | `IDEA.md` sections, `progress.md` | 00 only if the estimate exceeds `TRIAGE_BUDGET_GATE_USD` |
| 1 Validate (Opus) | sourced research against the kill criteria, adversarial panel, first score | `research/`, `panel.md`, `scores/round-1.md`, `gates/01.md` | 01 hard gate, always |
| 2 Plan | plan with stage budgets and a definition of done | `plan.md`, `gates/02.md` | 02 plan + budget |
| 3 Prototype | the cheapest thing that tests the riskiest assumption, re-score | `prototype/…` | score-steered; 03a… before any spend or external contact |
| 4 Build | the full build or deliverable, re-score | build output | 04 before the final build / irreversible step |
| 5 Review (final score on the judgment tier) | panel review, export | `gates/05.md` | 05 accept |

Playbooks: `build` (software), `business` (opportunity review), `research` (a question to answer), `create` (a format, deck, document), `improve` (an existing thing). Triage chooses; `playbooks/_meta.md` says how to add one.

## Gates and verdicts

| Gate | When | Verdicts | `run.sh` does on the verdict |
| --- | --- | --- | --- |
| 00 | triage estimate above the threshold | go · park · no-go | go → stage 1 |
| 01 | after Validate | go · park · no-go | go → stage 2 |
| 02 | after Plan | go · iterate · park · no-go | go → stage 3; iterate → same stage, notes go to the next iteration |
| 03a, 03b… | before any money, sign-up, domain, external contact | go · no-go | go → same stage continues, the run reads the decision file |
| 04, 04a… | before the final build / deploy | go · iterate · park | as above |
| 05 | after Review | accept · send-back · park | accept → `done`; send-back → stage 4 |
| B0…B5 | three consecutive cap hits in a stage | go · park | go → doubles that idea's cap factor and continues |

`park` keeps the idea on its branch (status `parked`); `no-go` removes the worktree and keeps the branch. A gate id the model invented (e.g. `03-prototype2`) is applied like a 03/04 gate: `go` keeps the stage. If the stage is actually finished, `advance <id>` sets `stage-complete` and lets `run.sh` move on.

**Decision file** `ideas/<id>/gates/NN.decision.md`: `verdict:`, `by: B`, `date:`, `gate:`, answers to the page's calibration questions, notes for the next iteration. `ip.sh decide` writes it; `run.sh <id>` applies it (the wrapper does both).

Scores steer everything else: average < 5.0 park, 5.0–6.9 iterate on the weakest dimension, ≥ 7.0 advance (`system/gates.md`). Two rounds without a 0.5 delta on the target dimension → open a gate instead.

## Statuses in `progress.md`

`running` (more iterations needed) · `awaiting-gate` (a page waits in `gates/NN.md`, `gate: NN`) · `stage-complete` (run.sh advances) · `parked` · `done` · `failed` (the headless run exited non-zero or wrote `failed`; sticky until an operator sets it back — `resume <id>`) · `no-go`.

`CAP HIT` in the log = the iteration hit `--max-budget-usd` or `--max-turns`. That is a checkpoint, not a failure: the next iteration inventories the folder and continues. Three in a row open gate `B<stage>`.

## Costs (API list prices; on a subscription this is usage, not a charge)

| Step | Observed | Cap per iteration (`tools/current.md`) |
| --- | --- | --- |
| Triage | USD 0.3–2 | 2 |
| Validate | USD 8 for research alone, 27–64 for a whole Validate with panel | 40 |
| Plan | USD 2–5 | 10 |
| Prototype | USD 4–7 per iteration | 30 |
| Build | up to the cap | 60 |
| Review | — | 40 |
| Scout daily / weekly | USD 0.5 / 2–8 | 2 / 8 |

A `budget_factor` in `progress.md` multiplies the caps for one idea (doubled by `go` on a budget gate). Models per stage are `--model` aliases; `fable` is used for the panel and the final score — if a plan has no access to it, change those two lines in `tools/current.md` to `opus`.

## Layout of an installed pipeline

```
<pipeline>/
├── run.sh  new-idea.sh  scout.sh  backup.sh  control-room.sh  setup.sh
├── .env                 DRIVE_DIR, CLAUDE_BIN, default caps (git-ignored)
├── CLAUDE.md            what every headless run reads first
├── system/              ground rules, token discipline, gates, scoring, panel, templates, lib/
├── playbooks/           build business research create improve _meta
├── tools/current.md     model + caps per stage (the only place the mapping lives)
├── learnings/           executive.md (≤ 50 lines, read by every run) · full.md (condensed by the scout)
├── gates/INBOX.md       one line per gate; "→ decided <verdict>" when answered
├── .claude/             slash commands + open-gate hook for sessions started inside this folder
├── .worktrees/<id>/     one checkout per idea (git-ignored); the idea's files are ideas/<id>/ inside it
├── .run-pids/           pid files of jobs launched by ip.sh
└── run.log              everything run.sh printed
```

Drive (optional): exports land in `$DRIVE_DIR/Idea Pipeline/<id>/`, bundles in `_backup/`, briefs dropped in `_inbox/*.md` become ideas with `new --inbox`. The git repo itself never syncs to Drive.

## Scheduling

Cron lines are in the pipeline's `README.md` (`run.sh --all` every 30 min, `scout.sh daily`, `scout.sh weekly`, `backup.sh`). A sleeping laptop never fires cron; `run.sh` wraps Claude in `caffeinate -i` while it runs but cannot wake the machine. The control room (this skill, or `control-room.sh` inside the folder with Remote Control) is what moves ideas when there is no cron.

## Conventions the control room keeps

- Present gate pages verbatim; the page is designed to be one screen.
- One gate at a time, INBOX order.
- Decisions carry the calibration answers — they are how thresholds and budgets get tuned by the scout.
- Nothing is launched twice: `jobs` before `run`, and the wrapper refuses duplicates.
- Never `source system/lib/common.sh` in an interactive shell; it sets `-euo pipefail` and derives its root from `BASH_SOURCE`, which zsh lacks. The wrapper is the interface.
