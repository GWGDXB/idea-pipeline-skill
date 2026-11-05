# Executive learnings (≤ 50 lines — every run reads this)

Rules that changed an outcome. Maintained by the daily scout from `full.md`. Each line carries its origin: [design] = from BUILD.md reasoning, not yet confirmed by a run; [run <id>] = observed in that idea.

## Always
- [design] Write kill criteria before the first search; criteria written after research fit the findings instead of testing them.
- [design] One subagent per decision-driving fact; return only its one-page summary. Raw search results in the main context are the largest avoidable token cost.
- [design] Cite with a date. Undated claims get re-checked by the panel and cost a round.

## Never
- [design] Never paste file contents into a subagent prompt. Pass the path.
- [design] Never read another idea's folder, even "for comparison".
- [design] Never let a panel seat see another seat's page before writing its own.

## Tool for which step
- [design] Research: WebSearch to find, WebFetch to read the primary source. Vendor pages are background, never decision-driving.
- [design] Scoring: tick the checklist with evidence first; derive the number last.

## Known unknowns
- No idea has finished the loop yet. Every line above is [design]; the daily scout replaces or confirms them with [run <id>] evidence as it arrives.
