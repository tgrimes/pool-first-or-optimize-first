# Rules for every stage

These rules apply in every stage. A stage file may add rules; it may not remove one. Where a stage file and this file disagree, this file wins, and the disagreement is a lesson for `CHANGELOG.md`.

## 1. Stops and status

- Every stage ends at a stop with one deliverable the user reads. No stage starts itself; the user's message starts it.
- `STATUS.md` names the stage and the open stop. The agent updates it when it reaches a stop and when a stop is answered. On any message, the agent reads `STATUS.md` first, then the stage file it names, then the stage's log.
- Within a stage, the stops the stage file marks are real stops: the agent returns what the stop asks for and waits. If the user has switched the stops off for a run, the agent decides at each one, records the decision and its reason in the stage's log under "Decisions made in place of a stop", and marks in the deliverable what a user should look at.
- When a stop has been answered by a ruling, the agent applies the ruling. If the ruling's stated reason turns out to be wrong, the agent keeps the ruling, says so in the log with a dated note, and marks it in the deliverable.
- The user may change at any stop. Every user is treated the same, and nothing in a deliverable or a log names the user.

## 2. Sources

- Zotero is the only source for anything cited in a deliverable from the proposal onward. A citation is an item in the library, read through the connector, with the passage that supports the claim recorded in `manuscript/citations.csv` (started at the proposal stage) and the date it was read. A citation that only names a method or a dataset is marked `definitional`.
- Searching the literature (PubMed, bioRxiv, Consensus, the browser) is allowed only where a stage file says so (the idea review, the mock review's first reviewer). Every search is logged with its query, source, and date. Nothing found is relied on until it is in Zotero with full text; until then it is listed for the user to add.
- Nothing from memory. A fact about the literature or about a dataset points at a file or a page the agent opened. An identifier (DOI, accession) is one the agent saw, never one it reconstructed.
- A fault in a Zotero record (a missing DOI, a lowercased journal, a cut author list, a date in the pages field) is reported to the user with the value to enter, and never patched in a bib.
- If the Zotero connector is down, the agent says so before anything else: restart the server in Zotero's plugin pane and confirm `curl http://127.0.0.1:23120/ping` answers `pong`; in the session, reconnect the `zotero-mcp` server.

## 3. Numbers

- Every number in the manuscript, the background report, the slides, and the poster is computed from files in `results/` at render time, through `prov()` and the other helpers, and carries the label of the run that produced it (`pilot`, `quick`, `production`). Nothing is typed.
- Every analysis script writes its run file (`results/run_info.rds`, or `results/<name>_run_info.rds` for a second script) and `sessionInfo()`; a Python script writes the same fields to a JSON file.
- A simulated rate, bias, or coverage is reported with its Monte Carlo standard error. A difference is called nonzero only when it exceeds about three Monte Carlo standard errors; otherwise it is marked.
- A finding stated in prose is shown in a table or figure, and no cell that supports a finding is dropped from a display; a cell where a method misbehaves gets its own row, panel, or table.
- A simulation study always plans power, not only type I error: for every method whose type I error is controlled (under about 10% for a test at 5%), cells with a true effect whose levels run from low power to about 80%, calibrated with a few low-replicate cells, with the real data placed on that gradient. Every varied factor runs from a small effect to a large one, and the application places the real data on the gradient.

## 4. Writing

- Plain language first, then the formal statement, with full precision kept.
- One idea per sentence, in a simple structure. The reader's time is balanced against the reader's burden: a simple topic takes one sentence, a complex one up to three simple sentences that build on each other, never one sentence that packs them together and never a long preamble.
- Why before what. A sentence that leaves the reader asking why, followed by a description, loses the reader.
- Keep the paragraph's subject rather than introducing another to carry a fact about it ("these methods were developed to", not "their authors' aim was to").
- No claim without a source, the first sentence included. No em or en dashes. The Oxford comma. No bold lead-ins outside an abstract with required headings. No footnotes in a manuscript (a report may use them to define a term). "We", never "I".
- Keep estimand, estimator, statistic, and limit distinct. Say what "trustworthy", "safe", or "valid" refers to. No workflow vocabulary in a deliverable meant for readers outside the project (harness, pilot, card, worker, quick run, spec, the report, too small to matter).
- Delete on sight: considerably, dramatically, enormously, exceptionally, extremely, highly, quite, remarkably, substantially, very, actually, basically, clearly, essentially, in fact, indeed, just, kind of, of course, really, simply, sort of, certainly, obviously, undoubtedly, important, interesting, notable, remarkable, considerable, major, minor, substantial. Justify or replace: apparently, arguably, can, conceivably, could, maybe, may, might, perhaps, potentially, presumably, probably, seemingly, likely, would, often, mostly, commonly, generally, typically, usually.
- A table of notation is never included. A design table with a reason column is welcome; its caption defines every label it uses and its cells read on their own.
- An abstract gives numeric results with their uncertainty for every claim.
- Every deliverable goes through at least one revision pass for clarity (stage 03, step 4) before the user reads it.

## 5. Environment

- R packages come from the project library (`renv::restore()`); Python from the project environment (`uv sync`). Nothing is installed outside them, and never through Homebrew, pyenv, or conda on the project's behalf. After a change to `DESCRIPTION` or `pyproject.toml`, snapshot and commit the lockfile.
- Parallel code uses PSOCK workers with the BLAS pinned to one thread in each; at most three cores at once, counting the workers. A background run is stopped with the task tool, never with `pkill`. Before restarting anything that looks dead, check `uptime` and the run's own log.
- Every R command runs from the project root or from `manuscript/`, where `.Rprofile` activates the library.
- No simulation runs before `protocol.md` is written, except a pilot's own pre-registered run.

## 6. Logs and feedback

- Every stage keeps a log in `log/<stage>.md` (stage 3's is `manuscript/drafting-log.md`, which the draft's banner reads; stage 2's decisions are in `pilot/decisions.md` with the process log in `log/02-pilot.md`): what was read, what was decided and why (decisions numbered D0, D1, ...), what was carried from where, what was unsure, and the time each step took.
- Every stage's log ends with "Process feedback": what in the stage file was unclear, could be simplified, or was missing, with times. The user folds accepted lessons into the stage file and `CHANGELOG.md`.
- When the user's comment on a deliverable states a general rule, the agent applies the comment and proposes the rule for the stage file; the user decides whether it is adopted.

## 7. Workers

- A stage may be run by the agent in the conversation (the coordinator) or delegated to a worker with a brief. A brief names the files to read, the rules, the decisions already taken, what to return, and the time box. A worker's report is a report, not proof: the coordinator verifies the files before relaying it.
- Workers do not install into the user's library, do not write outside the project, and do not edit the deliverables of earlier stages except where the stage file says a later stage may raise issues (the background report, the mock review).
- Two writers never touch the same files at once.

## 8. AI conduct

- Do not fabricate citations, numbers, or results. Say when something could not be verified.
- When asked for a derivation, also propose the numerical check that would catch an error in it.
- Flag scope creep against `proposal.md`, `project-spec.md`, and `protocol.md`.
- Explain first and fix second when asked why something is wrong.
- The user reviews every deliverable; the agent never marks a stop as answered on its own.
