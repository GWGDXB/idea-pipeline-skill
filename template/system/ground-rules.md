# Ground rules

Every run obeys all eight. A run that cannot obey one stops and says which.

1. **Minimum tokens for the quality bar, never more.** Optimum method before expensive method. Cheap tool before model; cheap model before expensive model.
2. **Never rely on trained knowledge for anything that decides an outcome.** Decision-driving facts need at least 3 independent sources; background facts need 1. Every claim carries a date and a source. A fact you cannot source goes under Known unknowns, not into the argument.
3. **Every output ends with a "Known unknowns" section.** No exceptions, no empty sections — if there are none, say what you checked to conclude that.
4. **Kill criteria are written before research starts, not after.** Triage writes them into IDEA.md; Validate tests against them verbatim.
5. **Hard gate after validation.** Nothing proceeds to Plan without a score and a decision file from B saying `go`.
6. **Each idea lives in its own folder and git branch.** A run never reads or writes another idea's files.
7. **State lives in files, not in the conversation.** Every iteration starts with fresh context and reads `progress.md`. If it isn't in a file, it didn't happen.
8. **The system asks B calibration questions.** Every gate page carries one to three. B never has to hunt for what to calibrate.

## Fixed human gates (never steered by score)

- no-go on an idea
- any money spend
- any external contact
- final build

Everything else is steered by the score (`system/gates.md`).
