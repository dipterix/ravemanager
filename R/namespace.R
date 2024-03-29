guess_libpath <- function(if_not_found = .libPaths()[[1]]) {
  lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = ""))

  ostype <- get_os()

  if(ostype == 'windows') {
    lib_path <- strsplit(lib_path, ";")[[1]]
  } else {
    lib_path <- strsplit(lib_path, ":")[[1]]
  }

  if(length(lib_path)) {
    return(lib_path[[1]])
  }

  return(if_not_found)
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



unload_namespace <- function(name, use_pkgload = TRUE) {

  if(!length(name)) { return() }

  use_pkgload <- use_pkgload && system.file("pkgload") != ''
  avoids <- NULL
  if(use_pkgload) {
    try(silent = TRUE, {
      pkgload_desc <- read.dcf(system.file(package = "pkgload", "DESCRIPTION"))
      pkgload_desc <- as.list(as.data.frame(pkgload_desc))
      avoids <- c(pkgload_desc$Imports, pkgload_desc$Suggests, pkgload_desc$Depends, "pkgload")
      avoids <- unlist(strsplit(avoids, "[ ,\n]"))
    })
  }
  if(any(name %in% avoids)) {
    use_pkgload <- FALSE
  }


  if(length(name) > 1) {
    for(nm in name) {
      unload_namespace(nm, use_pkgload = use_pkgload)
    }
  }
  unloaded <- FALSE
  if(!identical(name, "pkgload")) {
    try({
      pkgload <- asNamespace("pkgload")
      pkgload$unload(package = name)
      unloaded <- TRUE
    }, silent = TRUE)
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

get_libpaths <- function(first = TRUE, check = FALSE) {
  libpath <- normalizePath(guess_libpath(), winslash = "/", mustWork = FALSE)
  current_paths <- normalizePath(.libPaths(), winslash = "/", mustWork = FALSE)

  if(length(libpath)) {
    if(check) {
      dir_create2(libpath)
    }
    if( !libpath %in% current_paths ) {
      .libPaths(libpath)
    }
  }

  re <- unique(c(libpath, current_paths))

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

  lib_path <- get_libpaths(first = FALSE, check = TRUE)

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
