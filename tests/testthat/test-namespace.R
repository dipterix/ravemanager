test_that("Check function signatures for all asNamespace calls", {
  # find all calls to `xxx <- asNamespace("xxx")`
  src_dir <- "R"
  if (!dir.exists(src_dir)) {
    src_dir <- file.path("..", src_dir)
    if (!dir.exists(src_dir)) {
      src_dir <- file.path("..", src_dir)
      if (!dir.exists(src_dir)) {
        src_dir <- file.path("..", src_dir)
      }
    }
  }
  fs <- list.files(src_dir, all.files = FALSE, full.names = TRUE, include.dirs = FALSE, no.. = TRUE, recursive = FALSE)
  # Matches: var <- asNamespace("pkg")
  # group 2 = variable name, group 3 = package name
  assign_regex <- "(^|[ ])([a-zA-Z0-9\\.]+)[ ]{0,}<-[ ]{0,}asNamespace\\(['\"]([a-zA-Z0-9\\.]+)['\"]\\)"
  lapply(fs, function(f) {
    # f <- fs[[5]]
    s <- readLines(f, warn = FALSE)
    sel <- grepl(assign_regex, s)
    m <- regmatches(s[sel], regexec(assign_regex, text = s[sel]))
    lapply(m, function(item) {
      # item <- m[[1]]
      # item[[3]] = variable name (e.g. "ravedash")
      # item[[4]] = package name (e.g. "ravedash")
      pkg_name <- item[[4]]
      pkg_ns <- item[[3]]

      # Find all `pkg_ns$name` accesses in the whole file.
      # env$name uses get(name, envir=env, inherits=FALSE), so only bindings
      # directly in the namespace env are reachable — not imported re-exports.
      use_regex <- sprintf("\\b%s\\$([a-zA-Z0-9_.]+)", pkg_ns)
      all_matches <- unlist(regmatches(s, gregexpr(use_regex, s, perl = TRUE)))
      if (!length(all_matches)) return(NULL)

      # Strip "var$" prefix to obtain the accessed names
      accessed_names <- unique(sub(
        sprintf("^.*\\b%s\\$", pkg_ns), "", all_matches, perl = TRUE
      ))

      if (!requireNamespace(pkg_name, quietly = TRUE)) {
        # Package not installed in this environment — skip silently
        return(NULL)
      }

      ns_env <- asNamespace(pkg_name)
      lapply(accessed_names, function(nm) {
        # `$` on an environment is equivalent to get(nm, inherits = FALSE),
        # so the binding must live directly in the namespace environment,
        # not only in its parent imports environment (re-exports land there).
        expect_true(
          exists(nm, envir = ns_env, inherits = FALSE),
          label = sprintf(
            "%s: `%s$%s` — '%s' not found directly in namespace of '%s' (re-exported symbol?)",
            basename(f), pkg_ns, nm, nm, pkg_name
          )
        )
      })
    })
  })
})
