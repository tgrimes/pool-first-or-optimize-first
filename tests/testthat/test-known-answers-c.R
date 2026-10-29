test_that("every known-answer check of pilot-c passes", {
  checks <- KnownAnswerChecksC()
  expect_equal(nrow(checks), 7)
  for (i in seq_len(nrow(checks))) {
    expect_true(checks$pass[i],
                label = paste(checks$check[i], checks$setting[i], sep = ", "))
  }
})
