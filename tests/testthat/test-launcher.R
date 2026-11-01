run_launcher <- function(args, env = character()) {
  skip_on_cran()
  skip_on_os("windows")
  skip_if_not_installed("docopt")
  skip_if_not_installed("rave")

  script <- system.file("shell/launcher.R", package = "ravemanager")
  code <- sprintf(
    paste(
      "assignInNamespace('start_rave', function(...) {",
      "  cat('host:', list(...)$host, '\\n'); invisible() }, ns = 'rave')",
      "source(%s)",
      sep = "\n"
    ),
    deparse(script)
  )
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    args = c("--no-init-file", "-e", shQuote(code), args),
    env = env, stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  list(output = paste(output, collapse = "\n"),
       status = if (is.null(status)) 0L else status)
}

test_that("docopt is installed with RAVE, because launcher.R needs it", {
  expect_true("docopt" %in% rave_suggests)
})

test_that("launcher binds to localhost by default", {
  res <- run_launcher("start")
  expect_identical(res$status, 0L)
  expect_match(res$output, "host: 127.0.0.1", fixed = TRUE)
})

test_that("RAVE_HOST changes the default host", {
  res <- run_launcher("start", env = "RAVE_HOST=0.0.0.0")
  expect_identical(res$status, 0L)
  expect_match(res$output, "host: 0.0.0.0", fixed = TRUE)
})

test_that("--host wins over RAVE_HOST", {
  res <- run_launcher(c("start", "--host=10.0.0.5"), env = "RAVE_HOST=0.0.0.0")
  expect_identical(res$status, 0L)
  expect_match(res$output, "host: 10.0.0.5", fixed = TRUE)
})

test_that("launcher rejects ports outside 1024-65535", {
  for (port in c("80", "70000", "abc")) {
    res <- run_launcher(c("start", paste0("--port=", port)))
    expect_false(res$status == 0L)
    expect_match(res$output, "Invalid port number", fixed = TRUE)
  }
})
