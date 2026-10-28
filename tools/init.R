# tools/init.R
# Sets up a project created from the research-workflow template, in place.
#
#   Rscript tools/init.R <packagename> --title "Short title" --author "Name"
#          [--coauthor "Name"] [--email address] [--affiliation "Department, University"]
#          [--no-python]
#
# It names the R and Python packages, sets the authors in DESCRIPTION, LICENSE, README.md, and the
# manuscript skeleton, removes the template's example function, test, script, help pages, and Python
# example, writes placeholder tests so that R CMD check and pytest pass from the first commit, and
# fills the headers of README.md and STATUS.md. Run it once, from the project root, before
# renv::restore(). Anything not given stays a [FILL] slot.

args <- commandArgs(trailingOnly = TRUE)
usage <- "usage: Rscript tools/init.R <packagename> --title \"Short title\" --author \"Name\" [--coauthor \"Name\"] [--email ADDRESS] [--affiliation \"...\"] [--no-python]"
if (length(args) < 1) stop(usage)
pkg <- args[1]
if (!grepl("^[A-Za-z][A-Za-z0-9]*$", pkg)) stop("package name must start with a letter and contain only letters and digits (the Python package shares it)")
opt <- function(flag, default = NULL) {
  i <- match(flag, args); if (is.na(i)) return(default)
  if (flag == "--no-python") return(TRUE)
  args[i + 1]
}
title <- opt("--title", "[FILL: short title]")
author <- opt("--author", "[FILL: first author]")
coauthor <- opt("--coauthor", "[FILL: second author]")
email <- opt("--email", "[FILL: email]")
affiliation <- opt("--affiliation", "[FILL: affiliation]")
no_python <- isTRUE(opt("--no-python", FALSE))
root <- normalizePath(".")
if (!file.exists(file.path(root, "DESCRIPTION")) || !dir.exists(file.path(root, "workflow"))) {
  stop("run this from the project root (DESCRIPTION and workflow/ must be there)")
}
if (!grepl("projecttemplate", readLines(file.path(root, "DESCRIPTION"), warn = FALSE)[1])) {
  stop("DESCRIPTION no longer names projecttemplate: init.R has already been run")
}

esc <- function(s) gsub("\\\\", "\\\\\\\\", s)
sub_file <- function(path, pattern, replacement, fixed = FALSE) {
  if (!file.exists(path)) return(invisible(FALSE))
  x <- readLines(path, warn = FALSE)
  x <- gsub(pattern, if (fixed) replacement else esc(replacement), x, fixed = fixed, perl = !fixed)
  writeLines(x, path); invisible(TRUE)
}
is_fill <- function(s) grepl("^\\[FILL", s)
split_name <- function(s) {
  if (is_fill(s)) return(c("FILL", sub("^\\[FILL: (.*)\\]$", "\\1", s)))
  p <- strsplit(s, " ")[[1]]; c(paste(head(p, -1), collapse = " "), tail(p, 1))
}
year <- format(Sys.Date(), "%Y")
today <- format(Sys.Date())

# ---- DESCRIPTION, LICENSE, tests/testthat.R ----------------------------------------------------
d <- readLines("DESCRIPTION", warn = FALSE)
d <- sub("^Package:.*$", paste0("Package: ", pkg), d)
d <- sub("^Title:.*$", paste0("Title: ", gsub("[.?!]+$", "", title)), d)
a0 <- grep("^Authors@R:", d); nxt <- grep("^[A-Za-z@/]+:", d); a1 <- min(nxt[nxt > a0[1]]) - 1
au <- split_name(author); co <- split_name(coauthor)
d <- c(d[seq_len(a0[1] - 1)], "Authors@R: c(",
       sprintf('    person("%s", "%s", , "%s", role = c("aut", "cre")),', au[1], au[2], if (is_fill(email)) "first.last@example.com" else email),
       sprintf('    person("%s", "%s", role = "aut"))', co[1], co[2]),
       d[seq(a1 + 1, length(d))])
d0 <- grep("^Description:", d); nxt <- grep("^[A-Za-z@/]+:", d); d1 <- min(nxt[nxt > d0[1]]) - 1
d <- c(d[seq_len(d0[1] - 1)], "Description: A research compendium: the functions, tests, analysis scripts, results,",
       "    and manuscript of one project run with the research workflow, on the question [FILL: one sentence].",
       d[seq(d1 + 1, length(d))])
if (no_python) d <- d[!grepl("^\\s*reticulate,?\\s*$", d)]
writeLines(d, "DESCRIPTION")
sub_file("tests/testthat.R", "projecttemplate", pkg, fixed = TRUE)
sub_file("LICENSE", "^YEAR:.*$", paste0("YEAR: ", year))
holder <- if (is_fill(author)) paste(pkg, "authors") else if (is_fill(coauthor)) author else paste(author, "and", coauthor)
sub_file("LICENSE", "projecttemplate authors", holder, fixed = TRUE)

# ---- the Python package shares the name ---------------------------------------------------------
if (no_python) {
  unlink("inst/python", recursive = TRUE)
  for (f in c("pyproject.toml", ".python-version", "uv.lock")) if (file.exists(f)) file.remove(f)
  if (dir.exists("inst") && !length(list.files("inst", all.files = TRUE, no.. = TRUE))) unlink("inst", recursive = TRUE)
} else {
  for (f in c("pyproject.toml", "uv.lock", "inst/python/projecttemplate/__init__.py")) sub_file(f, "projecttemplate", pkg, fixed = TRUE)
  if (dir.exists("inst/python/projecttemplate")) invisible(file.rename("inst/python/projecttemplate", file.path("inst/python", pkg)))
}

# ---- remove the examples; placeholder tests ---------------------------------------------------
for (f in c("R/example.R", "tests/testthat/test-example.R", "analysis/01_example.R", "man/SimulateCohort.Rd",
            "R/python.R", "tests/testthat/test-python.R", "man/PySimulateCohort.Rd",
            file.path("inst/python", pkg, "example.py"), "inst/python/tests/test_example.py")) {
  if (file.exists(f)) file.remove(f)
}
for (f in list.files("results", full.names = TRUE)) if (!grepl("\\.gitkeep$", f)) file.remove(f)
writeLines("# Generated by roxygen2: do not edit by hand", "NAMESPACE")
writeLines(c(sprintf('test_that("the %s namespace loads", {', pkg), sprintf('  expect_true(isNamespaceLoaded("%s"))', pkg), "})"),
           "tests/testthat/test-package.R")
if (!no_python) {
  writeLines(c('"""Placeholder, so that pytest passes before the first real test exists."""', "", sprintf("import %s", pkg), "", "",
               "def test_package_imports():", sprintf("    assert %s.__doc__", pkg)), "inst/python/tests/test_package.py")
}

# ---- headers: README, STATUS, the manuscript skeleton ------------------------------------------
sub_file("README.md", "^# \\[Project title\\]$", paste0("# ", title))
sub_file("README.md", "^Authors: \\[names\\]\\.", paste0("Authors: ", author, ", ", coauthor, "."))
sub_file("STATUS.md", "[FILL: short title, set by tools/init.R]", title, fixed = TRUE)
sub_file("STATUS.md", "[FILL: package name, set by tools/init.R]", pkg, fixed = TRUE)
sub_file("STATUS.md", "[FILL: date, set by tools/init.R]", today, fixed = TRUE)
for (pair in list(c("[FILL: first author]", author), c("[FILL: second author]", coauthor), c("[FILL: email]", email), c("[FILL: affiliation]", affiliation))) {
  if (!is_fill(pair[2])) sub_file("manuscript/manuscript.qmd", pair[1], pair[2], fixed = TRUE)
}
if (!file.exists("manuscript/drafting-log.md")) {
  writeLines(c("# Drafting log", "", "Started by stage 3; see workflow/03-manuscript.md. The opening paragraph states the paper-test status in one line."), "manuscript/drafting-log.md")
}

cat("initialized:\n  package:", pkg, "\n  title:", title, "\n  authors:", author, "|", coauthor,
    "\n  python:", if (no_python) "removed" else "kept", "\nnext: renv::restore() in R from the project root; uv sync; write idea.md\n")
