guess_libpath <- function() {
  lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = ""))

  ostype <- get_os()

  if(ostype == 'windows') {
    lib_path <- strsplit(lib_path, ";")[[1]]
  } else {
    lib_path <- strsplit(lib_path, ":")[[1]]
  }

  if(!length(lib_path)) {
    return(NULL)
  }

  return(lib_path[[1]])
}

pkg_env_name <- function (package) {
  paste("package:", package, sep = "")
}

is_attached <- function (package) {
  pkg_env_name(package) %in% search()
}

is_loaded <- function (package) {
  package %in% loadedNamespaces()
}

ns_env <- function (package) {
  if (!is_loaded(package)) return(NULL)
  suppressWarnings({
    ns <- asNamespace(package)
  })
  ns
}

detach_namespace <- function (package) {
  if (is_attached(package)) {
    pos <- which(pkg_env_name(package) == search())
    suppressWarnings(detach(pos = pos, force = TRUE))
  }
}



unload_namespace <- function(name) {
  if(!length(name)) { return() }

  if(length(name) > 1) {
    for(nm in name) {
      unload_namespace(nm)
    }
  }

  detach_namespace(name)

  ns <- ns_env(name)
  if(!is.environment(ns)) { return() }

  users <- getNamespaceUsers(ns)
  if(length(users)) {
    for(dep in users) {
      unload_namespace(dep)
    }
  }

  unloadNamespace(ns)
  invisible()
}

get_libpaths <- function(first = TRUE) {
  re <- normalizePath(unique(c(guess_libpath(), .libPaths())),
                winslash = "/", mustWork = FALSE)
  re <- unique(re)
  if(length(re) && first) {
    re <- re[[1]]
  }
  re
}

ensure_depends <- function(name) {
  # Load all depends into namespace
  if(missing(name)) {
    name <- c(rave_depends, "rave")
  }

  lib_path <- get_libpaths(first = FALSE)

  lapply(name, function(nm) {
    tryCatch({
      if(!nm %in% loadedNamespaces()) {
        suppressWarnings({
          loadNamespace(nm, lib.loc = lib_path)
        })
      }
    }, error = function(e) {
      warning("Cannot load namespace ", shQuote(nm), ". Reason: ", e$message)
    })
  })

}
