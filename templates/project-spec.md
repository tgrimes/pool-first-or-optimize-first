# Project spec: [short title]

| | |
|---|---|
| Card | [ID and title from the idea file, if there is one] |
| Student | [name] |
| Supervisor | [name] |
| Written | [date] |
| Status | draft / handed off [date] / done [date] |

## How to use this form

Fill it in after the idea has passed its feasibility pilot, and not before. It takes two to three hours. The student gets it at the handoff meeting together with the dataset, so write it for someone who has two or three graduate statistics courses and some R, has never done research, and has an AI assistant.

The spec is the question and the design. It is not instructions for writing code. The student, with AI help, writes the code, and their time goes where AI is bad: choosing which factors to vary and why, noticing when a result is wrong, deciding what the application should show, and defending every choice. If a spec makes the first month about code, rewrite it.

Keep it to two to four pages. Each section ends with a note on what good looks like; delete those notes in the filled copy.

Before the handoff meeting:

- The pilot code runs from a clean clone of the project template on a machine other than yours.
- The dataset is downloaded, and the path or accession in section 5 is right.
- The reading in section 9 is sent, with its questions.
- The weekly one-on-one is on the calendar.

Save the filled copy as `project-spec.md` in the root of the project repository, next to `protocol.md`. This file stays blank.

Filled specs are private. Do not put them on a website, and keep the project repository private until the paper is submitted.

---

## 1. Question and why it matters

**Question (one sentence):** [Does procedure X do Y when condition Z holds?]

**Why it matters:** [What changes for a user of the procedure if the answer is yes. Two or three sentences.]

> **What good looks like.** The question names a procedure people use and a condition they meet in real data, and it can be answered yes or no, or with a number. "Does the mean-shift artifact of the LIONESS edge carry over to SSN edges, and does within-group standardization remove it?" is a question. "Study the properties of sample-specific networks" is a topic. The "why it matters" sentence is about the user, not the field: what would they do differently on Monday?

## 2. Mechanism we suspect

[One paragraph.]

> **What good looks like.** The paragraph says what the procedure converges to under the realistic condition, compared with what the user thinks it estimates, and writes the gap as a formula if one is known. It says when the gap is zero and what makes it large, because those two facts become the null cell and the factors in section 4. It also says what the student should expect to see if the mechanism is wrong. It is not a literature review: citations go in section 9.

## 3. Pilot

**Code:** [path in the repository, and the command that runs it]

**Plot:** [one figure, saved in `results/`, or pasted here]

**The three pilot answers:**

1. Does the effect exist? [yes or no, with the number]
2. Is it large enough to matter at realistic sample sizes? [the effect at the sample sizes in section 4]
3. Is there an obvious fix or diagnostic? [what it is, or "none yet"]

> **What good looks like.** The pilot is the smallest simulation that would show the effect if it exists, run for real, with the three answers in one line each and with numbers. It is the student's starting point, so it must run from a clean clone. If the answers are "yes, small, no", this is not a project yet. Do not assign it.

## 4. ADEMP skeleton

This becomes the student's `protocol.md`. Bullets are enough here; the student writes the full protocol in weeks 3 to 6 and presents it at lab meeting in week 6, before anything is run.

**Aims.** [Two or three questions with yes-or-no or numeric answers.]

**Data-generating mechanisms.**

- Factors varied, with levels: [sample size, balance, effect size, correlation structure, and so on]
- Factors fixed, and why: [each fixed factor with its reason]
- A cell where the answer is known: [a null, or a case with a closed form]

**Estimands.** [What each method is trying to estimate or test, defined without reference to any method.]

**Methods compared.** [The procedures, precisely enough to reimplement: statistic, reference distribution, number of permutations, software and version.]

**Performance measures.** [Level and power for tests; bias, empirical SE, and coverage for estimators.]

**Replicates and Monte Carlo SE target.** [R per cell, and the MCSE it gives for the measure that matters most. For a rejection rate near 0.05, about 1900 replicates give an MCSE of 0.005.]

> **What good looks like.** Every fixed factor has a reason, and the varied factors come from the mechanism in section 2, not from a list of everything that could be varied. The known-answer cell is there so that a bug shows up as a wrong answer. When balance varies, total N is held fixed, or the balance effect is confounded with a sample size effect. The estimand is defined before the methods, because in this group's work the estimand and the method's target often differ and the simulation exists to measure that difference. The MCSE target is a number, chosen before any run.

## 5. Application

**Dataset:** [name, accession or path, and where it lives on disk]

**Comparison:** [which groups, how many samples per group, which scale: counts, log-CPM, or intensities]

**What to show:** [the one thing the application should demonstrate]

> **What good looks like.** The dataset has been downloaded and opened by you before the spec is written, not just named. It is open data, autoimmune where possible and single-cell or spatial where possible; lupus is not required. "What to show" is a claim about the user's conclusion, for example "a comparison where the artifact changes which edges look different", not "run the method on the data". The application is there to show the effect matters in a real cohort. It is not a search for new biology.

## 6. Target journal

**Target journal:** [one journal]

**Fallback:** [one journal]

> **What good looks like.** The target is one of the student venues: BMC Bioinformatics, Biometrical Journal, Statistical Applications in Genetics and Molecular Biology, BMC Medical Research Methodology, Journal of Statistical Computation and Simulation, or PLOS ONE. Statistics in Medicine, Biostatistics, and JASA are the supervisor's venues, not student venues. Name the journal's word limit and its AI policy, because the disclosure in the paper follows that policy.

## 7. Milestones by week

The default schedule is below. Replace each line with the file the student hands in and the week it is due.

| Weeks | Default | This project |
|---|---|---|
| 1 to 2 | Review the project spec and the statistical background guides, with the most time on the guides that bear on the project. | [files and weeks] |
| 3 to 6 | Write `protocol.md` and the literature review, and keep working through the guides. Present the protocol at lab meeting in week 6. | [files and weeks] |
| 7 to 10 | Run the simulation study and the application, then write the full manuscript draft. Present the initial findings at lab meeting in week 10. | [files and weeks] |
| 11 to 20 | Review every table and figure in the manuscript, presenting revisions at the weekly lab meeting. | [files and weeks] |
| 21 to 25 | Revise the manuscript, run the final checks, and submit. | [files and weeks] |

The thesis or project report is the paper. Do not plan two documents.

> **What good looks like.** Every milestone is a file in the repository that someone else can open, not an activity. Each has a week. The protocol milestone includes the lab meeting where it is reviewed, and the manuscript milestone says which sections are drafted from the protocol already (the methods and simulation design should be nearly written by then).

## 8. Out of scope

The student must not add:

- [ ]
- [ ]
- [ ]

> **What good looks like.** This is the section advisors skip and the one that saves students. Write it before the meeting, by listing what a smart student with an AI assistant will be tempted to add: one more method or distance, a second dataset, the next sample-specific method after the ones in scope, a predictive model (not the research direction), an R package or software paper (software is a byproduct, not a publication), or a theory result beyond the closed form in section 2. Each item is a different project, not a missing section of this one. If the extension is already on the supervisor's list of project ideas, name it, so the student knows it is parked, not forgotten. When the student proposes something on this list, the answer is "later, as its own paper".

## 9. Reading

1. [Reference.] After reading, the student can answer: [question].
2. [Reference.] After reading, the student can answer: [question].
3. [Reference, optional.] After reading, the student can answer: [question].

> **What good looks like.** Two or three papers, not ten. The first introduces the procedure, the second shows a related critique or fix, and the third (if any) is background the student would otherwise skip. Each comes with a question that can only be answered by someone who read it, and the student answers them aloud in the third one-on-one. Add the relevant statistical background guides. Every reference is checked against the actual paper before it goes in.
