# Playbook: _meta — how playbooks work, and what to do when none fits

Triage picks exactly one playbook. If none fits, triage sets `playbook: _meta` and this playbook runs once: it drafts the missing playbook, runs the idea through it, and submits the draft for B's approval at gate 01.

## Always

- Sections: `## Always` (loaded with every stage) and `## Stage 0` … `## Stage 5`. `run.sh` loads only your stage's section plus Always.
- Each playbook defines: what each stage means for its kind of idea; its two catalogue scoring dimensions (anchors in `system/scoring/catalogue.md`); its fixed panel seats (`system/panel/archetypes.md`).
- Every stage writes to the paths named below, within caps, ends with Known unknowns, updates progress.md, and stops.
- Caps unless a stage says otherwise: IDEA.md 120 lines · panel seat 60 · panel.md 120 · scores/round-N.md 80 · gate 60 · plan.md 150.

## Stage 0

Triage (this is the shared triage procedure; playbooks do not override it).

1. Read IDEA.md brief. Classify into exactly one of: build, business, research, create, improve. If nothing fits, `_meta`.
2. Write into IDEA.md's Triage section: playbook, the one-line why, the quality bar for "good enough" for this idea, 1–2 idea-specific panel seats (name + what they protect), and the decision-driving facts that will need ≥3 sources.
3. Write three to five kill criteria. Each must be testable by Validate with sourced facts. No research yet — rule 4.
4. Fill the budget line using `system/token-discipline.md` estimates scaled by the quality bar. Convert tokens to USD with the rates in `tools/current.md`.
5. Set progress.md: `playbook`, `budget_usd_planned`, `stage: 0`. Then:
   - if Validate + Plan estimate > the triage gate threshold named in `.run/stage.md` header → write `gates/00.md` (gate type: budget) and set `status: awaiting-gate`, `gate: "00"`;
   - else `status: stage-complete`.
6. Stage summary row 0 in progress.md filled.

## Stage 1

`_meta` only: draft `playbooks/<name>.md` **inside the idea folder** at `ideas/<id>/proposed-playbook.md` following the structure of an existing playbook (read one, the closest). Define stages, two catalogue dimensions with 2/5/8 anchors, fixed seats. Then run Validate per that draft. Gate 01 presents both the validation result and the proposed playbook; the calibration questions ask B whether to adopt it. Adoption into `playbooks/` is done by B or the scout, never by the run (rule 6).

## Stage 2

Run Plan per the proposed playbook.

## Stage 3

Run Prototype per the proposed playbook.

## Stage 4

Run Build per the proposed playbook.

## Stage 5

Run Review per the proposed playbook. Add to learnings a dated note on whether the proposed playbook held up.
