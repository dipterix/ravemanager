
get_latest_R_version <- function(url = "https://cran.rstudio.com/bin/windows/base/", pat = "R-[0-9.]+.+-win\\.exe") {
  page <- readLines(url, warn = FALSE)

  res <- gregexpr(pat, text = page)
  sel <- which(vapply(res, function(item) {
    isTRUE(any(!is.na(item) & item >= 0))
  }, FALSE))[[1]]

  res <- res[[sel]]
  target_line <- page[sel]

  mlen <- attr(res, "match.length")[[1]]
  filename <- substr(target_line, res[[1]], res[[1]] + mlen - 1)

  res <- gregexpr("[0-9.]+", text = filename)[[1]]
  mlen <- attr(res, "match.length")[[1]]
  latest_R_version <- substr(filename, res[[1]], res[[1]] + mlen - 1)

  pat <- "Last change: [0-9.]+-[0-9.]+-[0-9.]+"
  target_line <- grep(pat, page, value = TRUE)

  m <- regexpr(pat, target_line)
  latest_R_date <- regmatches(target_line, m)
  latest_R_date <- gsub(pattern = "Last change: ", "", latest_R_date)

  current_R_version <- as.character(getRversion())
  there_is_a_newer_version <- utils::compareVersion(current_R_version, latest_R_version) == -1

  if( there_is_a_newer_version ) {
    message_text <- paste(
      "There is a newer version of R for you to download!\n\n",
      "You are using R version:    \t", gsub("R version", "", R.version$version.string), "\n",
      "And the latest R version is:\t ", latest_R_version, " (", latest_R_date, ")", "\n",
      sep = ""
    )
  } else {
    message_text <- NULL
  }

  list(
    has_new_version = there_is_a_newer_version,
    latest_R_version = latest_R_version,
    latest_R_date = latest_R_date,
    current_R_version = current_R_version,
    message_text = message_text
  )


}
