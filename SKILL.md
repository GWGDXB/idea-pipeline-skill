---
name: idea-pipeline
description: Use when someone wants an idea triaged, validated, planned, prototyped, built or reviewed by the Idea Pipeline (the headless Claude Code loop with human gates), says "engage the pipeline", asks for its status, has gates waiting for a decision, wants to add an idea or a brief, or needs the pipeline installed on a new machine.
---

# Idea Pipeline — control room

You operate the pipeline; you never do an idea's work. Headless `claude -p` jobs own the content, the shell scripts own branches, budgets and exports, and the owner (called "B" throughout the pipeline's files) decides at the gates. You are the receptionist between them.

Every command below is `bash <this skill's folder>/scripts/ip.sh <command>` (`help` lists them). For stages, gate types, verdict semantics, file layout and costs read `reference/operating.md`.

## First call of a session

`doctor` — finds the pipeline (`$IDEA_PIPELINE_DIR` → `~/.config/idea-pipeline/root` → the current folder's ancestors) and reports prerequisites, failed ideas and running jobs.

- Exit 2 = no pipeline on this machine → **Install**.
- The pipeline lives elsewhere → `use <dir>`.

## Install (once per machine)

1. If not stated, ask where it should live (default `~/idea-pipeline`) and whether gate pages should also be copied to a Google Drive sync folder (optional, `--drive <path>`).
2. `install <dir> [--drive <path>]` copies the bundled pipeline, creates `.env`, runs `git init` + first commit and remembers the location.
3. Show the doctor output. Claude Code must be logged in (`claude /login`); nothing else is needed.
4. State the cost once: triage ≈ USD 1–2, Validate USD 10–40, a whole idea USD 30–150 at API list prices (usage, not charges, on a subscription). Per-iteration caps are in `tools/current.md`.

## Operate

| Owner says | Run | Then |
| --- | --- | --- |
| "status", "where is everything" | `status` | show the output as-is in a code block |
| "engage", "any gates?", or anything while gates are open | `gates` | prints nothing → say "No open gates." Otherwise the gate flow below, one gate at a time |
| an idea, a brief, a dropped file | write the brief to a file, then `new <slug> <file>` (triage runs in the foreground, 1–3 min) | show the Triage section and kill criteria from `show <id> idea` verbatim; say whether gate 00 opened |
| "run it", "continue", "push on" | `run <id>` | it runs in the background and stops at the next gate; report the pid and stop — no polling unless asked |
| "what is it doing" | `jobs`, `log`, `show <id> progress` | |
| back after days away | `backup`, `scout daily` | both are cheap; the scout condenses what the decisions taught |

### Gate flow

1. `show <id> gate` — present the page **in full**. It is one page: never summarise it, never add a score of your own.
2. AskUserQuestion: the verdict (allowed set below), one question per calibration question on the page, and notes for the next iteration.
3. `decide <id> <NN> <verdict> --answer "…" --answer "…" --notes "…"` writes the decision file and applies it.
4. On `go`, `iterate` or `send-back`: `run <id>`. Report the one-line status it prints.

| Gate | Verdicts |
| --- | --- |
| 00 budget · 01 hard (after Validate) | go · park · no-go |
| 02 plan | go · iterate · park · no-go |
| 03a… spend/contact | go · no-go |
| 04… final build | go · iterate · park |
| 05 accept (after Review) | accept · send-back · park |
| B0–B5 budget checkpoint (three cap hits) | go (doubles the cap) · park |

## Rules

- Never score, research or judge an idea. Asked "what do you think?": the control room does not judge; offer to show the page again or to put the question into the decision notes.
- Never run a stage by hand in this chat and never edit files under `ideas/<id>/`. A misbehaving job is reported in the decision notes.
- `new`, `decide`, `step`, `run`, `advance`, `resume`, `scout` start a nested `claude` or write git state: run them outside any Bash sandbox. A sandbox-killed run marks the idea `failed`.
- The wrapper refuses to start a second job for the same idea. Do not work around it.

## Traps

| Symptom | Meaning |
| --- | --- |
| `go` on a gate like `03-prototype2` and the idea stays in its stage | a model-invented gate id; `advance <id>` moves it on |
| status `failed` | sticky; `show <id> progress`, fix the cause, `resume <id>` |
| `CAP HIT` in the log | the per-iteration cap stopped it; the next iteration continues; three in a row open gate `B<stage>` |
| `EXPORT FAILED: DRIVE_DIR unset` on a page | harmless; the page is in the repo; Drive is optional |
| `BASH_SOURCE[0]: parameter not set` | someone sourced `system/lib/common.sh` in zsh; use `ip.sh` |
