# NHANES serum cotinine: the files, the adult cohort, and its Youden curve.

#' NHANES file names for the pilot's cycles
#'
#' @return A data frame with `cycle` ("2013-2014", ...), `year` (the folder
#'   year), `suffix` ("H", "I", "J"), `component` ("COT", "SMQ", "DEMO"),
#'   `file`, and `url`.
#' @export
NhanesFiles <- function() {
  cycles <- data.frame(cycle = c("2013-2014", "2015-2016", "2017-2018"),
                       year = c(2013L, 2015L, 2017L),
                       suffix = c("H", "I", "J"))
  out <- merge(cycles, data.frame(component = c("COT", "SMQ", "DEMO")))
  out$file <- paste0(out$component, "_", out$suffix, ".xpt")
  out$url <- sprintf(
    "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/%d/DataFiles/%s",
    out$year, out$file)
  out[order(out$year, out$component), ]
}

#' Build the adult cotinine cohort of one NHANES cycle
#'
#' Keeps participants aged 18 and over who answered whether they smoked 100
#' cigarettes in their life (`SMQ020` 1 or 2). A current smoker smoked 100
#' cigarettes and now smokes every day or some days (`SMQ040` 1 or 2);
#' everyone else who answered is a nonsmoker, and a missing or refused
#' `SMQ040` among those who smoked 100 cigarettes is dropped.
#'
#' @param cot,smq,demo Data frames read from the `COT`, `SMQ`, and `DEMO`
#'   files of one cycle.
#' @param cycle Label of the cycle.
#' @return A data frame with `seqn`, `cycle`, `age`, `sex`, `race`,
#'   `examined`, `cotinine` (ng/mL, `NA` when missing), `below_lod`, and
#'   `smoker` (1 current, 0 not).
#' @export
BuildCotinineCohort <- function(cot, smq, demo, cycle) {
  dat <- merge(demo[, c("SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH3",
                        "RIDSTATR")],
               smq[, c("SEQN", "SMQ020", "SMQ040")], by = "SEQN")
  dat <- merge(dat, cot[, c("SEQN", "LBXCOT", "LBDCOTLC")], by = "SEQN",
               all.x = TRUE)
  dat <- dat[!is.na(dat$RIDAGEYR) & dat$RIDAGEYR >= 18 &
               dat$SMQ020 %in% c(1, 2), ]
  smoker <- ifelse(dat$SMQ020 == 2, 0L,
                   ifelse(dat$SMQ040 %in% c(1, 2), 1L,
                          ifelse(dat$SMQ040 %in% 3, 0L, NA_integer_)))
  race_labels <- c(`1` = "Mexican American", `2` = "Other Hispanic",
                   `3` = "Non-Hispanic White", `4` = "Non-Hispanic Black",
                   `6` = "Non-Hispanic Asian", `7` = "Other or multiracial")
  out <- data.frame(seqn = dat$SEQN, cycle = cycle, age = dat$RIDAGEYR,
                    sex = ifelse(dat$RIAGENDR == 1, "male", "female"),
                    race = unname(race_labels[as.character(dat$RIDRETH3)]),
                    examined = dat$RIDSTATR == 2,
                    cotinine = dat$LBXCOT,
                    below_lod = dat$LBDCOTLC %in% 1,
                    smoker = smoker, stringsAsFactors = FALSE)
  out[!is.na(out$smoker), ]
}

#' Youden curve of a real marker, on a scale comparable to the simulation
#'
#' Standardizes the marker by the mean and standard deviation of group 0, as
#' in the simulation, and computes the empirical and Gaussian-kernel Youden
#' curves of complete cases, with the kernel curve's maximizer, maximum, and
#' curvature.
#'
#' @param x Marker values (complete cases).
#' @param d Group (0 or 1).
#' @param grid_n Number of grid points.
#' @return A list with `center`, `scale`, `grid` (standardized),
#'   `empirical` and `kernel` (curves on the grid), `c_star`, `j_star`,
#'   `kappa` (kernel, standardized scale), and the empirical maximizer
#'   `c_star_empirical` and maximum `j_star_empirical`.
#' @export
RealYoudenCurve <- function(x, d, grid_n = 401L) {
  center <- mean(x[d == 0])
  scale <- stats::sd(x[d == 0])
  xs <- (x - center) / scale
  grid <- seq(stats::quantile(xs, 0.005), stats::quantile(xs, 0.995),
              length.out = grid_n)
  emp <- EmpiricalCurves(matrix(xs), d)
  emp_max <- MaximizeStep(emp$u, emp$values[1, ])
  kc <- KernelCurves(matrix(xs), d)
  grid_values <- kc$grid_fun(grid)
  kmax <- MaximizeSmooth(function(cc) kc$curve_fun(cc, 1), grid,
                         grid_values[1, ])
  step <- 0.02
  kappa <- -(kc$curve_fun(kmax$cutoff + step, 1) - 2 * kmax$value +
               kc$curve_fun(kmax$cutoff - step, 1)) / step^2
  list(center = center, scale = scale, grid = grid,
       empirical = StepValue(grid, emp$u, emp$values[1, ]),
       kernel = grid_values[1, ], c_star = kmax$cutoff,
       j_star = kmax$value, kappa = kappa,
       c_star_empirical = emp_max$cutoff, j_star_empirical = emp_max$value)
}

#' Read and build the adult cotinine cohort of one NHANES cycle
#'
#' @param raw_dir Folder holding the downloaded `.xpt` files.
#' @param suffix File suffix of the cycle ("H", "I", "J").
#' @param cycle Label of the cycle.
#' @return See `BuildCotinineCohort()`.
#' @export
ReadNhanesCycle <- function(raw_dir, suffix, cycle) {
  ReadOne <- function(component) {
    foreign::read.xport(file.path(raw_dir,
                                  paste0(component, "_", suffix, ".xpt")))
  }
  BuildCotinineCohort(ReadOne("COT"), ReadOne("SMQ"), ReadOne("DEMO"), cycle)
}
