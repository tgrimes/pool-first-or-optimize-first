test_that("every known-answer check of the pre-registration passes", {
  checks <- KnownAnswerChecks()
  expect_equal(nrow(checks), 13)
  for (i in seq_len(nrow(checks))) {
    expect_true(checks$pass[i],
                label = paste(checks$check[i], checks$setting[i], sep = ", "))
  }
})

test_that("pooling identical curves gives a gap of exactly zero", {
  checks <- KnownAnswerChecks()
  nothing_missing <- checks[checks$check == "Gap with nothing missing", ]
  expect_identical(nothing_missing$computed, c(0, 0))
})
