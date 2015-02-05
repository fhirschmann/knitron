#' Starts a new IPython kernel into the background and returns its PID
#' 
#' @param profile the name of the profile
#' @return the profile name
#' @export
knitron.start <- function(profile = "knitr", wait = TRUE) {
  system2("ipcluster", c("start", paste("--profile", profile, sep="="), "--n=1"),
          wait = FALSE)
  
  # Keep a list so that we can kill the kernels later
  .knitron_env$profiles <- append(.knitron_env$profiles, profile)

  if (wait) {
    # We wait until we can reach the cluster.
    count <- 0
    while (!knitron.is_running(profile)) {
      Sys.sleep(0.5)
      count <- count + 1
      if (count > 20)
        stop("IPython cluster could not be started. Giving up.")
    }
  }
  profile
}

#' Stop
#' @export
knitron.stop <- function(profile = "knitr") {
  system2("ipcluster", c("stop", paste("--profile", profile, sep="=")))
  .knitron_env$profiles <- setdiff(.knitron_env$profiles, profile)
}

#' Returns true if the cluster is running
#' @export
knitron.is_running <- function(profile = "knitr") {
  paste(knitron.execute_code("0"), collapse="") == "0"
}

#' Execute a code chunk from a knitr option list
#' 
#' @param options a knitr option list
#' @param kernel the kernel ID to use
#' @return a data frame of messages from the Python wrapper
#' @export
knitron.execute_chunk <- function(options, profile = "knitr") {
  json_file <- tempfile()
  args <- paste(.knitron_env$knitron_wrapper, profile, "chunk", json_file)
  system2("ipython", args, input = jsonlite::toJSON(options, auto_unbox = TRUE))
  jsonlite::fromJSON(readLines(json_file))
}

#' Execute a single Python command
#' @param code the command to execute
#' @param kernel the kernel ID to use
#' @export
knitron.execute_code <- function(code, profile = "knitr") {
  args <- paste(.knitron_env$knitron_wrapper, profile, "code", code)
  system2("ipython", args, wait = TRUE, stdout = TRUE, stderr = TRUE)
}

#' Register the IPython engine with knitr
#' @import knitr
#' @export
knitron.register <- function(profile = "knitr") {
  knitr::knit_engines$set(ipython = function(options) eng_ipython(options, profile))
}

.knitron_defaults <- function(options) {
  defaults <- list(
    knitron.autoplot = TRUE,
    knitron.matplotlib = TRUE,
    knitron.print = "auto"
  )
  append(defaults[!names(defaults) %in% names(options)], options)
}

.auto_print <- function(text) {
  if (length(text) == 0)
    FALSE
  else !grepl("matplotlib", text)
}

#' An IPython engine that gets registered with knitr
#' 
#' @param options an knitr option list
#' @return output for knitr
#' @export
#' @import knitr
eng_ipython = function(options, profile = "knitr") {
  koptions <- .knitron_defaults(options)
  koptions$knitron.fig.path <- fig_path("", options, NULL)
  koptions$knitron.base.dir <- knitr::opts_knit$get("base.dir")
  
  # We set the engine to python for further processing (highlighting),
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
