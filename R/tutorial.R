#' @title Run tutorials
#' @param topic integers of which topic to launch, leave it blank, then 'RAVE'
#' will ask you to select a topic
#' @param ... other parameters to pass to \code{shiny::runApp()}
#' @examples
#' \dontrun{
#'
#' ravemanager::run_tutorials()
#'
#' }
#' @export
run_tutorials <- function(topic = NULL, ...) {
  if(system.file(package = "ravedash") == "") {
    message("Cannot find RAVE. Installing RAVE...")
    ravemanager::install()
  }

  if(system.file(package = "learnr") == "") {
    install_packages("learnr")
  }

  topics <- learnr::available_tutorials(package = "ravemanager")
  if(length(topic)) {
    topic <- topic[[1]]
    if(is.integer(topic) && topic %in% seq_along(topics$name)) {
      topic <- topics$name[topic]
    }
    if(!isTRUE(topic %in% topics$name)) {
      topic <- NULL
    }
  }

  if(!length(topic)) {

    titles <- sprintf("  %d. %s", seq_along(topics$title), topics$title)
    dipsaus <- asNamespace("dipsaus")
    ans <- dipsaus$ask_or_default(
      paste(c("Please enter a topic number to start: ",
              titles), collapse = "\n"),
      default = ""
    )
    ans <- as.integer(ans)
    if(!length(ans) || is.na(ans) || ans > length(topics$name) || ans <= 0) {
      stop("Please enter a number indicating which topic you want to start.")
    }
    topic <- topics$name[ans]
  }

  options(shiny.launch.browser = TRUE)

  learnr::run_tutorial(name = topic, package = "ravemanager", shiny_args = list(
    launch.browser = TRUE,
    ...
  ), as_rstudio_job = FALSE)

}
