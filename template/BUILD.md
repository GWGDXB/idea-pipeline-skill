# Idea Pipeline — BUILD.md

Oct 22, 2026 · @Bjoern Lauen · rev 2 (gate delivery, acceptance checks, model mapping — verified against Claude Code docs 22 Oct 2026)

Spec for an automated Claude Code pipeline that takes any idea from B and validates, plans, prototypes, builds and reviews it with minimal human input, running on his Mac first and movable to a VM in an hour.

## Purpose and principles

The loop takes any idea from B — a creative AI platform one day, a Big-Four-style business opportunity review the next — and runs it through validate → plan → prototype → build → review with as little human input as possible, always using the best current AI tool for each step. B judges the quality of reasoning at the gates, not the domain.

Ground rules every run obeys:

1. Minimum tokens for the quality bar, never more; optimum method before expensive method.
2. Never rely on trained knowledge for anything that decides an outcome. Decision-driving facts need at least 3 independent sources; background facts need 1. Every claim carries a date and a source.
3. Every output ends with a "Known unknowns" section.
4. Kill criteria are written before research starts, not after.
5. Hard gate after validation — nothing proceeds to plan without a score and B's go.
6. Each idea lives in its own folder and git branch; runs never touch another idea's files.
7. State lives in files, not in the conversation: every iteration starts with fresh context and reads progress.md.
8. The system asks B calibration questions; B never has to hunt for what to calibrate.

## Architecture: Mac first, VM-ready

Phase 1 runs entirely on B's MacBook; Phase 2 moves the same repo to an always-on VM in about an hour. Nothing in the design is Mac-specific.

| Part | Role | Phase 1 (Mac) | Phase 2 (VM) |
| --- | --- | --- | --- |
| Pipeline jobs | Headless Claude Code runs, one fresh process per iteration, one folder per idea, many in parallel | `run.sh` on the Mac | Same script on the VM |
| Control room | ONE interactive Claude Code session with Remote Control on (`claude --rc "Control room"`, model Sonnet — it is a receptionist, not a worker); B's single window into all jobs; push to iPhone enabled via `/config` → "Push when actions required" | VS Code terminal, wrapped in `caffeinate -i` while on power | Same command on the VM, reached from desktop app and iPhone |
| GitHub | System of record: repo, every run commits, history, branches per idea | Push from Mac | VM clones and pushes |
| Google Drive | Inbox (idea briefs, PDFs, decks dropped in), outbox (exported deliverables per idea), nightly git bundle backup | Drive MCP / local sync folder | Drive API |
| Claude app (Mac + iPhone) | Where B reads gate pages and answers advance / park / no-go | Desktop app Code tab, iPhone app | Same, via Remote Control |
| Home Assistant | Optional actions via HA Cloud remote URL + long-lived token | Works from anywhere | Works from anywhere |

How a gate reaches B (verified design, see Sources):

1. The job writes its one-page gate to `ideas/<id>/gates/NN.md`, exports it to Drive, and appends one line (`<id> | NN | <timestamp>`) to the fixed file `gates/INBOX.md` at repo root.
2. The control-room session runs a `/loop` every 15–30 min: read `gates/INBOX.md`, for every gate without a `NN.decision.md` present the gate page and end with an `AskUserQuestion` (go / park / no-go + calibration answers). The question is what triggers the iPhone push — Remote Control pushes when an action is required.
3. Fallback that always works: a `UserPromptSubmit` hook (`.claude/hooks/list-gates.sh`) injects all undecided gates into context whenever B types anything, e.g. "gates" from the iPhone.
4. The control room writes `ideas/<id>/gates/NN.decision.md` (verdict + answers). `run.sh` polls for that file before advancing. No live IPC between session and jobs; state stays in files (ground rule 7).

Why not a file-watch hook: Claude Code's `FileChanged` hook watches literal filenames named in advance and is not documented to fire while the session is idle; there is no timer hook. Why not Telegram: Channels (Telegram/Discord) exist as an official research preview and remain plan B if the push route proves unreliable in step 0; not needed by design.

Mac sleep: Remote Control reconnects automatically after sleep, but the `claude` process must survive — interactive mode retries indefinitely, server mode (`claude remote-control`) exits after ~10 min offline, so the control room runs interactive. Headless jobs die on sleep, so `run.sh` runs under `caffeinate -i`. If the Mac must sleep, Phase 2 is the fix.

One session, many jobs: the Remote Control session is never the pipeline. It is the receptionist; the jobs are the workers. Ten ideas = ten headless loops, one chat.

Drive rule: the git repo never syncs to Drive (sync corrupts git). Drive holds exported copies only, in one folder per idea named exactly like its repo folder (\`Idea Pipeline/\<yyyy-mm-dd>-\<slug>/\`), written at every gate; the gate page carries the Drive link so a failed export is visible. No idea ever writes outside its own folder, in the repo or on Drive.

## Folder structure

One repo, `idea-pipeline/`, on GitHub. Everything the system needs is inside it; secrets live in one `.env` that is git-ignored.

```markdown
idea-pipeline/
├── BUILD.md                    # this spec
├── README.md                   # how to run it
├── CLAUDE.md                   # what every Claude Code run reads first (points to ground rules + executive learnings)
├── .env.example                # keys: Drive, HA token, API keys — real values in .env (git-ignored)
├── .claude/
│   └── hooks/
│       └── list-gates.sh       # UserPromptSubmit hook: injects undecided gates into the control-room context
├── gates/
│   └── INBOX.md                # one line per gate written by any job; read by the control-room loop
├── tests/
│   ├── probe-01.sh             # compliance probe for build step 1 (sources, Known unknowns, kill criteria, stops at gate)
│   └── briefs/                 # five sample briefs for the triage check (build step 3)
├── run.sh                      # the loop: pick next stage for an idea, run one headless iteration under caffeinate, pass --model/--max-budget-usd/--max-turns from tools/current.md and plan.md, commit; waits for gates/NN.decision.md before advancing
├── new-idea.sh                 # create ideas/<date>-<slug>/ from a brief (text or Drive file), run triage
├── scout.sh                    # tooling scout: daily condense, weekly tool research
├── backup.sh                   # daily git bundle → Drive
├── system/
│   ├── ground-rules.md
│   ├── token-discipline.md
│   ├── gates.md                # gate page format + calibration questions
│   ├── scoring/
│   │   ├── universal.md        # value, feasibility, effort
│   │   ├── catalogue.md        # playbook-specific dimensions with anchored examples
│   │   └── rubric-version.md
│   ├── panel/
│   │   ├── protocol.md         # independent review, objections resolved before score counts
│   │   └── archetypes.md       # fixed seats per playbook
│   └── templates/
│       ├── brief.md
│       ├── progress.md
│       ├── plan.md
│       └── persona.md
├── playbooks/
│   ├── _meta.md                # how to write a new playbook
│   ├── build.md
│   ├── business.md
│   ├── research.md
│   ├── create.md
│   └── improve.md
├── tools/
│   ├── current.md              # the tool AND model per step, as of date — the only place the model mapping lives
│   ├── sources.md              # where the scout looks
│   ├── criteria.md             # how a tool earns a swap
│   └── pending-swaps.md        # proposed swaps awaiting B's approval
├── learnings/
│   ├── executive.md            # ≤ 50 lines, read by every run
│   └── full.md                 # ≤ 250 lines, condensed daily
└── ideas/
    └── <yyyy-mm-dd>-<slug>/
        ├── IDEA.md             # the brief
        ├── progress.md         # sole state file
        ├── plan.md
        ├── panel.md
        ├── scores/             # one file per scoring round, with deltas
        ├── gates/              # NN.md one page per gate; NN.decision.md written by the control room
        └── exports/            # what went to Drive, with links
```

## Pipeline stages

Every idea moves through the same stages; the playbook decides what each stage means for that kind of idea.

| Stage | What happens | Output | Gate after it |
| --- | --- | --- | --- |
| 0 Triage | Classify the idea into one playbook, add 1–2 idea-specific panel seats, write kill criteria, estimate a token budget | IDEA.md, progress.md, budget line | B approves budget if an expensive stage is ahead |
| 1 Validate | Sourced research against the kill criteria; panel round; first score | panel.md, scores/round-1.md, gate page | HARD gate: B says go / park / no-go |
| 2 Plan | Plan with stage budgets, dependencies, what "done" means | plan.md | B approves plan and budget |
| 3 Prototype | Cheapest thing that tests the riskiest assumption | prototype in idea folder, re-score | Score steers: park / iterate / advance |
| 4 Build | Full build or full deliverable (deck, review, document) | build output, re-score | B gate before final build and before any money spend or external contact |
| 5 Review | Panel reviews the finished thing; final score by Fable; export to Drive | final gate page, exports/ | B accepts or sends back |

Iteration discipline: each round names its target dimension and expected change before running and logs the delta after. Stop after two rounds without meaningful delta. Each stage has an iteration budget set in the plan.

Human gates are fixed: no-go, any money spend, any external contact, final build. All other steering is done by the score.

## Prototype to product: definition of done

A prototype proves one risky assumption; a product is something a stranger can use tomorrow. The build playbook ships nothing as "done" until every line below is true, each with evidence in the idea folder.

| Area | Done means |
| --- | --- |
| Stack | Stack and hosting chosen from `tools/current.md`, with the reason logged in plan.md; the product gets its own repo under B's GitHub, separate from the loop |
| Environment | One-command setup from a clean machine (`make setup` or equivalent); `.env.example` documents every key |
| Tests | Automated tests for the core flow and for every bug fixed during review; CI runs them on every push |
| Security | Secrets never in code; auth, input validation and rate limits in place where the product takes outside input |
| Deployment | Deployed to a real URL on the chosen host with a rollback path; domain and SSL handled; cost per month written down |
| Data | Backups and a stated retention rule for anything users create; DSGVO/privacy notes where EU users are possible |
| Monitoring | Uptime check and error alerting, both pointing at B |
| Docs | README for operators, a one-page user guide, and a handover note: how to run, pay for, and shut it down |
| Review | Panel reviewed the live product, not screenshots; final score by Fable; open items listed in Known unknowns |

Money spend, domains, hosting sign-ups and any external contact are human gates: the plan names them and B approves each before it happens.

## Playbooks

Triage picks exactly one. Each playbook defines what each stage means, its two catalogue scoring dimensions, and its fixed panel seats.

| Playbook | Use when | Prototype means | Catalogue dimensions |
| --- | --- | --- | --- |
| build | Software, apps, automations, agents | Working slice of the riskiest feature | reliability, adoption friction |
| business | Ventures, market entries, Big-Four-style opportunity reviews | One-page model + 5 customer signals | market evidence, unit economics |
| research | Questions, comparisons, due diligence | Annotated source map | source quality, decision clarity |
| create | Creative platforms, formats, content, campaigns | A sample of the thing | originality, audience fit |
| improve | Changes to an existing system, process or project | Before/after on one case | time saved, breakage risk |
| \_meta | No playbook fits | Draft the missing playbook, run it once, submit it for B's approval | — |

## Adversarial panel

One panel, one round per scoring point. Seats review independently (each a subagent with no sight of the others), then objections are listed and must be resolved or explicitly accepted before the score counts. One seat is always the skeptic.

| Playbook | Fixed seats | Plus from triage |
| --- | --- | --- |
| build | security, user, maintainer, cost hawk, skeptic | 1–2 idea-specific |
| business | investor, operator, customer, lawyer, skeptic | 1–2 idea-specific |
| research | domain expert, methodologist, decision-maker, skeptic | 1–2 idea-specific |
| create | audience, critic, producer, rights/IP, skeptic | 1–2 idea-specific |
| improve | current owner, downstream user, ops, skeptic | 1–2 idea-specific |

Protocol: each seat gets the brief, the stage output and its persona only; returns at most one page: strongest objection, second objection, what would change its mind. Panel critiques; the main agent scores. Seats run on Fable 5.1.

## Scoring and gating

Five dimensions, each scored 1–10 from a binary checklist with evidence first and the number derived last. Three are universal; two come from the playbook's catalogue entry, which carries anchored examples for a 2, a 5 and an 8 so scores mean the same thing across ideas.

| Dimension | Type | Question it answers |
| --- | --- | --- |
| Value | universal | How much does this matter if it works? |
| Feasibility | universal | Can it actually be done with what we have? |
| Effort | universal | What does it cost in time, tokens, money? (inverted) |
| Catalogue 1 | per playbook | e.g. improve → time saved |
| Catalogue 2 | per playbook | e.g. improve → breakage risk |

Rules:

- The rubric is versioned; a score always names the rubric version it was made under.
- Every iteration re-scores and logs the delta against the previous round — a 4 can become an 8, and the log shows why.
- Score steers the job: below the park threshold → park; between → iterate on the weakest dimension; above the advance threshold → advance. Thresholds live in `system/gates.md` and are tuned from B's gate answers.
- Final scoring at Review is done by Fable 5.1.

Gate page (one page, always the same shape): verdict, score with deltas, three reasons, the killer risk, the recommended next step, the Drive link, and one to three calibration questions the system wants B to answer. B judges the reasoning, not the domain.

## Token discipline

Quality bar first, budget second: triage sets what "good enough" means for this idea, then estimates tokens per stage. The plan is re-costed at every stage end so it always lands; B approves the estimate before any expensive stage.

The eleven techniques, all mandatory in `system/token-discipline.md`:

1. Executive learnings only — every run reads `learnings/executive.md` (≤ 50 lines), never `full.md` unless a task names it.
2. `progress.md` is the sole state — every iteration starts with fresh context and reads it; no long-running conversation.
3. Cheapest-method ladder — try the cheap method (grep, script, cached source) before a model call, and the cheap model before the expensive one.
4. Stage-scoped playbook loading — a run loads only the playbook section for its current stage.
5. Hard output caps — every artifact has a line limit; the panel seat page is one page; the gate page is one page.
6. Write once, reference by path — never paste a file's content into a prompt when a path will do.
7. Model tiering — see Model policy.
8. Budget line per plan — `plan.md` carries tokens planned vs spent per stage; `run.sh` enforces it with `--max-budget-usd` and `--max-turns` on every headless call, so an overrun stops the run and triggers a re-plan, not a silent continue.
9. Subagents as context sinks — research and panel seats run as subagents; only their summaries return to the main loop.
10. Minimal MCP servers — a run loads only the servers its stage needs; loaded schemas cost 50–70k tokens a session.
11. Plan mode before execution — every build stage starts in plan mode and executes only an approved plan.

## Model policy

B is on the Max plan. The spec fixes the principle only; the concrete model per step lives in `tools/current.md` with an as-of date, and `run.sh` passes it with `--model`. This spec never names a model version again — that is what made rev 1 stale.

| Tier | Work | Starting mapping (22 Oct 2026, owned by `tools/current.md`) |
| --- | --- | --- |
| Mechanical | Triage, file housekeeping, condensing learnings, exports, scout daily pass, control room | Sonnet 5.5 |
| Workhorse | Research, planning, prototyping, building, scout weekly research | Opus 5.5 |
| Judgment | Panel seats, final scoring at Review | Fable 5.1, capped at 50% of the weekly limit |

Haiku 5.5 is current generation (rev 1 was wrong on this). It is not in the starting mapping, but the scout tests it once on triage and housekeeping; if it holds the quality bar it earns the mechanical tier on cost.

The tooling scout may propose a model change to `tools/pending-swaps.md`; it never changes a running project's model.

## Tooling scout

A separate loop, `scout.sh`, keeps the pipeline on the best current tools without ever touching a running project.

- `tools/current.md` names the tool per pipeline step with an as-of date and the source that justified it.
- Daily (Sonnet): condense new learnings from finished runs into `learnings/full.md`, then refresh `executive.md`.
- Weekly (Opus): research the sources in `tools/sources.md` against `tools/criteria.md`; any tool or model that beats the current one on the criteria goes to `tools/pending-swaps.md` with evidence and dates.
- B approves swaps at a gate page; approved swaps apply to new ideas only.

## Learnings

Two files, both size-capped, both maintained by the scout's daily pass.

| File | Cap | Who reads it | What goes in |
| --- | --- | --- | --- |
| `learnings/executive.md` | 50 lines | Every run, every time | Rules that changed an outcome: what to always do, never do, and which tool for which step |
| `learnings/full.md` | 250 lines | Scout, and a run that names it | Dated entries from finished ideas: what worked, what failed, score deltas, token spent vs planned |

Condensing rule: when `full.md` passes 250 lines, the oldest entries are merged into one dated summary line each; nothing is deleted without a summary.

## Portability and backup

Portable by design, so moving to a VM is a re-launch, not a rebuild:

- Everything lives in the repo; nothing on Drive, nothing in `~/`, nothing in app settings.
- Secrets in one `.env` (git-ignored), documented by `.env.example`.
- All paths relative to the repo root; no hard-coded Mac paths.
- Scheduling via `cron`-style entries documented in README, not via Mac-only tools.

Backup, belt and braces: GitHub is the mirror; the full history also sits on the Mac. `backup.sh` writes a daily `git bundle` to a Drive folder, so the repo survives a GitHub outage and can be restored from Drive alone.

Moving to a VM (≈ 1 hour): install Claude Code, clone the repo, copy `.env`, log in with the Max account, start the control-room session with Remote Control on, add the cron entries. Open: VM provider and location — not decided.

## Build order

Claude Code builds the system from this spec in this order; each step has an acceptance check before the next starts.

0. Control-room round-trip test (≈30 min, before anything is built) — start `claude --rc "Control room"`, enable push in `/config`, have it ask one `AskUserQuestion`; check: the iPhone receives a push, the answer arrives in the session, and after closing the lid for five minutes the session reconnects. If push fails, switch the design to Channels (Telegram) before step 1.
1. Repo skeleton, `CLAUDE.md`, `.env.example`, ground rules, token discipline, `tests/probe-01.sh` — check: a fresh headless run (`claude -p`) on a 3-line brief whose answer depends on one decision-driving fact (a) cites ≥3 dated sources for it, (b) ends with a Known unknowns section, (c) writes kill criteria before any research line, (d) stops at the validate gate. Four greps, no judgment call. Reciting the rules is not the check.
2. Templates and `new-idea.sh` — check: a brief becomes a correctly named idea folder with IDEA.md and progress.md.
3. Triage + the five playbooks + `_meta` — check: five sample briefs land in the right playbook with kill criteria and a budget line.
4. Panel archetypes + protocol as subagents — check: one validate stage produces a panel.md with independent seats and resolved objections.
5. Scoring rubric v1 + gate page + `run.sh` loop — check: one idea runs validate → gate with a one-page gate in `gates/`.
6. Drive inbox/outbox exports, `gates/INBOX.md`, the control-room `/loop`, the `UserPromptSubmit` fallback hook and the `NN.decision.md` release — check: a gate written by a headless job appears in the Claude app chat with its Drive link, the iPhone is pushed, B answers from the phone, and the job advances on the decision file.
7. Scout, learnings condensing, `backup.sh` — check: a daily run produces a bundle on Drive and an updated executive.md.
8. Run three real ideas end to end on the Mac, tune thresholds from B's gate answers — check: B's reported effort per gate is under five minutes.

Known unknowns: whether the control-room `/loop` holds its cadence over days without drift or token creep (measure in step 8); token cost of the idle control room per day; whether `FileChanged` fires on an idle session (would allow replacing the loop — test opportunistically, not blocking); the VM choice.

Resolved in rev 2 (Claude Code docs, 22 Oct 2026): Remote Control pushes to the iPhone when an action is required; it reconnects after sleep if the process survives; hooks cannot watch for new files, so delivery uses a loop plus a prompt hook; `--model`, `--max-budget-usd`, `--max-turns` exist for headless runs.

## Sources

- Hooks reference — https://code.claude.com/docs/en/hooks.md
- Remote Control — https://code.claude.com/docs/en/remote-control.md
- Mobile app — https://code.claude.com/docs/en/mobile.md
- Headless mode — https://code.claude.com/docs/en/headless.md
- CLI reference — https://code.claude.com/docs/en/cli-reference.md
- Channels (research preview) — https://code.claude.com/docs/en/channels
