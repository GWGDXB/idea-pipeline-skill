# Playbook: build — software, apps, automations, agents

## Always

- Catalogue dimensions: **reliability**, **adoption friction** (anchors: `system/scoring/catalogue.md`).
- Fixed seats: security, user, maintainer, cost hawk, skeptic (+1–2 from triage).
- Prototype means: a working slice of the riskiest feature, runnable by B in one command.
- The product gets its own repo under B's GitHub, separate from the pipeline. Creating that repo is an external action → human gate.
- Definition of done is the table in `BUILD.md` § Prototype to product; plan.md restates it for this idea.

## Stage 0

See `playbooks/_meta.md` Stage 0 (shared triage). Build-specific: name the riskiest technical assumption and the one integration most likely to break.

## Stage 1

Validate.
1. Research each kill criterion and each decision-driving fact (≥3 dated sources; use WebSearch/WebFetch; one subagent per fact as a context sink). Write `research.md` (cap 120 lines: fact → sources → verdict).
2. Check prior art: three closest existing tools, what they do, why this is still worth building (or not).
3. Run the panel per `system/panel/protocol.md` → `panel/<seat>.md` each, then `panel.md` with objections resolved or accepted.
4. Score per `system/scoring/universal.md` + catalogue → `scores/round-1.md`.
5. Write `gates/01.md` (gate type: hard). `status: awaiting-gate`, `gate: "01"`.

## Stage 2

Plan → `plan.md` from template. Must contain: definition of done for this product, riskiest assumption, stack from `tools/current.md` with reason, every human gate (repo creation, hosting, domain, money) named with cost. Then `gates/02.md` (gate type: plan+budget), `status: awaiting-gate`.

## Stage 3

Prototype. Build the slice that tests the riskiest assumption, inside `ideas/<id>/prototype/`. Must run with one documented command. Record what the test showed in `prototype/RESULT.md`. Re-score → `scores/round-N.md` with deltas. Then steer by score per `system/gates.md`: park → `status: parked`; iterate → `status: running` and name the target dimension in progress.md; advance → `status: stage-complete`. Max iterations: plan.md says.

## Stage 4

Build. Technique 11: read plan.md first; execute only what is there. Work in `ideas/<id>/build/` until the human gate for the external repo is passed. Before the final build (deploy, domain, anything irreversible) write `gates/04.md` (gate type: final-build) and wait. Tests for the core flow and every bug fixed; CI config present; `.env.example`; README; handover note. Re-score after each iteration.

## Stage 5

Review. Panel reviews the live product (real URL or running local build), not screenshots. Final score by the judgment tier. Gate `05.md` (gate type: accept) with the done-table filled with evidence paths. Export deliverables. `status: awaiting-gate`.
