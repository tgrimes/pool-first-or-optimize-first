test_that("every known-answer check of the re-pilot passes", {
  checks <- KnownAnswerChecksB()
  expect_equal(nrow(checks), 9)
  for (i in seq_len(nrow(checks))) {
    expect_true(checks$pass[i],
                label = paste(checks$check[i], checks$setting[i], sep = ", "))
  }
})

test_that("a bootstrap that reproduces the data has optimism exactly zero", {
  checks <- KnownAnswerChecksB()
  row <- checks[checks$check == "Optimism of a reproducing bootstrap", ]
  expect_identical(row$computed, 0)
})
