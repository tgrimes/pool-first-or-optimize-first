[^pilot]: A pilot is a quick, small first run of a card's simulation, done before a project is assigned, to check that the idea is worth a student's time. It asks three questions: does the effect exist, is it large enough at realistic sample sizes, and is there an obvious fix or diagnostic?

[^card]: A card in `research-ideas.md` is a short description of one candidate project: the question, why it matters, the data, and the result of any pilot.

[^pf]: `piloted-fail` means at least one of the three pilot questions did not get a clear yes, so the card should not be assigned as written. `piloted-pass` means all three did.

[^worker]: An AI assistant session that ran the pilot, wrote the files this document is built from, and kept a log of its decisions.

[^cond]: A draft that applies only if the card is re-scoped as described. If the card stays as written, it is a record only.

[^harness]: A harness check tests the simulation code itself. It runs a setting where the correct answer is known from theory (for example, a t-test on balanced data should reject 5% of the time at level 0.05) and confirms the code reproduces it, so that a bug shows up as a wrong answer before any new result is trusted.

[^closed]: A closed form is a formula that gives the exact answer without simulation, so the simulation can be checked against it.

[^stress]: A stress case is a deliberately extreme setting used to see whether a method breaks. It is not meant to resemble the real data.

[^doublet]: A droplet that captured two cells and reads them as one, so its counts mix two cell states.

[^annot]: Annotation: labeling each cell as a monocyte, NK cell, and so on, usually by clustering its gene expression and matching known marker genes.
