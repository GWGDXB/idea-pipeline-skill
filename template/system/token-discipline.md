# Token discipline — eleven mandatory techniques

Quality bar first, budget second. Triage sets what "good enough" means for this idea, then estimates tokens per stage. The plan is re-costed at every stage end; B approves the estimate before any expensive stage.

1. **Executive learnings only.** Read `learnings/executive.md` (≤ 50 lines). Never `learnings/full.md` unless the task names it.
2. **`progress.md` is the sole state.** Fresh context every iteration. No long-running conversation. If you need something from a previous iteration, it must be in a file.
3. **Cheapest-method ladder.** grep / script / cached source → cheap model → expensive model. Try the lower rung first and log when you had to climb.
4. **Stage-scoped playbook loading.** Read only `.run/stage.md` (your stage's section). Never the whole playbook.
5. **Hard output caps.** Line limits per artifact are in each template's header. Panel seat page: 1 page (≤ 60 lines). Gate page: 1 page (≤ 60 lines). Over the cap = rewrite shorter, not append.
6. **Write once, reference by path.** Never paste a file's content into a prompt when a path will do. Subagent prompts carry paths.
7. **Model tiering.** `tools/current.md` names the model per step; `run.sh` sets it. You do not choose models. Subagents inherit the tier named in `system/panel/protocol.md`.
8. **Budget line per plan.** `plan.md` carries tokens planned vs spent per stage. `run.sh` enforces `--max-budget-usd` and `--max-turns` per iteration as a checkpoint: a cut-off iteration is resumed by the next one, and three cut-offs in a row go to B. Never a silent overrun, never a silent redo.
9. **Subagents as context sinks.** Research and panel seats run as subagents; only their written one-page summaries return. The main loop never holds raw research.
10. **Minimal MCP servers.** A run loads only the servers its stage needs (`tools/current.md` lists them per stage). Loaded schemas cost 50–70k tokens a session.
11. **Plan mode before execution.** Every Build stage iteration starts by reading `plan.md` and executes only what the approved plan says. No plan, no build.

## Estimating

Observed figures first, placeholders second. Log actuals in `progress.md`; the scout updates this table.

| Stage | USD per iteration (observed) | Notes |
| --- | --- | --- |
| Triage | 0.3 (Sonnet) | [run 2026-10-23-probe] two runs, 0.31 and 0.33 |
| Validate | 8 for research alone, 4 facts × 1 Opus subagent each, primary sources fetched; panel on Fable not yet measured — plan 15–25 | [run 2026-10-23-probe] stopped at the $8 cap after research, before the panel |
| Plan | 2–5 (placeholder) | |
| Prototype | 5–15 (placeholder) | |
| Build | 20–60 (placeholder) | |
| Review | 10–20 (placeholder; panel on Fable) | |

Triage converts these to its budget line. The hard cap per iteration is in `tools/current.md`; a run that hits it ends with `error_max_budget_usd`; `run.sh` keeps the idea `running` and the next iteration continues from the files on disk. Three consecutive cap stops open a budget gate for B. The cap is a checkpoint, not a failure.
