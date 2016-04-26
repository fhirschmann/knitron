#' Starts an IPython cluster with one engine
#' 
#' @param profile the name of the profile
#' @param wait wait for the engine to start up
#' @param quiet be quiet about IPython's startup messages
#' @export
knitron.start <- function(profile = "knitr", wait = TRUE, quiet = FALSE) {
  message(paste("Starting cluster for profile", profile))

  system2("ipcluster", c("start", paste("--profile", profile, sep="="), "--n=1"),
          wait = FALSE, stderr = if(quiet) FALSE else "")
  
  # Keep a list so that we can kill the clusters later
  .knitron_env$profiles <- append(.knitron_env$profiles, profile)

  if (wait) {
    Sys.sleep(15)
    # We wait until we can reach the cluster.
    count <- 0
    while (!knitron.is_running(profile)) {
      Sys.sleep(0.5)
      count <- count + 1
      if (count > 40)
        stop("IPython cluster could not be started. Giving up.")
    }
  }
}

#' Stops an IPython cluster
#' 
#' @param profile the name of the profile
#' @param quiet be quiet about IPython's shutdown messages
#' @export
knitron.stop <- function(profile = "knitr", quiet = TRUE) {
  system2("ipcluster", c("stop", paste("--profile", profile, sep="=")),
          stderr = if(quiet) FALSE else "")
  .knitron_env$profiles <- setdiff(.knitron_env$profiles, profile)
}

#' Returns true if the cluster is running
#' 
#' @param profile the name of the profile
#' @return \code{TRUE} if cluster is running
#' @export
knitron.is_running <- function(profile = "knitr") {
  res <- paste(knitron.execute_code("0", profile), collapse="")
  res == "0"
}

#' Execute a code chunk from a knitr option list
#' 
#' @param options a knitr option list
#' @param profile the name of the profile
#' @return a data frame of messages from the Python wrapper
#' @export
knitron.execute_chunk <- function(options, profile = "knitr") {
  json_file <- tempfile()
  args <- paste(.knitron_env$knitron_wrapper, profile, "chunk", json_file)
  out <- system2("ipython", args, input = jsonlite::toJSON(options, auto_unbox = TRUE),
                 wait = TRUE, stdout = TRUE, stderr = TRUE)
  cat(paste(out, collapse=""))
  jsonlite::fromJSON(readLines(json_file))
}

#' Execute a single Python command
#' 
#' @param code the command to execute
#' @param profile the name of the profile
#' @return the command's stdout and stderr
#' @export
knitron.execute_code <- function(code, profile = "knitr") {
  args <- paste(.knitron_env$knitron_wrapper, profile, "code", code)
  system2("ipython", args, wait = TRUE, stdout = TRUE, stderr = TRUE)
}

.knitron_defaults <- function(options) {
  defaults <- list(
    knitron.autoplot = TRUE,
    knitron.matplotlib = TRUE,
    knitron.print = "auto",
    knitron.profile = "knitr"
  )
  append(defaults[!names(defaults) %in% names(options)], options)
}

.auto_print <- function(text) {
  if (length(text) == 0)
    FALSE
  else !grepl("matplotlib", text)
}

#' An IPython engine that can be registered with knitr
#' 
#' @param options an knitr option list
#' @return output for knitr
#' @export
#' @import knitr
eng_ipython = function(options) {
  koptions <- .knitron_defaults(options)
  koptions$knitron.fig.path <- fig_path("", options, NULL)
  koptions$knitron.base.dir <- knitr::opts_knit$get("base.dir")
  
  if (is.null(koptions$fig.ext))
    koptions$fig.ext <- dev2ext(koptions$dev)
  koptions$knitron.backend <- dev2backend(koptions$dev)

  profile <- koptions$knitron.profile

  # Start the cluster automatically
  if (!profile %in% .knitron_env$profiles)
    if (!knitron.is_running(profile))
      knitron.start(profile)
  
  # We set the engine to python for further processing (highlighting)
  options$engine <- "python"

  if (paste(options$code, sep = "", collapse = "") == "")
    return(knitr::engine_output(options, options$code, NULL, NULL))
  
  result <- knitron.execute_chunk(koptions, profile)

  out <- paste(result$stdout, result$stderr,
               if (koptions$knitron.print == TRUE |
                     (koptions$knitron.print == "auto" & .auto_print(result$text))) {
                 result$text
               }, sep = "")

  extra <- sapply(result$figures, function(f) knitr::knit_hooks$get("plot")(f, options))
  knitr::engine_output(options, options$code, out, extra)
}
