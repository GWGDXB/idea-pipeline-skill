# Tools and models — current, as of 2026-10-23 (stage1/5 budgets raised 2026-10-23 after probe run: research alone ≈ $8)

The only place the model-per-step mapping lives. `run.sh` parses the `config` block below; everything else here is for humans. Swaps arrive via `pending-swaps.md` and B's approval; approved swaps apply to new ideas only.

## Config (parsed by run.sh — keep one setting per line, `key=value`, no spaces around `=`)

Model names are Claude Code `--model` aliases or full IDs. `budget` is the per-iteration cap passed as `--max-budget-usd` (API-list-price USD; on Max this is a token measure, not a charge), `turns` is `--max-turns`. Caps are runaway protection, not planning: hitting one ends the iteration and the next iteration continues from disk; three in a row open a budget gate. progress.md's `budget_factor` (doubled by `go` on a budget gate) multiplies the cap for that idea. `tools` is the `--allowedTools` list.

```config
stage0: model=sonnet turns=20 budget=2 tools=Read,Write,Edit,Glob,Grep
stage1: model=opus turns=100 budget=40 tools=Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Agent
stage2: model=opus turns=40 budget=10 tools=Read,Write,Edit,Glob,Grep,WebSearch,WebFetch
stage3: model=opus turns=120 budget=30 tools=Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Agent,Bash
stage4: model=opus turns=200 budget=60 tools=Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Agent,Bash
stage5: model=opus turns=100 budget=40 tools=Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Agent,Bash
panel: model=fable
final-score: model=fable
control-room: model=sonnet
scout-daily: model=sonnet turns=30 budget=2 tools=Read,Write,Edit,Glob,Grep
scout-weekly: model=opus turns=60 budget=8 tools=Read,Write,Edit,Glob,Grep,WebSearch,WebFetch
usd_per_mtoken_in: 3
usd_per_mtoken_out: 15
```

Why Bash is absent before stage 3: triage, validate and plan need no shell. Fewer tools, fewer tokens of schema, smaller blast radius.

## Tool per pipeline step (human view)

| Step | Tool | As of | Source that justified it |
| --- | --- | --- | --- |
| Headless runs | Claude Code `-p` with `--model`, `--max-turns`, `--max-budget-usd` | 2026-10-23 | code.claude.com/docs/en/headless.md |
| Control room | Claude Code `--rc`, Sonnet, push via `/config` | 2026-10-23 | code.claude.com/docs/en/remote-control.md |
| Research | WebSearch + WebFetch inside the run; one subagent per decision-driving fact | 2026-10-23 | BUILD.md technique 9 |
| Panel seats | Agent tool subagents on the judgment tier | 2026-10-23 | BUILD.md § Adversarial panel |
| Source of record | GitHub, branch per idea, worktree per idea | 2026-10-23 | BUILD.md |
| Drive exports | local Google Drive sync folder via `system/lib/export.sh` | 2026-10-23 | Phase 1 choice; Phase 2 → Drive API, same interface |
| Backup | `git bundle` daily to Drive | 2026-10-23 | BUILD.md |
| Visualisation (when a deliverable needs it) | — not chosen; scout to propose | | |
| Hosting for build-playbook products | — not chosen; scout to propose per idea | | |

## Model tiers (principle in BUILD.md; mapping above)

- Mechanical → sonnet. Workhorse → opus. Judgment → fable (≤ 50 % of weekly limit; the control room reports usage weekly).
- Haiku 5.5: not mapped. Scout to test on stage0 and scout-daily once; swap if quality holds.
- Token→USD rates above are placeholders for budget estimation only; the scout refreshes them from the pricing page with a date.

## MCP servers per stage (technique 10)

None required in v1. Drive is a sync folder; GitHub is the git CLI. If a stage needs a server, add `mcp=<name>` to its config line and the reason here.
