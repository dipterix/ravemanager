alt_graphics <- local({
  app_src <- '
library(shiny)
dir <- Sys.getenv("PV_DIR")
addResourcePath("pvplots", file.path(dir, "plots"))

atomic <- function(lines, path) {
  tmp <- file.path(dirname(path), paste0(".tmp", Sys.getpid()))
  writeLines(as.character(lines), tmp); file.rename(tmp, path)
}

cfg_path <- file.path(dir, "viewer_cfg")

read_cfg <- function() {
  if (!file.exists(cfg_path)) return(NULL)
  suppressWarnings(tryCatch(readLines(cfg_path, warn = FALSE),
                            error = function(e) NULL))
}

ui <- fillPage(
  tags$style(
    "body{margin:0;background:#fff}
     #pvctl{position:fixed;top:6px;right:6px;z-index:9999;
            opacity:.35;transition:opacity .15s}
     #pvctl:hover{opacity:1}
     #pvctl .btn{margin-left:2px}"),
  tags$head(tags$script(HTML(
    \'function pvSend(){Shiny.setInputValue("dim",[innerWidth,innerHeight],{priority:"event"})}
     var t, deb=function(){clearTimeout(t); t=setTimeout(pvSend,200)};
     $(document).on("shiny:connected", pvSend);
     $(document).on("shiny:sessioninitialized", pvSend);
     $(window).on("resize", deb);
     if (window.ResizeObserver) new ResizeObserver(deb).observe(document.body);
     document.addEventListener("visibilitychange", function(){
       if (!document.hidden) pvSend();
     });\'))),
  div(id = "pvctl",
      actionButton("pv_prev", HTML("&lsaquo;"), class = "btn-default btn-sm",
                   title = "Previous plot"),
      actionButton("pv_next", HTML("&rsaquo;"), class = "btn-default btn-sm",
                   title = "Next plot (refresh if latest)"),
      actionButton("pv_last", HTML("&#8635;"), class = "btn-default btn-sm",
                   title = "Latest plot / refresh")),
  uiOutput("plot"))

server <- function(input, output, session) {
  init <- read_cfg()
  d0 <- suppressWarnings(as.integer(init[1:2]))
  if (length(d0) != 2L || anyNA(d0) || any(d0 < 50L)) d0 <- c(1000L, 700L)
  state <- reactiveValues(
    dim = d0,
    token = if (length(init) >= 3L) init[[3]] else "")

  write_cfg <- function() {
    d <- state$dim
    if (length(d) != 2L) return(invisible())
    atomic(c(d, state$token), cfg_path)
  }
  request_refresh <- function() {
    state$token <- format(as.numeric(Sys.time()), digits = 17)
    write_cfg()
  }

  observeEvent(input$dim, {
    d <- as.integer(input$dim)
    if (length(d) == 2L && all(is.finite(d)) && all(d > 50L)) {
      state$dim <- d
      write_cfg()
    }
  })
  idx <- reactiveFileReader(300, session, file.path(dir, "img_index"), function(f) {
    if (!file.exists(f)) return(0L)
    suppressWarnings(as.integer(readLines(f, warn = FALSE)[1]))
  })
  paths <- function() {
    f <- file.path(dir, "img_paths")
    if (!file.exists(f)) return(character(0))
    readLines(f, warn = FALSE)
  }
  # oldest image still on disk (main session only keeps the last 20)
  first_avail <- function() {
    p <- paths()
    if (!length(p)) return(0L)
    ok <- which(file.exists(p))
    if (!length(ok)) 0L else min(ok)
  }

  cur <- reactiveVal(0L)
  # always follow the newest plot
  observeEvent(idx(), {
    i <- idx()
    if (!is.na(i) && i > 0L) cur(i)
  })

  observeEvent(input$pv_prev, {
    i <- cur() - 1L
    lo <- first_avail()
    if (lo > 0L && i >= lo) cur(i)
  })
  observeEvent(input$pv_next, {
    i <- idx()
    if (!is.na(i) && cur() < i) cur(cur() + 1L) else request_refresh()
  })
  observeEvent(input$pv_last, {
    i <- idx()
    if (!is.na(i) && i > 0L) cur(i)
    request_refresh()
  })

  output$plot <- renderUI({
    i <- cur(); req(!is.na(i), i > 0L)
    p <- paths()
    req(length(p) >= i)
    tags$img(src = paste0("pvplots/", basename(p[i])),
             style = "max-width:100%;max-height:100vh;display:block;margin:auto")
  })
}
shinyApp(ui, server)
'

  tool_env <- NULL
  dir <- file.path(tempdir(), "plotview")
  proc <- NULL
  port <- NULL
  n <- 0L
  lastlen <- -1L
  busy <- FALSE
  old_device <- NULL
  own_devices <- integer(0)
  dirty <- FALSE
  last_cfg <- NULL
  poll_id <- 0L
  poll_interval <- 0.5

  # Set to c("plot.new", "grid.newpage") if I want to have some default
  # hook_funs <- character(0L)
  hook_funs <- c("plot.new", "grid.newpage", "image")
  bump <- function(...) {
    if (shiny_active()) {
      return(invisible())
    }
    dirty <<- TRUE
  }

  # These are optional: this package neither imports nor suggests them, so
  # they are resolved at run time instead of with `pkg::fun`
  required_pkgs <- c("svglite", "rstudioapi", "callr", "httpuv", "shiny",
                     "later")

  missing_pkgs <- function() {
    required_pkgs[!vapply(required_pkgs, is_installed, FALSE)]
  }

  # Report everything that is missing at once, with a command to install it
  install_hint <- function(pkgs = missing_pkgs()) {
    if (!length(pkgs)) {
      return("")
    }
    paste0(
      "tools:plotview: missing package", if (length(pkgs) > 1L) "s" else "",
      ". To install, run\n\n  ravemanager::add_r_package(",
      paste(deparse(pkgs), collapse = ""), ")\n"
    )
  }

  report_missing <- function(pkgs) {
    miss <- pkgs[!vapply(pkgs, is_installed, FALSE)]
    if (length(miss)) {
      message(install_hint(miss))
    } else {
      # installed, but the function is not there: too old, or broken
      message("tools:plotview: cannot use package ", paste(pkgs, collapse = ", "))
    }
    invisible(FALSE)
  }

  ns_get <- function(pkg, name) {
    if (!is_installed(pkg)) {
      return(NULL)
    }
    ns <- tryCatch(asNamespace(pkg), error = function(e) NULL)
    if (!is.environment(ns)) {
      return(NULL)
    }
    get0(name, envir = ns, mode = "function")
  }

  # TRUE when a shiny app is running in *this* session (the viewer app itself
  # runs in a background process, so it never triggers this)
  shiny_active <- function() {
    if (!isNamespaceLoaded("shiny")) {
      return(FALSE)
    }
    ns <- asNamespace("shiny")
    is_running <- get0("isRunning", envir = ns, mode = "function")
    if (is.function(is_running)) {
      if (isTRUE(tryCatch(is_running(), error = function(e) FALSE))) {
        return(TRUE)
      }
    }
    get_domain <- get0("getDefaultReactiveDomain", envir = ns, mode = "function")
    if (is.function(get_domain)) {
      if (!is.null(tryCatch(get_domain(), error = function(e) NULL))) {
        return(TRUE)
      }
    }
    FALSE
  }

  # Open a device using whatever `getOption("device")` was before `register()`
  default_device <- function(...) {
    dev <- old_device
    if (is.character(dev) && length(dev)) {
      dev <- tryCatch(match.fun(dev[[1]]), error = function(e) NULL)
    }
    if (!is.function(dev)) {
      dev <- function(...) grDevices::pdf(NULL)
    }
    dev(...)
  }

  atomic <- function(lines, path) {
    tmp <- file.path(dirname(path), paste0(".tmp", Sys.getpid()))
    writeLines(as.character(lines), tmp)
    file.rename(tmp, path)
  }

  # `viewer_cfg` has three lines: width, height, and a token that the viewer
  # bumps whenever it wants the main session to re-render
  read_cfg <- function() {
    f <- file.path(dir, "viewer_cfg")
    x <- if (file.exists(f)) {
      tryCatch(readLines(f, warn = FALSE), error = function(e) NULL)
    }
    d <- suppressWarnings(as.integer(x[1:2]))
    if (length(d) != 2L || anyNA(d) || any(d < 50L)) {
      d <- c(1000L, 700L)
    }
    token <- if (length(x) >= 3L && !is.na(x[[3]])) x[[3]] else ""
    list(dim = d, token = token)
  }

  dims <- function() {
    read_cfg()$dim
  }

  view <- function() {
    viewer <- ns_get("rstudioapi", "viewer")
    if (is.null(port) || !is.function(viewer)) {
      return(invisible(FALSE))
    }
    viewer(sprintf("http://127.0.0.1:%d/", port), height = 800)
    invisible(TRUE)
  }

  wait_port <- function(timeout = 15) {
    t0 <- Sys.time()
    repeat {
      if (!is.null(proc) && !proc$is_alive()) {
        return(FALSE)
      }
      ok <- tryCatch(
        {
          con <- socketConnection(
            "127.0.0.1",
            port,
            open = "r+",
            blocking = TRUE,
            timeout = 1
          )
          close(con)
          TRUE
        },
        error = function(e) FALSE,
        warning = function(w) FALSE
      )
      if (ok) {
        return(TRUE)
      }
      if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout) {
        return(FALSE)
      }
      Sys.sleep(0.15)
    }
  }

  ensure <- function() {
    if (!is.null(proc) && proc$is_alive()) {
      return(TRUE)
    }
    random_port <- ns_get("httpuv", "randomPort")
    r_bg <- ns_get("callr", "r_bg")
    if (!is.function(random_port) || !is.function(r_bg)) {
      return(report_missing(c("httpuv", "callr")))
    }
    port <<- random_port()
    proc <<- r_bg(
      # runs in a background process, where `shiny` is resolved the same way
      function(d, p) {
        Sys.setenv(PV_DIR = d)
        asNamespace("shiny")$runApp(
          file.path(d, "app.R"),
          port = p,
          launch.browser = FALSE
        )
      },
      args = list(dir, port),
      supervise = TRUE
    )
    if (!wait_port()) {
      msg <- if (!proc$is_alive()) {
        paste(utils::tail(proc$read_all_error_lines(), 5), collapse = "\n")
      } else {
        "timed out"
      }
      proc <<- NULL
      port <<- NULL
      message("tools:plotview: app failed to start\n", msg)
      return(FALSE)
    }
    view()
    TRUE
  }

  render <- function(cur) {
    svglite <- ns_get("svglite", "svglite")
    if (!is.function(svglite)) {
      return(report_missing("svglite"))
    }
    if (!ensure()) {
      return(invisible(FALSE))
    }
    d <- dims()
    n <<- n + 1L

    f <- file.path(dir, "plots", sprintf("p%d.svg", n))
    svglite(f, width = d[1] / 96, height = d[2] / 96, bg = "white")
    tryCatch(grDevices::replayPlot(cur), finally = grDevices::dev.off())

    cat(f, "\n", sep = "", file = file.path(dir, "img_paths"), append = TRUE)
    atomic(n, file.path(dir, "img_index"))

    for (i in seq_len(max(0L, n - 20L))) {
      unlink(file.path(dir, "plots", sprintf("p%d.svg", i)))
    }
    invisible(TRUE)
  }

  show <- function() {
    if (!registered() || shiny_active()) {
      return(invisible(FALSE))
    }
    if (is.null(grDevices::dev.list())) {
      return(invisible(FALSE))
    }
    cur <- tryCatch(grDevices::recordPlot(), error = function(e) NULL)
    if (is.null(cur) || is.null(cur[[1]]) || length(cur[[1]]) == 0L) {
      return(invisible(FALSE))
    }
    lastlen <<- length(cur[[1]])
    render(cur)
  }

  registered <- function() "tools:plotview" %in% getTaskCallbackNames()

  # Watch `viewer_cfg` for viewer-side requests: a token change (one of the
  # navigation buttons) or a size change (viewer resized) re-renders the
  # current plot
  poll_once <- function() {
    if (busy || shiny_active()) {
      return(invisible(FALSE))
    }
    cfg <- read_cfg()
    if (is.null(last_cfg)) {
      last_cfg <<- cfg
      return(invisible(FALSE))
    }
    if (identical(cfg$token, last_cfg$token) && identical(cfg$dim, last_cfg$dim)) {
      return(invisible(FALSE))
    }
    last_cfg <<- cfg
    busy <<- TRUE
    on.exit(busy <<- FALSE)
    show()
  }

  start_poll <- function() {
    later <- ns_get("later", "later")
    if (!is.function(later)) {
      return(report_missing("later"))
    }
    poll_id <<- poll_id + 1L
    id <- poll_id
    step <- function() {
      if (id != poll_id || !registered()) {
        return(invisible())
      }
      tryCatch(poll_once(), error = function(e) {
        message("tools:plotview: ", conditionMessage(e))
      })
      later(step, delay = poll_interval)
    }
    later(step, delay = poll_interval)
    invisible(TRUE)
  }

  stop_poll <- function() {
    poll_id <<- poll_id + 1L
    last_cfg <<- NULL
    invisible(TRUE)
  }

  # `par` settings live on the device, so closing the off-screen devices this
  # package opened is what resets them: the next plot starts on a fresh device
  # with the default `par`. Devices opened by anything else are left alone.
  reset_devices <- function() {
    for (d in own_devices) {
      lst <- grDevices::dev.list()
      if (!(d %in% lst)) {
        next
      }
      # the device number may have been recycled by an unrelated device
      if (!identical(names(lst)[lst == d][[1]], "pdf")) {
        next
      }
      tryCatch(grDevices::dev.off(d), error = function(e) NULL)
    }
    own_devices <<- integer(0)
    invisible(TRUE)
  }

  unregister <- function() {
    if (registered()) {
      removeTaskCallback("tools:plotview")
    }
    if (!is.null(old_device)) {
      options(device = old_device)
      old_device <<- NULL
    }
    reset_devices()
    while ("tools:plotview" %in% search()) {
      detach("tools:plotview", character.only = TRUE)
    }
    if (!is.null(proc) && proc$is_alive()) {
      proc$kill()
    }

    for (fun in hook_funs) {
      setHook(fun, NULL, "replace")
    }
    stop_poll()
    dirty <<- FALSE
    proc <<- NULL
    port <<- NULL
    lastlen <<- -1L
    gc()
    invisible(TRUE)
  }

  register <- function(hooks) {
    if (!interactive() || !nzchar(Sys.getenv("RSTUDIO"))) {
      return(invisible(FALSE))
    }
    if (length(missing_pkgs())) {
      message(install_hint())
      return(invisible(FALSE))
    }
    unregister()

    dir.create(file.path(dir, "plots"), recursive = TRUE, showWarnings = FALSE)
    writeLines(app_src, file.path(dir, "app.R"))
    unlink(file.path(dir, c("img_paths", "img_index")))
    n <<- 0L

    old_device <<- getOption("device")
    options(device = function(...) {
      # let shiny (or anything running inside it) use the original device
      if (shiny_active()) {
        return(default_device(...))
      }
      d <- dims()
      grDevices::pdf(NULL, width = d[1] / 96, height = d[2] / 96)
      grDevices::dev.control(displaylist = "enable")
      # remember it so `unregister()` can close it again
      own_devices <<- unique(c(own_devices, grDevices::dev.cur()))
      invisible()
    })

    addTaskCallback(
      function(...) {
        if (shiny_active()) {
          dirty <<- FALSE
          return(TRUE)
        }
        if (!dirty || busy || is.null(grDevices::dev.list())) {
          return(TRUE)
        }
        dirty <<- FALSE
        cur <- tryCatch(grDevices::recordPlot(), error = function(e) NULL)
        if (is.null(cur) || is.null(cur[[1]]) || length(cur[[1]]) == 0L) {
          return(TRUE)
        }
        busy <<- TRUE
        on.exit(busy <<- FALSE)
        tryCatch(render(cur), error = function(e) {
          message("tools:plotview: ", conditionMessage(e))
        })
        TRUE
      },
      name = "tools:plotview"
    )

    e <- init_env()
    e$.pv_show <- show
    e$.pv_dims <- dims
    e$.pv_stop <- unregister
    e$.pv_start <- register
    do.call(
      "attach",
      list(
        what = e,
        name = "tools:plotview",
        warn.conflicts = FALSE
      )
    )

    ensure()

    # baseline, so the current on-disk state is not taken for a fresh request
    last_cfg <<- read_cfg()
    start_poll()

    if (!missing(hooks)) {
      hook_funs <<- hooks
    }
    for (fun in hook_funs) {
      setHook(fun, bump, "replace")
    }
    invisible(TRUE)
  }

  init_env <- function() {
    if (!is.environment(tool_env)) {
      tool_env <<- new.env(parent = emptyenv())
      reg.finalizer(
        tool_env,
        function(e) {
          message("Shutting down alt-graphics")
          if (!is.null(proc) && proc$is_alive()) {
            proc$kill()
          }
        },
        TRUE
      )
    }
    tool_env
  }

  list(
    register = register,
    unregister = unregister,
    registered = registered,
    show = show,
    dims = dims
  )
})

#' @name pv_alt_graphics
#' @title Alternative graphics device for `RStudio`
#' @description
#' Replaces the default `RStudio` graphics device with a light-weight
#' `shiny` application that renders plots as `SVG` images in the viewer pane.
#' This is useful when the built-in device is unavailable or misbehaves, for
#' example on remote or containerized `RStudio` servers.
#'
#' `pv_init` starts the viewer and installs the hooks, `pv_off` removes them
#' and shuts the viewer down, `pv_show` sends the current plot to the viewer
#' manually, and `pv_dims` reports the viewer size in pixels.
#'
#' `pv_off` also closes the off-screen devices that `pv_init` opened. Since
#' `graphics::par()` settings belong to a device, this resets them: the next
#' plot starts on a fresh device with the defaults. Devices opened by anything
#' else are left untouched.
#'
#' @param ... currently ignored, reserved for future use
#'
#' @details
#' `pv_init` only takes effect in interactive `RStudio` sessions, and requires
#' the packages `svglite`, `rstudioapi`, `callr`, `httpuv`, and `shiny` to be
#' installed; otherwise the call is a no-op. When enabled, the graphics device
#' option is redirected to an off-screen `pdf` device with the display list
#' enabled, a top-level task callback named `tools:plotview` re-renders the
#' recorded plot whenever a new page is drawn, and helper functions
#' (`.pv_show`, `.pv_dims`, `.pv_start`, `.pv_stop`) are attached to the search
#' path under `tools:plotview`.
#'
#' While a `shiny` application is running in the current session (that is,
#' `shiny::isRunning()` is `TRUE` or a reactive domain is active), the hooks
#' step aside: new devices are opened with the original device and plots are
#' not captured, so `shiny` renders as usual. Normal behavior resumes once the
#' application stops. The viewer's own application does not count, as it runs
#' in a separate process.
#'
#' The viewer runs in a background \R process and reports its own width and
#' height back to the main session, so plots are re-drawn at the size of the
#' viewer pane. Only the 20 most recent images are kept on disk.
#'
#' Three buttons in the top-right corner of the viewer navigate the plot
#' history: previous steps back one image (and does nothing at the oldest one
#' still on disk), next steps forward one image, and the last button jumps to
#' the newest image. Stepping forward from the newest image, or pressing the
#' last button, also asks the main session to re-render the current plot, the
#' same as calling `pv_show()`. Such a request is passed back through the
#' viewer configuration file, which the main session polls once per second
#' using `later::later` while registered; resizing the viewer is picked up the
#' same way. The polling stops on `pv_off()`.
#'
#' @importFrom grDevices dev.control dev.cur dev.list dev.off pdf recordPlot
#' @importFrom grDevices replayPlot
#'
#' @returns
#' `pv_init`, `pv_off`, and `pv_show` invisibly return a logical value
#' indicating whether the corresponding action succeeded. `pv_dims` returns an
#' integer vector of length two: the viewer width and height in pixels,
#' defaulting to `c(1000L, 700L)` when the viewer has not reported its size.
#'
#' @examples
#' \dontrun{
#'
#' # Start the alternative graphics device
#' ravemanager::pv_init()
#'
#' plot(1:10)
#'
#' # Query the viewer size
#' ravemanager::pv_dims()
#'
#' # Re-send the current plot, e.g. after resizing the viewer
#' ravemanager::pv_show()
#'
#' # Restore the default device
#' ravemanager::pv_off()
#'
#' }
#'
#' @export
pv_init <- function(...) {
  alt_graphics$register(...)
}

#' @rdname pv_alt_graphics
#' @export
pv_off <- function(...) {
  alt_graphics$unregister(...)
}

#' @rdname pv_alt_graphics
#' @export
pv_show <- function(...) {
  alt_graphics$show(...)
}

#' @rdname pv_alt_graphics
#' @export
pv_dims <- function(...) {
  alt_graphics$dims(...)
}

