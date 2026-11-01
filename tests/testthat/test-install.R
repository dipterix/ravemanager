test_that("install() returns TRUE when the installation finishes", {
  local_mocked_bindings(install_internal = function(...) invisible())
  expect_true(install(allow_cache = TRUE))
})

test_that("install() returns FALSE when the installation fails", {
  local_mocked_bindings(install_internal = function(...) stop("boom"))
  expect_false(suppressMessages(install(allow_cache = TRUE)))
})

test_that("add_shortcuts() on macOS points to `rave start` and touches nothing", {
  touched <- character()
  stub <- function(name) {
    function(...) {
      touched <<- c(touched, name)
      invisible(FALSE)
    }
  }
  f <- add_shortcuts
  environment(f) <- list2env(list(
    get_os = function() { "darwin" },
    dir.create = stub("dir.create"),
    dir.exists = function(...) { FALSE },
    file.copy = stub("file.copy"),
    unlink = stub("unlink"),
    Sys.chmod = stub("Sys.chmod"),
    system = stub("system")
  ), parent = environment(add_shortcuts))

  expect_message(f(), "rave start")
  expect_length(touched, 0)
})

test_that("rave-upgrade.R installs ravemanager from the RAVE repository", {
  script <- system.file("shell/rave-upgrade.R", package = "ravemanager")
  install_call <- parse(script)[[1]]

  # Evaluating the old code changed this option, so put it back
  saved_repos <- getOption("repos")
  repos <- eval(install_call$repos, envir = baseenv())
  options(repos = saved_repos)

  expect_type(repos, "character")
  expect_true("https://rave-ieeg.r-universe.dev" %in% repos)
})
