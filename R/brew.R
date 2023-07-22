cmd_homebrew <- function(error_on_missing = TRUE, unset = NA) {

  if(identical(Sys.info()[['machine']], "arm64")) {
    path <- "/opt/homebrew/bin/brew"
  } else {
    path <- "/usr/local/bin/brew"
  }

  if( length(path) != 1 || is.na(path) || !isTRUE(file.exists(path)) ) {
    if( error_on_missing ) {
      stop("Cannot find binary command `brew`. ",
           "Please open terminal and run the following shell command:\n\n",
           '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n\n',
           "If you have installed brew, please use\n\n",
           '  raveio::raveio_setopt("homebrew_path", <path to brew>)\n\n',
           "to set the path. Remember to replace and quote <path to brew>")
    }
    return(unset)
  } else {
    path <- normalizePath(path, winslash = "/")
  }
  return(path)
}

brew_installed <- function(pkgs) {
  if(missing(pkgs)) {
    brew <- cmd_homebrew(error_on_missing = FALSE)
    return(!is.na(brew) && file.exists(brew))
  }
  brew <- cmd_homebrew(error_on_missing = TRUE)
  return(vapply(pkgs, function(pkg) {
    tryCatch({
      suppressWarnings({
        suppressMessages({
          system2(brew, c("list", pkg), stdout = TRUE, stderr = FALSE)
        })
      })
      TRUE
    }, error = function(e) {
      FALSE
    })
  }, FALSE))

}
