# Catalogue scoring dimensions (rubric v1)

Two per playbook. Same derivation as universal: checklist with evidence → score. Anchors show what a 2, a 5 and an 8 look like so scores mean the same across ideas.

## build → reliability

Anchors: **2** — works on B's machine when B watches it. **5** — runs unattended for a week with one manual fix. **8** — tests, CI, monitoring and alerting; a stranger could run it from the README.

- [ ] Automated tests for the core flow
- [ ] CI runs on push
- [ ] Error alerting points at B
- [ ] Restart/rollback documented
- [ ] Handles the three most likely bad inputs (listed)
- [ ] Secrets outside code
- [ ] Ran unattended ≥ 7 days or equivalent evidence
- [ ] Panel reliability objections resolved

## build → adoption friction (inverted: 10 = frictionless)

Anchors: **2** — needs B to explain it. **5** — one-page guide, one sign-up. **8** — works on first contact with no instructions.

- [ ] One-command setup
- [ ] First useful result within 5 minutes of start
- [ ] No new account required, or one
- [ ] Fits an existing habit/tool of the user
- [ ] User guide ≤ 1 page
- [ ] Reversible (user can leave without loss)
- [ ] Tested on one person who is not B
- [ ] Panel user objections resolved

## business → market evidence

Anchors: **2** — top-down TAM from a report. **5** — bottom-up count plus comparable prices. **8** — five dated customer signals plus two comparables' actual revenue.

- [ ] Bottom-up customer count with source
- [ ] Price today for the alternative, sourced
- [ ] ≥3 independent sources on demand
- [ ] ≥2 comparable businesses with dated performance data
- [ ] 5 customer signals (prototype) collected
- [ ] Trend direction sourced
- [ ] Regulatory exposure sourced
- [ ] Panel market objections resolved

## business → unit economics

Anchors: **2** — margin asserted. **5** — one-page model with sourced inputs. **8** — model stress-tested, break-even and sensitivity shown, inputs from comparables.

- [ ] Revenue per unit sourced
- [ ] Cost per unit sourced (incl. labour at real rates)
- [ ] Fixed costs listed with sources
- [ ] Break-even volume computed
- [ ] Sensitivity on the one critical number
- [ ] Cash timing considered
- [ ] Comparable's margins as a check
- [ ] Panel economics objections resolved

## research → source quality

Anchors: **2** — blogs and vendor pages. **5** — mixed primary/secondary, some undated. **8** — primary sources, independent, dated, graded, disagreements handled.

- [ ] Every decision-driving fact has ≥3 independent sources
- [ ] Sources graded A–D with criteria stated
- [ ] Primary sources preferred and identified
- [ ] Independence checked (not one primary repeated)
- [ ] All sources dated; nothing > 24 months without a note
- [ ] Vendor material labelled as such
- [ ] Conflicts between sources resolved explicitly
- [ ] Methodologist objections resolved

## research → decision clarity

Anchors: **2** — a summary. **5** — a recommendation with caveats. **8** — the decision, confidence, what would change it, and what to do Monday.

- [ ] Question restated as a decision
- [ ] One recommendation
- [ ] Confidence stated with reason
- [ ] What would change the recommendation
- [ ] Trade-offs made explicit
- [ ] Next action named
- [ ] Fits on one page before appendices
- [ ] Decision-maker objections resolved

## create → originality

Anchors: **2** — a clone with a twist. **5** — a known format in a new combination. **8** — a recognisable new idea a critic would name.

- [ ] Three closest existing things named with dates
- [ ] The one new idea stated in a sentence
- [ ] A critic persona could not name a direct precedent
- [ ] Not dependent on third-party IP
- [ ] Format survives being described in one line
- [ ] Sample made (prototype)
- [ ] Sample shown to one non-B person
- [ ] Critic objections resolved

## create → audience fit

Anchors: **2** — "people who like X". **5** — a defined audience where they already are. **8** — audience evidence, channel fit, and a sample they reacted to.

- [ ] Audience defined (who, where, how many — sourced)
- [ ] Channel named with its rules checked
- [ ] Comparable formats' performance sourced
- [ ] Hook within the first 10 seconds/lines
- [ ] Cadence B can sustain stated
- [ ] Reachable without paid acquisition
- [ ] Sample reaction from ≥1 audience member
- [ ] Audience objections resolved

## improve → time saved

Anchors: **2** — "feels faster". **5** — baseline measured, after estimated. **8** — before/after measured on real cases, annualised.

- [ ] Baseline measured (how, when)
- [ ] After measured on ≥1 real case
- [ ] Frequency sourced (how often it happens)
- [ ] Annual saving computed
- [ ] Who saves the time named
- [ ] Quality of output unchanged or better (checked)
- [ ] Adoption effort subtracted
- [ ] Owner objections resolved

## improve → breakage risk (inverted: 10 = safe)

Anchors: **2** — changes a live system without rollback. **5** — rollback exists, dependents known. **8** — tested, reversible in minutes, dependents informed, blast radius small.

- [ ] Rollback documented and tested
- [ ] All dependents listed
- [ ] Output format unchanged where required
- [ ] Change tested on a copy first
- [ ] Monitoring tells us if it broke
- [ ] Blast radius stated
- [ ] No irreversible step
- [ ] Ops objections resolved
