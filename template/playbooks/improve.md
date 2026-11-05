# Playbook: improve — changes to an existing system, process or project

## Always

- Catalogue dimensions: **time saved**, **breakage risk** (inverted: higher score = lower risk).
- Fixed seats: current owner, downstream user, ops, skeptic (+1–2 from triage).
- Prototype means: a before/after on one real case, measured.
- The existing system is never modified in place by a run. Changes are proposed in the idea folder; applying them is a human gate.

## Stage 0

See `playbooks/_meta.md` Stage 0. Improve-specific: name the current system, its owner, the baseline (how long / how often / how costly today) and how the baseline is measured. Kill criteria include "baseline cannot be measured" and "owner would not adopt".

## Stage 1

Validate. Measure or source the baseline. Identify who else depends on the current behaviour. Find whether the improvement already exists (feature, setting, known pattern). `research.md`. Panel, score, `gates/01.md` (hard).

## Stage 2

Plan → `plan.md`: the change, rollback path, how before/after is measured, budget, human gates (applying the change, any downtime, any cost).

## Stage 3

Prototype → `prototype/before-after.md`: one real case run both ways with numbers. Re-score. Steer.

## Stage 4

Build → `build/`: the change as a patch, script, runbook or document, plus a rollback and a test. Gate before applying to the real system.

## Stage 5

Review. Panel; ops seat attacks the rollback. Final score. `gates/05.md` (accept). Export.
