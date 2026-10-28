# Stage 5: mock review

## Purpose

Put the settled manuscript through the review it would get at the target journal, from three reviewers with different habits, before it is submitted: one who reads for coherence and fit with the literature and knows when the work has been done before; one who distrusts every detail and derivation; and one who asks what more the paper could do. Then draft the responses and revisions the user decides on, and repeat until the user is satisfied.

## Inputs

- The rendered manuscript and supplement (`manuscript/manuscript.html`), and the target journal's profile from `workflow/journals/`.
- `workflow/reviewers/reviewer-1.md`, `reviewer-2.md`, `reviewer-3.md`: the three reviewers' instructions.
- `templates/review-report.md` and `templates/response.md`.
- For later rounds: the previous round's reviews and responses.

## Preconditions

- The manuscript is settled and the background report is done, with its issues resolved.
- The log is `log/05-mock-review.md`.

## Procedure

**1. The packet.** Make `review/round-1/` and put in it what a reviewer at the journal would get: the rendered manuscript, the supplement, and the journal's reviewer criteria from the profile. A reviewer does not get `proposal.md`, `project-spec.md`, the logs, or the background report. The packet is the same for all three.

**2. Three independent reviews.** Run the three reviewers as separate agents with no shared context and no sight of each other's output, each with its instruction file, the packet, and the review report template. Reviewer 1 may search the literature and read Zotero. Reviewer 2 may write and run code of its own to probe a claim (a small simulation, a recomputation from a formula), within a budget of about fifteen minutes of compute, and never reruns the manuscript's own analyses, which are tested already. Reviewer 3 may search for competing methods and datasets. Each returns `review/round-1/reviewer_N.md` in the template's form: summary, major comments, minor comments, recommendation with confidence. A reviewer's claim about the literature names the source it saw.

**3. The editor's summary.** Read the three reviews. Write `review/round-1/summary.md`: the comments grouped by theme with duplicates merged, each with its reviewers' numbers, and a triage table for the user with one row per comment and an empty decision column (address, rebut, defer). Say which comments, if any, contradict the manuscript's own evidence or the background report, with the file that shows it.

**Stop.** Return the three reviews and the summary. The user fills the decision column. Wait.

**4. Responses and revisions.** For each comment marked address: the change to the manuscript, made in a revision round of stage 3 (logged there under a dated "Revision from review round N" heading, with the revision pass applied); for each marked rebut: the reply with its evidence; for each marked defer: the reply saying what would be needed. Write `review/round-1/response.md` from the template: a point-by-point response in the order of the reviews, each reply quoting the comment, stating what changed and where, or why not. Render and check the manuscript; commit.

**5. Further rounds.** When the user asks, make `review/round-2/` with the revised manuscript and, for each reviewer, its own previous review and the response to it, not the others'. Each reviewer judges whether its comments were met and raises what the revision opened. Repeat steps 3 and 4. The stage ends when the user declares the review complete; `STATUS.md` records the number of rounds.

## Outputs

- `review/round-N/`: the packet, `reviewer_1.md`, `reviewer_2.md`, `reviewer_3.md`, `summary.md`, `response.md`.
- Revision rounds in `manuscript/drafting-log.md`.
- `log/05-mock-review.md`: the agents run, their budgets and time, the triage, process feedback.

## What to return at the stop

One message: the three recommendations; the major comments by theme with the reviewers' numbers; the comments that contradict the evidence, if any; the path to the summary and its triage table; what the coordinator was unsure of.

## Lessons

(None yet. This stage has not been run.)
