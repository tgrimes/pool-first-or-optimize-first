# Brief for a manuscript-drafting worker

You are drafting the initial manuscript for this project, whose repository root is the research compendium. Read `workflow/rules.md` and `workflow/03-manuscript.md` first; the stage file is the manual, and this brief only tells you the order of work and what to return at each stop. Then read `proposal.md`, `project-spec.md`, and `pilot/` (`preregistration.md`, `decisions.md`, the report, and the saved result files), and `manuscript/citations.csv` as stage 1 left it.

Rules that apply throughout:

- The project library is renv's: run `renv::restore()` after instantiating, install nothing outside it, and after any change to `DESCRIPTION` run `renv::install()` and `renv::snapshot()` and commit `renv.lock`. The Python environment is uv's: `uv sync`, `uv add` for a package, vendoring for scripts, as the compendium's `CLAUDE.md` says. Pin BLAS to one thread in parallel code. At most three cores at once, counting PSOCK workers; stop a background run with the task tool, never with `pkill`.
- Write nothing outside this repository except the Zotero collection named for the project. Never edit `idea.md`, `proposal.md`, `project-spec.md`, or anything in `pilot/`.
- Every number in the manuscript comes through `prov()` from `results/`. Never type a result.
- No em or en dashes anywhere, the Oxford comma, plain language before the formal statement, no first person singular, no workflow vocabulary in the paper.
- Nothing from memory: every citation is a Zotero item read through the connector, and every fact about the data or the literature points at a file or a page you opened.
- When something needs a decision, write a `[TO CONFIRM: ...]{.tc}` marker and go on; do not stop to ask, except at the three stops below.

## Order of work

**Step 0. Paper test.** Before writing anything, answer the seven questions in the README, each qualified by method and setting and pointing at the file that meets it. Keep them in a scratch note until step 1 creates `manuscript/drafting-log.md`, then write them there under `## Paper test` as a three-column table (step, answer, where), and make the log's opening paragraph a one-line status (the paper test in a sentence, and anything the run will not cover); the banner repeats that line. If the estimand, the formula, or the fix is missing, that line says so.

**Step 1. Promote the pilot.** Promote the pilot's script and code as the stage file says (the functions are already in `R/`; the acceptance test is a gated testthat test on a fixture copy of the pilot's summaries in `pilot/results/`). A method whose only implementation is Python is run through the compendium's uv environment (a package with `uv add`, scripts vendored into `inst/python/vendor/`, glue in `inst/python/<package>/` with pytest tests, an R wrapper in `R/`); if the environment cannot be built, it is drafted as planned with markers, and the decision is logged. Record in the log every assumption found in the pilot's code comments and decisions log, the acceptance test's result, and the test coverage you added for code paths the pilot did not run.

**Step 2. References.** Build the inventory as a table in the log (key, grade core or supporting, section, why, origin). Check Zotero availability by DOI and then by title. If the connector is unavailable, return at once with the single line "Zotero unavailable" and nothing else.

If the references step was run before, point the log at the existing inventory and checklist and go on to the rebuild. *Return at the first stop* with one message holding three lists: (1) available, with the count; (2) missing, grouped as "add the item", "attach the PDF", "complete the metadata", or "correct a field", each row with the full citation as known, the identifier, and the claim it is needed for; (3) record faults, each with the item, the field, and the value to enter. Then wait. When told the library is updated, re-check, build the bib with `build-bib.py`, start `citations.csv`, and create the Zotero collection.

**Step 3. Draft.** In this order, and record in the log what each section was carried from and what was written new.

1. The purpose draft of the Introduction and the claims list.
2. The design proposal: the factor table with levels and reasons, the application plan, the runtime from one timed cell per method, the performance measures by target, and the power cells, planned by default as the README says, naming any method left out of them with its type I error. *Return at the second stop* with the proposal as one table and one paragraph, and wait. On approval, write `protocol.md` from it.
3. The quick run: set the replicate count from the timing so the grid finishes well within an hour, run it in the background, run the application if its code exists, and confirm `results/run_info.rds` says `quick`.
4. Methods, the design section, Results, and Discussion, with the supplement skeleton for the proofs. Design levels through `lvl()`, results through `prov()`, ranges through `range_mcse()`; the journal's CSL named in the YAML; the AI-use statement placed where the journal's profile says. Write every attributing citation with the PDF open (the connector's `get_content` or `search_fulltext` on the item) and record the passage and the date in `citations.csv`; mark a citation that only names a method or a dataset as `definitional`. You may delegate the passage reading to other agents if each returns the quote, its location, and a verdict, and you spot-check a sample yourself and say so in the log. When a result contradicts a claim in the spec, state the fact in Results, interpret it with a guard in Discussion, and mark it with the spec's sentence quoted.
5. Revise the Introduction against the Results and Discussion; write the Abstract in the journal's headings.
6. If drafting turned up sources not in the inventory, run the availability check on them as one batch. *Return at the third stop* only if any is missing, with the same three lists.

**Step 4. Revise.** At least one revision pass for clarity as the README's step 4 says, recorded in the log under `## Revision pass`.

**Step 5. Render, check, prove.** Render in draft mode, run the checker, fix every error, answer every warning in the log. Finish the log. Clone to a scratch directory, run `renv::restore()` and `uv sync`, then the tests in both languages and `devtools::check()`, rerun the quick run, compare the summaries, render. If any of that fails, say so and do not hand over.

**If the stops are switched off for this run,** decide at each one, record the decision and its reason in the log under `## Decisions made in place of a stop`, mark in the draft what a person should look at, and carry on.

## What to return at the end

One message with: the paper-test status; the path to the draft HTML, the qmd, and the log; the counts of markers by kind; the list of `[TO CONFIRM]` markers with their sections; the Zotero fixes still open; the gap table; the warnings kept and why; and what you were unsure of. No summary of the paper's findings: the person reads the draft.
