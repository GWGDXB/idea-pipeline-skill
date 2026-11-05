# Idea Pipeline — a Claude Code skill

Give Claude an idea. It triages, validates, plans, prototypes, builds and reviews it in headless runs with per-stage budgets, and stops at human gates where you decide **go / iterate / park / no-go**. Every fact in its reasoning carries a dated source; every output ends with what it does not know.

This repo is the **skill**: it teaches Claude Code how to install and operate the pipeline from any folder, and it bundles a clean copy of the pipeline itself (`template/`). The pipeline is a set of shell scripts and Markdown files, no server, no dependencies beyond `git`, `python3` and Claude Code.

## Install the skill (60 seconds)

```bash
git clone https://github.com/GWGDXB/idea-pipeline-skill ~/.claude/skills/idea-pipeline
```

For a team, put the same folder in a shared repo at `.claude/skills/idea-pipeline/` instead. Then start Claude Code anywhere and say:

> install the idea pipeline

Claude runs `bash scripts/ip.sh install`, which creates `~/idea-pipeline` (or a folder you name), its `.env`, a git repo with a first commit, and remembers the location. The only prerequisite is a logged-in Claude Code (`claude /login`).

## Use it

| You say | What happens |
| --- | --- |
| "new idea: a bookable photo studio in Dubai for creators" | Claude writes the brief, creates the idea, runs triage (Sonnet, ≈ USD 1–2) and shows the kill criteria |
| "run it" | the loop runs in the background through Validate (sourced research, adversarial panel, score) and stops at the hard gate |
| "any gates?" / "engage the pipeline" | Claude shows each open gate page in full and asks for your verdict and the page's calibration answers |
| "status" | one line per idea: stage, status, gate, spend |

Everything is also a plain command: `bash ~/.claude/skills/idea-pipeline/scripts/ip.sh help`.

```
install · use · root · doctor
status · gates · show · new · decide · run · step · advance · resume · jobs · log · backup · scout
```

## What it costs

Budgets are enforced per iteration (`--max-budget-usd`, `--max-turns`); hitting a cap is a checkpoint, not a failure, and three in a row ask you before spending more. Observed so far at API list prices: triage USD 0.3–2, Validate USD 10–60, Prototype USD 4–7 per iteration, a whole idea USD 30–150. On a Claude subscription this is usage against your plan, not a charge. The panel and final score default to the `fable` model; set them to `opus` in `tools/current.md` if your plan lacks it.

## How it works

- **One idea = one branch = one folder.** `ideas/<id>/progress.md` is the only state; every iteration starts with fresh context and reads it. Runs never touch another idea.
- **Eight ground rules** every run obeys (`system/ground-rules.md`): minimum tokens for the quality bar, no decision-driving fact without three dated sources, kill criteria before research, Known unknowns on every output, a hard gate after validation, calibration questions for you on every gate page.
- **Fixed human gates:** no-go, any money spend, any external contact, the final build. Everything else is steered by the score.
- **Playbooks** for five kinds of idea: build, business, research, create, improve.
- **Learnings loop:** a daily scout condenses your decisions into rules every later run reads.

The full spec is `template/BUILD.md`; the operating reference Claude uses is `reference/operating.md`.

## Optional: Google Drive

Set `DRIVE_DIR` in the pipeline's `.env` to your local Drive sync folder and gate pages, deliverables and nightly git bundles are copied to `Idea Pipeline/<id>/` there; briefs dropped into `Idea Pipeline/_inbox/` become ideas. Without it everything stays in the repo.

## Repo layout

```
SKILL.md                 what Claude reads (the control-room role)
reference/operating.md   stages, gates, verdicts, costs, layout
scripts/ip.sh            the wrapper: install, status, gates, decide, run …
scripts/sync-template.sh maintainer: refresh template/ from a live pipeline
template/                the pipeline (54 files), installed by ip.sh install
tests/smoke.sh           offline check of the wrapper, no model calls
```

Test: `bash tests/smoke.sh`.

## Credits

Designed and built by Bjoern Lauen with Claude (Anthropic). The pipeline spec is `template/BUILD.md`, revision 2, October 2026; the skill wraps it for sharing.
