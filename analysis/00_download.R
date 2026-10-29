# Download the NHANES files of the application (2013-2014, 2015-2016,
# 2017-2018: serum cotinine, smoking questionnaire, demographics) into
# data/raw/. A file that already exists is skipped, so a raw file is
# written once and never overwritten.
#
# Run from the project root: Rscript analysis/00_download.R

devtools::load_all(quiet = TRUE)
set.seed(20261028)

files <- NhanesFiles()
raw_dir <- here::here("data", "raw")
status <- character(nrow(files))
for (i in seq_len(nrow(files))) {
  dest <- file.path(raw_dir, files$file[i])
  if (file.exists(dest)) {
    status[i] <- "skipped, exists"
    next
  }
  utils::download.file(files$url[i], dest, mode = "wb", quiet = TRUE)
  status[i] <- "downloaded"
}
files$status <- status
files$bytes <- file.size(file.path(raw_dir, files$file))
files$md5 <- unname(tools::md5sum(file.path(raw_dir, files$file)))
print(files[, c("file", "status", "bytes")], row.names = FALSE)

saveRDS(list(run = "pilot", n_rep = NA_integer_, n_cells = NA_integer_,
             date = Sys.time(), note = "NHANES download; files and md5 sums",
             n_rep_production = NA_integer_, files = files,
             session = utils::sessionInfo()),
        here::here("results", "download_run_info.rds"))
