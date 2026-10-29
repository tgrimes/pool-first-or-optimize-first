# Status

| | |
|---|---|
| Workflow version | 0.2.1 (2026-10-28) |
| Project | Pool First or Optimize First? Cutoffs from Multiply Imputed Biomarker Data |
| Package | micutoff |
| Stage | 2, piloted-fail |
| Open stop | Stop at the end of stage 2: the user reads `pilot/pilot-report.html` and decides on the failed pilot: a revised proposal and a re-pilot in `pilot-b/`, a re-scope (a revised proposal and a re-pilot), or a drop |
| Last update | 2026-10-29 |

The Stage row reads "stage number, state". The states a stage can be in:

| Stage | States |
|---|---|
| 1. Idea review | `1, reviewing`; `1, proposal at stop 1`; `1, Zotero check`; `1, proposal final` |
| 2. Pilot | `2, spec`; `2, pilot running`; `2, piloted-pass`; `2, piloted-fail`; `2, piloted-close-call`; `dropped (reason)` |
| 3. Manuscript | `3, design stop`; `3, drafting`; `3, draft at stop`; `3, revision round N`; `3, settled`; `3, production run`; `3, final` |
| 4. Background report | `4, in progress`; `4, report at stop`; `4, done` |
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
