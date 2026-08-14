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
    \'function pvSend(){Shiny.setInputValue("dim",
       [innerWidth,innerHeight,window.devicePixelRatio||1],{priority:"event"})}
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
  r0 <- suppressWarnings(as.numeric(init[4]))
  if (length(r0) != 1L || is.na(r0) || r0 < 1) r0 <- 1
  state <- reactiveValues(
    dim = d0,
    token = if (length(init) >= 3L) init[[3]] else "",
    dpr = r0)

  write_cfg <- function() {
    d <- state$dim
    if (length(d) != 2L) return(invisible())
    atomic(c(d, state$token, state$dpr), cfg_path)
  }
  request_refresh <- function() {
    state$token <- format(as.numeric(Sys.time()), digits = 17)
    write_cfg()
  }

  observeEvent(input$dim, {
    v <- as.numeric(input$dim)
    d <- as.integer(v[1:2])
    if (length(d) == 2L && all(is.finite(d)) && all(d > 50L)) {
      state$dim <- d
      r <- v[3]
      if (length(r) == 1L && is.finite(r) && r >= 1) state$dpr <- r
      write_cfg()
    }
  })
  # `img_index` holds the number of pages and an ever-increasing render number.
  # Poll its *contents*: an update in place leaves the page count alone, and
  # `reactiveFileReader` compares only mtime (whole seconds) and size, so it
  # would miss exactly that case
  state_path <- file.path(dir, "img_index")
  read_state <- function() {
    if (!file.exists(state_path)) return(character(0))
    tryCatch(readLines(state_path, warn = FALSE), error = function(e) character(0))
  }
  hist_state <- reactivePoll(100, session,
    checkFunc = function() paste(read_state(), collapse = "|"),
    valueFunc = function() {
      x <- suppressWarnings(as.integer(read_state()))
      list(index = if (length(x) >= 1L && !is.na(x[[1]])) x[[1]] else 0L,
           ver = if (length(x) >= 2L && !is.na(x[[2]])) x[[2]] else 0L)
    })
  idx <- function() hist_state()$index

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
  # follow the newest page, but only when a page is actually added: updates in
  # place must not drag the user forward while browsing back
  seen <- reactiveVal(0L)
  observeEvent(hist_state(), {
    i <- idx()
    if (!is.na(i) && i > 0L && !identical(i, seen())) {
      seen(i)
      cur(i)
    }
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
    hist_state()               # re-read on every render, in place or not
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
  # NOTE: this `local()` is evaluated when the package is *installed*, so
  # anything computed here is frozen into the build. `tempdir()` in particular
  # would be the temporary directory of the session that built the package,
  # which no longer exists for the user -- hence a function, resolved on every
  # call. `check = TRUE` also recreates it if it was cleaned up mid-session
  work_dir <- function() {
    file.path(tempdir(check = TRUE), "plotview")
  }
  proc <- NULL
  port <- NULL
  # one entry per page; a render either appends a page or updates the last one
  img_list <- character(0)
  # always increments, so every render gets a file name the browser has not seen
  fileno <- 0L
  lastlen <- -1L
  busy <- FALSE
  old_device <- NULL
  own_devices <- integer(0)
  dirty <- FALSE
  # watch the display list so incremental drawing is picked up too
  watch_dl <- TRUE
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

  # "png" (default) or "svg"; `svglite` is only needed for the latter
  out_format <- "png"

  # These are optional: this package neither imports nor suggests them, so
  # they are resolved at run time instead of with `pkg::fun`
  required_pkgs <- c("rstudioapi", "callr", "httpuv", "shiny", "later")

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

  # Open the output device. `ragg` is much faster than `svglite` on point-heavy
  # and raster plots and writes a fraction of the bytes, but it is optional, so
  # fall back to cairo and then to whatever `png()` offers. The size is given in
  # pixels while the recording device is sized in inches; `res` keeps the two in
  # step, so the layout is identical and only the pixel density changes.
  open_png <- function(f, w, h, dpr) {
    px <- c(max(1L, round(w * dpr)), max(1L, round(h * dpr)))
    res <- 96 * dpr
    agg_png <- ns_get("ragg", "agg_png")
    if (is.function(agg_png)) {
      agg_png(f, width = px[[1]], height = px[[2]], res = res,
              background = "white")
      return(TRUE)
    }
    args <- list(f, width = px[[1]], height = px[[2]], res = res, bg = "white")
    if (isTRUE(unname(capabilities("cairo")))) {
      args$type <- "cairo"
    }
    do.call(grDevices::png, args)
    TRUE
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
    f <- file.path(work_dir(), "viewer_cfg")
    x <- if (file.exists(f)) {
      tryCatch(readLines(f, warn = FALSE), error = function(e) NULL)
    }
    d <- suppressWarnings(as.integer(x[1:2]))
    if (length(d) != 2L || anyNA(d) || any(d < 50L)) {
      d <- c(1000L, 700L)
    }
    token <- if (length(x) >= 3L && !is.na(x[[3]])) x[[3]] else ""
    # a 3x display would quadruple the work for no visible gain
    dpr <- suppressWarnings(as.numeric(x[4]))
    if (length(dpr) != 1L || is.na(dpr) || dpr < 1) {
      dpr <- 1
    }
    list(dim = d, token = token, dpr = min(dpr, 2))
  }

  dims <- function() {
    read_cfg()$dim
  }

  view <- function() {
    viewer <- ns_get("rstudioapi", "viewer")
    if (is.null(port) || !is.function(viewer)) {
      return(invisible(FALSE))
    }
    # showing the pane is optional: if it fails, the app is still running and
    # reachable, and `register()` must not be left half-finished
    ok <- tryCatch({
      viewer(sprintf("http://127.0.0.1:%d/", port), height = 800)
      TRUE
    }, error = function(e) {
      message("tools:plotview: cannot open the viewer pane: ",
              conditionMessage(e))
      FALSE
    })
    invisible(ok)
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
      args = list(work_dir(), port),
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

  # A history entry is a *page*: `new_page` appends one, anything else (drawing
  # onto the current page, a refresh, a resize) updates the last entry in place
  render <- function(cur, new_page = isTRUE(dirty)) {
    svglite <- if (identical(out_format, "svg")) {
      f <- ns_get("svglite", "svglite")
      if (!is.function(f)) {
        return(report_missing("svglite"))
      }
      f
    }
    if (!ensure()) {
      return(invisible(FALSE))
    }
    cfg <- read_cfg()
    d <- cfg$dim
    fileno <<- fileno + 1L

    f <- file.path(work_dir(), "plots",
                   sprintf("p%d.%s", fileno, if (is.null(svglite)) "png" else "svg"))
    if (is.null(svglite)) {
      open_png(f, d[[1]], d[[2]], cfg$dpr)
    } else {
      svglite(f, width = d[1] / 96, height = d[2] / 96, bg = "white")
    }
    tryCatch(grDevices::replayPlot(cur), finally = grDevices::dev.off())

    if (new_page || !length(img_list)) {
      img_list <<- c(img_list, f)
    } else {
      unlink(img_list[[length(img_list)]])
      img_list[[length(img_list)]] <<- f
    }

    # `img_index` is written last: once the viewer sees it change, `img_paths`
    # is already up to date
    atomic(img_list, file.path(work_dir(), "img_paths"))
    atomic(c(length(img_list), fileno), file.path(work_dir(), "img_index"))

    # keep the files for the 20 most recent pages, but keep every line so the
    # viewer can still tell how far back it may step
    for (i in seq_len(max(0L, length(img_list) - 20L))) {
      unlink(img_list[[i]])
    }
    dirty <<- FALSE
    lastlen <<- if (is.null(cur)) -1L else length(cur[[1]])
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
    if (identical(cfg$token, last_cfg$token) &&
        identical(cfg$dim, last_cfg$dim) &&
        identical(cfg$dpr, last_cfg$dpr)) {
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

  register <- function(hooks, watch = TRUE, format = c("png", "svg")) {
    if (!interactive() || !nzchar(Sys.getenv("RSTUDIO"))) {
      return(invisible(FALSE))
    }
    format <- match.arg(format)
    need <- c(required_pkgs, if (identical(format, "svg")) "svglite")
    if (length(miss <- need[!vapply(need, is_installed, FALSE)])) {
      message(install_hint(miss))
      return(invisible(FALSE))
    }
    unregister()

    watch_dl <<- isTRUE(watch)
    out_format <<- format
    dir <- work_dir()
    plots <- file.path(dir, "plots")
    dir.create(plots, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(plots)) {
      message("tools:plotview: cannot create the working directory ", plots)
      return(invisible(FALSE))
    }
    writeLines(app_src, file.path(dir, "app.R"))
    unlink(file.path(dir, c("img_paths", "img_index")))
    # start from a clean slate: images left behind by an earlier session are
    # not in `img_list` and would only confuse the viewer
    unlink(list.files(plots, full.names = TRUE))
    img_list <<- character(0)
    fileno <<- 0L

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
        if (busy || is.null(grDevices::dev.list())) {
          return(TRUE)
        }
        # `points()`, `lines()`, `text()`, ... run no hook, they only append to
        # the display list, so watch its length: anything that draws on the
        # current page changes it. `dirty` (set by the `plot.new` hook) covers
        # the case of a new page that happens to be the same length
        if (!dirty && !watch_dl) {
          return(TRUE)
        }
        cur <- tryCatch(grDevices::recordPlot(), error = function(e) NULL)
        if (is.null(cur) || is.null(cur[[1]]) || length(cur[[1]]) == 0L) {
          return(TRUE)
        }
        if (!dirty && length(cur[[1]]) == lastlen) {
          return(TRUE)
        }
        busy <<- TRUE
        on.exit(busy <<- FALSE)
        # `render()` reads `dirty` to decide new page vs. update, and clears it
        tryCatch(render(cur), error = function(e) {
          # clear it here too, so a failing render does not report itself again
          # after every command
          dirty <<- FALSE
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
#' @param ... passed to the internal handlers; `pv_init` accepts `hooks`, a
#' character vector of new-page hook names to watch, plus `watch` and `format`,
#' see 'Details'
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
#' Incremental drawing such as `points()`, `lines()`, or `legend()` runs no
#' hook, so the hooks alone would miss it. Instead the callback compares the
#' length of the device display list with the length at the last render, and
#' re-renders when it differs; the `plot.new` hook still covers the case of a
#' new page that happens to have the same length. This means the display list
#' is recorded once per top-level command, which is the cost of the feature;
#' pass `watch = FALSE` to `pv_init` to disable it and fall back to the hooks
#' alone.
#'
#' While a `shiny` application is running in the current session (that is,
#' `shiny::isRunning()` is `TRUE` or a reactive domain is active), the hooks
#' step aside: new devices are opened with the original device and plots are
#' not captured, so `shiny` renders as usual. Normal behavior resumes once the
#' application stops. The viewer's own application does not count, as it runs
#' in a separate process.
#'
#' The viewer runs in a background \R process and reports its own width, height,
#' and device pixel ratio back to the main session, so plots are re-drawn at the
#' size of the viewer pane and stay sharp on high-density displays. Only the 20
#' most recent pages are kept on disk.
#'
#' Pages are written as `PNG` using `ragg` when it is installed, falling back to
#' `grDevices::png()` with the `cairo` back end and then to whatever `png()`
#' offers. `PNG` keeps the cost of a render bounded: `SVG` is faster for simple
#' line art, but a scatter plot of 100000 points or a raster image takes several
#' times longer to write and produces a file in the tens of megabytes, which the
#' browser then has to parse. Pass `format = "svg"` to `pv_init` for vector
#' output instead, which additionally requires `svglite`. The raster output is
#' re-rendered whenever the viewer changes size, so it is never scaled up.
#'
#' The history holds one entry per page: `plot()` and friends start a new one,
#' while incremental drawing, a refresh, and a resize re-render the current
#' entry in place instead of appending a copy of it. Three buttons in the
#' top-right corner of the viewer navigate that history: previous steps back
#' one page (and does nothing at the oldest one still on disk), next steps
#' forward one page, and the last button jumps to the newest page. Stepping forward from the newest image, or pressing the
#' last button, also asks the main session to re-render the current plot, the
#' same as calling `pv_show()`. Such a request is passed back through the
#' viewer configuration file, which the main session polls once per second
#' using `later::later` while registered; resizing the viewer is picked up the
#' same way. The polling stops on `pv_off()`.
#'
#' @importFrom grDevices dev.control dev.cur dev.list dev.off pdf png
#' @importFrom grDevices recordPlot replayPlot
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
  suppressWarnings({
    alt_graphics$register(...)
  })
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

