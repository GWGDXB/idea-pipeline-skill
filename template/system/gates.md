# Gates — thresholds, page format, calibration

## Thresholds (rubric v1, tuned from B's decisions)

| Average score | Steering |
| --- | --- |
| < 5.0 | **park** — write the gate page with verdict park; status `parked` after B confirms (parking is a human gate at Validate, score-steered afterwards) |
| 5.0 – 6.9 | **iterate** — on the weakest dimension; name it and the expected Δ in progress.md before running |
| ≥ 7.0 | **advance** |

Iteration discipline: stop after two rounds without a meaningful delta (< 0.5 on the target dimension) and open a gate instead.

## Human gates (always, regardless of score)

| Gate | NN | When | Decision verdicts |
| --- | --- | --- | --- |
| budget | 00 | Triage estimate for Validate+Plan above the threshold in `.env` | go / park / no-go |
| hard | 01 | After Validate | go / park / no-go |
| plan+budget | 02 | After Plan | go / iterate / park / no-go |
| spend/contact | 03a, 03b… | Before any money, sign-up, domain or external contact | go / no-go |
| final-build | 04 | Before the final build / deploy / irreversible step | go / iterate / park |
| accept | 05 | After Review | accept / send-back / park |

## Gate page

`system/templates/gate.md`, ≤ 60 lines, always the same shape: verdict, score with deltas, three reasons, the killer risk, recommended next step, Drive line (filled by run.sh), 1–3 calibration questions, Known unknowns. Written to `ideas/<id>/gates/NN.md`.

## Decision file

B's answer lands in `ideas/<id>/gates/NN.decision.md` (`system/templates/decision.md`). `run.sh` reads `verdict:` and acts:

| verdict | run.sh does |
| --- | --- |
| go / accept | advance to next stage (accept → `done`) |
| iterate | same stage, `running`, iteration +1; the decision's notes go to the next iteration |
| park | `parked`; idea stays on its branch |
| no-go | `no-go`; branch kept, worktree removed |
| send-back | Review → Build, `running` |

## Calibration questions

Every gate carries one to three. They are how thresholds, anchors and budgets get tuned. Good calibration questions are about B's judgment, not the domain:

- "We scored Effort 6 because X; would you have scored it higher or lower?"
- "Is a 3-source requirement on fact Y overkill for an idea at this stage?"
- "This would have parked at 4.8 — right call?"
- "The panel's lawyer seat objection cost ~40k tokens to resolve; worth it?"

The scout's daily pass reads decision files and condenses recurring answers into `learnings/executive.md`; threshold changes bump the rubric version.
