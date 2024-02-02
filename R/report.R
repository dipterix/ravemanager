
session_log <- function(x = NULL, max_lines = 200, modules = NULL) {
  n <- tryCatch({
    as.integer(max_lines)
  },
  error = function(e){200L},
  warning = function(e){200L})

  # x = NULL;max_lines = 200; modules = NULL
  ravedash <- asNamespace("ravedash")
  dipsaus <- asNamespace("dipsaus")
  if(is.function(ravedash$session_log)) {
    return(ravedash$session_log(x, max_lines = max_lines, modules = modules))
  }

  if(n <= 0) { n <- 5000L }
  if(is.null(x)) {
    x <- ravedash$list_session(order = "descend")
    if(!length(x)) {
      return(structure(character(0L), class = "ravedash_session_log_string", max_lines = n, session_id = NULL))
    }
    x <- x[[1]]
  }
  session <- ravedash$use_session(x)
  log_dir <- file.path(session$app_path, "logs")
  if(!dir.exists(log_dir)) {
    return(structure(character(0L), class = "ravedash_session_log_string", max_lines = n, session_id = session$session_id))
  }
  all_modules <- list.files(log_dir, pattern = "\\.log", all.files = FALSE, full.names = FALSE, recursive = FALSE, include.dirs = FALSE)
  modules <- all_modules
  if(length(modules)) {
    modules <- gsub("\\(.log|)$", ".log", x = modules, ignore.case = TRUE)
    modules <- c(modules[modules %in% all_modules], "ravedash.log")
  }
  modules <- unique(modules)
  modules <- modules[file.exists(file.path(log_dir, modules))]
  if(!length(modules)) {
    return(structure(character(0L), class = "ravedash_session_log_string", max_lines = n, session_id = session$session_id))
  }

  logs <- lapply(modules, function(module) {
    s <- trimws(readLines(file.path(log_dir, module)))
    if(length(s) > n) {
      s <- s[ -seq_len(length(s) - n) ]
    }
    timestamp <- substring(gsub("^(TRACE|DEBUG|INFO|WARN|ERROR|FATAL)[ ]{0, }", "", s), 1, 19)
    timestamp <- strptime(timestamp, format = "%Y-%m-%d %H:%M:%S")
    nas <- dipsaus$deparse_svec( which(is.na(timestamp)), concatenate = FALSE)

    for(ns_idx in nas) {
      idx <- dipsaus$parse_svec(ns_idx)
      if(length(idx)) {
        midx <- idx[[1]]
        if(midx > 1) {
          timestamp[ idx ] <- timestamp[[ midx - 1 ]]
        }
      }
    }
    data.frame(
      time = timestamp,
      string = s
    )
  })
  logs_combined <- do.call("rbind", logs)
  timestamps <- logs_combined$time[!is.na(logs_combined$time)]

  if(length(timestamps) > n) {
    tmp <- timestamps[[ order(timestamps, decreasing = TRUE)[[n]] ]]
    logs <- lapply(logs, function(log) {
      log[log$time >= tmp, ]
    })
    logs_combined <- do.call("rbind", logs)
  }
  return(structure(logs_combined$string[order(logs_combined$time, decreasing = FALSE)],
                   class = "ravedash_session_log_string", max_lines = n, session_id = session$session_id))

}

#' Print out 'RAVE' session log
#' @param session 'RAVE' session string; default is the most recent (active)
#' session
#' @param modules which module to read; default is all
#' @param max_lines maximum number of lines to read; default is 200
#' @param verbose whether to print out the log; default is true
#' @returns characters of log
#' @export
export_logs <- function(session = NULL, modules = NULL,
                        max_lines = Sys.getenv("RAVEMANAGER_BUGREPORT_MAX", "200"),
                        verbose = TRUE) {
  x <- session_log(session, modules = modules, max_lines = max_lines)
  x_ <- unclass(x)
  session_id <- attr(x_, "session_id")
  if(is.null(session_id)) {
    session_id <- "empty session ID"
  }
  if( verbose ) {
    tryCatch({
      version_info(vanilla = TRUE)
    }, error = function(e) {
      cat("Unable to obtain the RAVE version information...\n")
    })
    if( !any(grepl("^INFO.*Current session information:[ ]{0,}$", x_ )) ) {
      print(utils::sessionInfo())
    }
    cat(sprintf("<RAVE Module Session Logs> (%s)\n", session_id))
    cat(x_, sep = "\n")
    cat(sprintf("<Max lines: %s>\n", attr(x_, "max_lines")))
  }
  return(invisible(x))
}

#' Print 'RAVE' debugging information
#' @description
#' This function will generate a report. Please include the report when you
#' file an issue. Useful for reporting issues to 'RAVE' developers.
#' @param max_lines maximum number of log entries to print
#'
#' @export
debug_info <- function(max_lines) {

  has_reprex <- FALSE

  if(!missing(max_lines)) {
    Sys.setenv("RAVEMANAGER_BUGREPORT_MAX" = as.character(max_lines[[1]]))
  }

  if(!system.file(package = "reprex") != "") {
    tryCatch({
      install_packages("reprex")
      has_reprex <- TRUE
    }, error = function(e){
    })
  } else {
    has_reprex <- TRUE
  }
  if( has_reprex ) {
    reprex <- asNamespace("reprex")
    reprex$reprex(x = asNamespace("ravemanager")$export_logs(), advertise = FALSE)

  } else {
    cat("\014")
    message("\014")
    message("---- Start: RAVE Debug Info ----------------------------------------")
    export_logs()
    message("---- End: RAVE Debug Info ------------------------------------------")
  }

  message("Please Copy the above debugging information in your issue report :)")

  invisible()
}
