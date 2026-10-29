# Status

| | |
|---|---|
| Workflow version | 0.2.4 (2026-10-29) |
| Project | Pool First or Optimize First? Cutoffs from Multiply Imputed Biomarker Data |
| Package | micutoff |
| Stage | 3, revision round 1 |
| Open stop | None while the round runs: issue C1 of the background report (the code fix, the reruns of the quick run and the application, the re-render); the user is still reading the report and `background/issues.md` |
| Last update | 2026-10-29 |

The Stage row reads "stage number, state". The states a stage can be in:

| Stage | States |
|---|---|
| 1. Idea review | `1, reviewing`; `1, proposal at stop 1`; `1, Zotero check`; `1, proposal final` |
| 2. Pilot | `2, spec`; `2, pilot running`; `2, piloted-pass`; `2, piloted-fail`; `2, piloted-close-call`; `dropped (reason)`; `parked (reason)` |
| 3. Manuscript | `3, design stop`; `3, drafting`; `3, draft at stop`; `3, revision round N`; `3, settled` (then stage 4 runs); `3, production run` (after `4, done`); `3, final`; after a dropped or parked pilot, `3, memo`, then `dropped (memo at manuscript/manuscript.html)` or `parked (memo at ...)` |
| 4. Background report | `4, in progress`; `4, report at stop`; `4, done`; it runs between `3, settled` and `3, production run` |
| 5. Mock review | `5, round N at stop`; `5, round N responses`; `5, complete after N rounds` |
| 6. Slides, 7. Poster | `6, in progress`; `6, at stop`; `6, done`; the same for 7 |
| 8. Publish | `8, exported`; `8, verified` |

## Stage record

One line per stage boundary, newest last: the date, the stage reached, the path of the deliverable the user reads, and the stop that is open. The agent writes the line when it reaches a stop; the user's answer is the next message in the conversation, and the agent records the decision in the stage's log.

| Date | Stage | Deliverable | Open stop |
|---|---|---|---|
| 2026-10-28 | 1, proposal at stop 1 | `proposal.md` (log: `log/01-idea-review.md`) | Stop 1: the user reviews the proposal, answers the open questions, and adds the Zotero items |
| 2026-10-28 | 1, Zotero check | `manuscript/citations.csv` (faults and missing items: `log/01-idea-review.md`, step 9) | Stop 2: two items missing, record faults to fix |
| 2026-10-28 | 1, proposal final | `proposal.md` | none: the user declared the proposal final; stage 2 starts in a new session |
| 2026-10-29 | 2, piloted-fail | `pilot/pilot-report.html` (verdict: `pilot/results/verdict.csv`; decisions: `pilot/decisions.md`; spec: `project-spec.md`; log: `log/02-pilot.md`) | The pilot stop: the user decides between a revised proposal with a re-pilot, a re-scope, and a drop |
| 2026-10-29 | 2, piloted-close-call | `pilot-b/pilot-report.html` (re-pilot of the re-scoped proposal, `proposal.md` section 12; verdict: `pilot-b/results/verdict.csv`; decisions: `pilot-b/decisions.md`; spec: `project-spec.md`; log: `log/02-pilot.md`) | The re-pilot stop: the user decides the close call, and reviews the re-scope and its pass rule, which were not shown before the run |
| 2026-10-29 | 2, piloted-close-call | `pilot-c/pilot-report.html` (pilot-c, `proposal.md` section 13; verdict: `pilot-c/results/verdict.csv`; decisions: `pilot-c/decisions.md`; spec: `project-spec.md`; log: `log/02-pilot.md`) | The pilot-c stop: the user decides the close call, and reviews pilot-c's pass rule, which was not shown before the run |
| 2026-10-29 | 2, piloted-pass | `pilot-c/pilot-report.html` | none: the user read pilot-c's close call as a pass; stage 3 waits for the user's word, with three design questions for the protocol (`log/02-pilot.md`, D-S8) |
| 2026-10-29 | 3, drafting | `log/03-manuscript.md`, section "Step 2: references" (the three lists) | Step 2, references: the user adds the NHANES data items, attaches or fixes four PDFs, completes one record, and corrects ten record fields |
| 2026-10-29 | 3, design stop | `log/03-manuscript.md`, section "3.2 The design proposal" (the Introduction's purpose draft in `manuscript/manuscript.qmd`) | The design stop: the user approves or changes the design; `protocol.md` follows |
| 2026-10-29 | 3, draft at stop | `manuscript/manuscript.html` (draft mode, quick run of 100 replicates per cell; qmd `manuscript/manuscript.qmd`; log `log/03-manuscript.md`; protocol `protocol.md`) | The first draft: the user comments in revision rounds or declares the draft settled; seven `[TO CONFIRM]` and ten `[CITE]` markers are open |
| 2026-10-29 | 3, settled | `manuscript/manuscript.html` (the first draft, 375b006) | none: the user, "I have no comments at this time", then asked for the background report on this version before the production run (workflow 0.2.4 order) |
| 2026-10-29 | 4, report at stop | `background/background.html` (issues: `background/issues.md`; log: `log/04-background-report.md`) | The report's stop: five substantive issues send the manuscript to a stage 3 revision round before the production run (about 12 hours at 2,000 replicates on seven workers) |
