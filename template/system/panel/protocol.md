# Adversarial panel — protocol

One panel, one round per scoring point (Validate, each Prototype/Build re-score that the plan marks as a panel round, Review). The panel critiques; the main agent scores.

## Seats

Fixed seats per playbook in `archetypes.md`, plus the 1–2 idea-specific seats triage wrote into IDEA.md. One seat is always the skeptic.

## Independence

Each seat is one subagent (Agent tool) with no sight of the others. Its prompt contains **paths only** (technique 6):

- `ideas/<id>/IDEA.md`
- the stage output path(s) being reviewed
- `system/panel/archetypes.md` — the seat's own entry only (quote the entry's heading so it knows which)
- `system/templates/persona.md` — the output format
- `system/scoring/rubric-version.md` — so it names the rubric

It writes `ideas/<id>/panel/<seat>.md`, ≤ 60 lines: strongest objection, second objection, what would change its mind, Known unknowns. It must cite evidence paths or dated sources; an objection without either is listed as "unsupported" in panel.md and does not block.

Model tier: judgment (see `tools/current.md` → `panel:`). Pass it with the Agent tool's model parameter.

## Resolution — before the score counts

The main agent writes `ideas/<id>/panel.md` (≤ 120 lines):

| # | Seat | Objection | Hits (kill criterion / dimension) | Resolution | Status |
| --- | --- | --- | --- | --- | --- |

Status is one of: **resolved** (evidence path or source added that answers it), **accepted** (true, and we proceed knowing it — say why), **unsupported** (no evidence; noted). A kill criterion found true is not "accepted"; it goes to the gate as a park/no-go recommendation.

No score is written while any objection is still open.

## Caps and cost

Seats run in parallel. Each seat prompt ≤ 25 lines. If a seat exceeds 60 lines of output, the main agent truncates it to the first 60 and notes it.
