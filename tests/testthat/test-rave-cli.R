# The `rave` script is macOS-only. These tests use a stub `brew` and a dead proxy,
# so they never install anything: an install fails right after the R check.

rscript_path <- "/Library/Frameworks/R.framework/Resources/bin/Rscript"

new_cli <- function(rapp_version = NULL, brew_manages_r = FALSE) {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  skip_if_not(file.exists(rscript_path), "CRAN R is not installed")

  root <- tempfile("rave-cli-")
  stub_dir <- file.path(root, "stub-bin")
  dir.create(stub_dir, recursive = TRUE)
  dir.create(file.path(root, "home"))
  brew_log <- file.path(root, "brew.log")
  file.create(brew_log)

  info <- if (is.null(rapp_version)) {
    "exit 1"
  } else {
    sprintf(paste(
      "cat <<'JSON'",
      "{",
      "  \"casks\": [",
      "    {",
      "      \"token\": \"r-app\",",
      "      \"version\": \"%s,sonoma\"",
      "    }",
      "  ]",
      "}",
      "JSON",
      sep = "\n"
    ), rapp_version)
  }
  writeLines(con = file.path(stub_dir, "brew"), c(
    "#!/bin/bash",
    sprintf("echo \"$*\" >> '%s'", brew_log),
    "case \"$1\" in",
    sprintf("  info)\n%s\n    ;;", info),
    sprintf("  list) exit %d ;;", if (brew_manages_r) 0L else 1L),
    "esac",
    "exit 0"
  ))
  Sys.chmod(file.path(stub_dir, "brew"), "0755")

  list(root = root, stub_dir = stub_dir, brew_log = brew_log)
}

# The variables are set for the script only, and the library path points into
# the temporary folder so that nothing can reach the real R library.
cli_command <- function(cli, args) {
  script <- system.file("shell/rave", package = "ravemanager")
  home <- file.path(cli$root, "home")
  c(
    "/usr/bin/env", "-u", "R_LIBS", "-u", "RAVE_LIB_PATH",
    sprintf("HOME=%s", home),
    sprintf("R_LIBS_USER=%s", file.path(home, "rlib")),
    "HTTPS_PROXY=http://127.0.0.1:9", "https_proxy=http://127.0.0.1:9",
    "HTTP_PROXY=http://127.0.0.1:9", "http_proxy=http://127.0.0.1:9",
    sprintf("PATH=%s:/usr/bin:/bin", cli$stub_dir),
    "/bin/bash", script, args
  )
}

run_cli <- function(cli, args = character(), input = character()) {
  command <- cli_command(cli, args)
  run_system(command[[1]], command[-1], input)
}

run_system <- function(command, args, input = character()) {
  stdin_file <- tempfile()
  on.exit(unlink(stdin_file))
  writeLines(input, stdin_file)
  output <- suppressWarnings(system2(
    command, args = shQuote(args),
    stdin = stdin_file, stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  list(output = paste(output, collapse = "\n"),
       status = if (is.null(status)) 0L else status)
}

# `script` gives the command a real terminal, so `rave` can ask a question.
# The answer is typed once the question is on screen, as a person would.
run_cli_in_terminal <- function(cli, args, answer) {
  log <- file.path(cli$root, "terminal.log")
  type_answer <- sprintf(
    "for i in $(seq 1 150); do grep -q 'Update R now' %s 2>/dev/null && break; sleep 0.2; done; echo %s",
    shQuote(log), answer
  )
  command <- paste(shQuote(cli_command(cli, args)), collapse = " ")
  driver <- sprintf("(%s) | /usr/bin/script -qF %s %s", type_answer, shQuote(log), command)
  res <- run_system("/bin/bash", c("-c", driver))
  res$output <- paste(readLines(log, warn = FALSE), collapse = "\n")
  res
}

r_minor_ahead <- function(n) {
  # The version of the R the script uses, which need not be the one running tests
  version <- system2(
    rscript_path, c("-e", shQuote("cat(R.version$major, R.version$minor, sep = '.')")),
    stdout = TRUE
  )
  parts <- as.integer(strsplit(version, ".", fixed = TRUE)[[1]])
  sprintf("%d.%d.0", parts[[1]], parts[[2]] + n)
}

brew_calls <- function(cli) {
  readLines(cli$brew_log, warn = FALSE)
}

test_that("--help works before RAVE is installed", {
  cli <- new_cli()
  res <- run_cli(cli, "--help")
  expect_identical(res$status, 0L)
  expect_match(res$output, "rave start", fixed = TRUE)
  expect_match(res$output, "rave update", fixed = TRUE)
})

test_that("--version works before RAVE is installed", {
  cli <- new_cli()
  res <- run_cli(cli, "--version")
  expect_identical(res$status, 0L)
  expect_match(res$output, "not installed", fixed = TRUE)
})

test_that("`rave start --help` does not start an install", {
  cli <- new_cli()
  res <- run_cli(cli, c("start", "--help"))
  expect_identical(res$status, 0L)
  expect_false(grepl("Installing RAVE", res$output, fixed = TRUE))
})

test_that("an unknown command fails", {
  cli <- new_cli()
  res <- run_cli(cli, "nonsense")
  expect_false(res$status == 0L)
  expect_match(res$output, "rave start", fixed = TRUE)
})

test_that("R one minor version behind r-app is left alone", {
  cli <- new_cli(rapp_version = r_minor_ahead(1))
  res <- run_cli(cli, "update")
  expect_false(any(grepl("(install|upgrade) --cask", brew_calls(cli))))
  expect_false(grepl("too old", res$output, fixed = TRUE))
  expect_match(res$output, "Installing RAVE", fixed = TRUE)
})

test_that("an install continues when r-app's version is unknown", {
  cli <- new_cli(rapp_version = NULL)
  res <- run_cli(cli, "update")
  expect_false(any(grepl("(install|upgrade) --cask", brew_calls(cli))))
  expect_match(res$output, "Installing RAVE", fixed = TRUE)
})

test_that("R older than that stops with no terminal and prints the command", {
  cli <- new_cli(rapp_version = r_minor_ahead(2))
  res <- run_cli(cli, "update")
  expect_false(res$status == 0L)
  expect_match(res$output, "too old", fixed = TRUE)
  expect_match(res$output, "brew install --cask r-app", fixed = TRUE)
  expect_false(any(grepl("(install|upgrade) --cask", brew_calls(cli))))
  expect_false(grepl("Installing RAVE", res$output, fixed = TRUE))
})

test_that("R managed by Homebrew is upgraded rather than installed", {
  cli <- new_cli(rapp_version = r_minor_ahead(2), brew_manages_r = TRUE)
  res <- run_cli(cli, "update")
  expect_false(res$status == 0L)
  expect_match(res$output, "brew upgrade --cask r-app", fixed = TRUE)
})

test_that("answering no leaves R alone", {
  cli <- new_cli(rapp_version = r_minor_ahead(2))
  res <- run_cli_in_terminal(cli, "update", answer = "n")
  expect_false(res$status == 0L)
  expect_false(any(grepl("(install|upgrade) --cask", brew_calls(cli))))
})

test_that("answering yes replaces R, then continues", {
  cli <- new_cli(rapp_version = r_minor_ahead(2), brew_manages_r = TRUE)
  res <- run_cli_in_terminal(cli, "update", answer = "y")
  expect_true("upgrade --cask r-app" %in% brew_calls(cli))
  expect_match(res$output, "Installing RAVE", fixed = TRUE)
})

test_that("a failed install exits non-zero, says what to do, and leaves no marker", {
  cli <- new_cli(rapp_version = r_minor_ahead(0))
  res <- run_cli(cli, "start")
  expect_false(res$status == 0L)
  expect_match(res$output, "rave start", fixed = TRUE)
  marker <- file.path(cli$root, "home", "rlib", ".rave-installed")
  expect_false(file.exists(marker))
})
