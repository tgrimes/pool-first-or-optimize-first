# Stage 2: project spec and pilot

## Purpose

Write the project spec from the final proposal, then run the pre-registered pilot that decides whether the idea survives: pass, fail, or a close call stated both ways. The pilot's code is written as package functions with tests from the first day, so that a pass carries straight into stage 3 with no port.

## Inputs

- `proposal.md`, final, with its pilot plan and pass criteria.
- `templates/project-spec.md` and `templates/pilot-report/`.
- `manuscript/citations.csv` as stage 1 left it.

## Preconditions

- The proposal is marked final in `STATUS.md`, and its open questions are answered.
- The recommended dataset is `verified`, or the pilot is a simulation only and the proposal says so.
- `renv::restore()` and `uv sync` have been run.

## Procedure

**1. The spec.** Fill `templates/project-spec.md` as `project-spec.md` from the proposal: the question and why it matters, the mechanism, the pilot (section 3 is this stage's plan), the ADEMP skeleton, the application, the target journal, the milestones, what is out of scope, and the reading with its questions. A decision the proposal left to the user carries a `[TO CONFIRM: ...]` marker. If writing the spec changes the pilot's pass criteria, **stop** and say why before running anything; otherwise go on.

**2. Pre-register.** Before any run, write `pilot/preregistration.md`: the three pilot questions; the pass rule with numbers (what each answer must show, in which cells, beyond how many Monte Carlo standard errors); the design of the first simulation (factors, levels, methods, measures, replicates, seeds); the cells with a known answer; the time box (an hour of compute by default); and what will be reported whatever the outcome. Commit it, so that its timestamp precedes every result.

**3. Code.** Every function goes in `R/` with roxygen comments and a test, and the data-generating mechanism, the methods, and the summaries are functions. Known-answer checks (the null cell, a closed form, a code-identity check against a literal implementation) are tests in `tests/testthat/`. The pilot script is `pilot/pilot.R`: it calls `devtools::load_all()`, builds the design table, gives each cell its own seed, runs the cells (PSOCK workers with the BLAS pinned, at most three cores), saves per-replicate output and per-cell summaries with their Monte Carlo standard errors to `pilot/results/`, writes `pilot/results/run_info.rds` with `run = "pilot"`, and saves `sessionInfo()`. A method whose only implementation is Python goes through the uv environment as `CLAUDE.md` says. Time one cell of each method at the largest sample size before the run, and set the replicate count from the time box. `devtools::test()` and `devtools::check()` run clean before the run.

**4. Run.** Run the pilot in the background. If the first run is stopped and restarted, say so and why in the decisions log. The application part of the pilot, if the proposal has one, runs the same way with its own run file.

**5. Verdict.** Answer the three questions with numbers against the pre-registered rule. A close call is stated both ways, with the reading that passes and the reading that fails. The verdict is a table in `pilot/results/` written by a script (`pilot/verdict.R`), not a judgment typed into the report.

**6. Decisions log.** `pilot/decisions.md`: D0, the literature pass (a pointer to the proposal's prior-work section and anything read since); D1, the status call with both readings; then every decision taken while building and running (what, the alternatives, why, what the user should check), each pointing at the file that holds its numbers; a final section on what was not done. Nothing in the log is a number that is not in a saved file.

**7. The report.** Copy `templates/pilot-report/pilot-report-template.qmd` to `pilot/pilot-report.qmd` and fill it as its README says; render; run its checker; look at the HTML. Every number comes from `pilot/results/`.

**8. Status.** Write `piloted-pass`, `piloted-fail`, or `piloted-close-call` in `STATUS.md` with the date, and the stage record line.

**Stop.** Return the report, the verdict, the decisions log, and the spec. The user decides: pass, and stage 3 starts; fail, and the user revises the proposal (a dated revision section at its end) for a re-pilot in `pilot-b/`, or drops the idea (`STATUS.md` says `dropped`, with the reason); or a re-scope, which is a revised proposal and a re-pilot.

## Outputs

- `project-spec.md`.
- `pilot/preregistration.md`, `pilot/pilot.R`, `pilot/verdict.R`, `pilot/results/`, `pilot/decisions.md`, `pilot/pilot-report.qmd` and `.html`.
- Functions in `R/` with tests.
- `log/02-pilot.md`: what was read, the timing, the run, the decisions by number, the process feedback.

## Checks before the stop

- The pre-registration's commit precedes every file in `pilot/results/`.
- The tests and `devtools::check()` pass; the known-answer tests exist for every closed form the pilot uses.
- Every number in the report and the decisions log is in a saved file.
- The verdict follows the pre-registered rule, or the deviation is stated and marked.
- The report's checker reports no errors.

## What to return at the stop

One message: the status; the three answers with their numbers; the pass rule they were judged against; the close-call reading if there is one; the paths to the report, the verdict file, the decisions log, and the spec; the runtime and the replicate count; the spec's open markers; and what the agent was unsure of.

## Lessons

(None yet.)
