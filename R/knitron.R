#' Starts a new IPython kernel into the background and returns its PID
#' 
#' @param persist don't kill the process after R exits
#' @return the process id
#' @export
knitron.start <- function(persist = FALSE) {
  ipython_tmp <- tempfile()

  # Start new kernel
  system2("ipython", "kernel", stdout = ipython_tmp, wait = FALSE)
  
  # We wait a while for IPython to write its kernel ID to ipython_tmp
  Sys.sleep(1)
  
  kernel <- as.integer(gsub("\\D", "", grep("--existing",
                                            readLines(ipython_tmp), value = TRUE)))
  message(paste("Knitron: Started IPython kernel with ID", kernel))

  # Keep a list so that we can kill the kernels later (if persist is FALSE)
  if (!persist)
    .knitron_env$kernels <- append(.knitron_env$kernels, kernel)
  
  kernel
}

#' Execute a code chunk from a knitr option list
#' 
#' @param options a knitr option list
#' @param kernel the kernel ID to use
#' @return a data frame of messages from the Python wrapper
#' @export
knitron.execute_chunk <- function(options, kernel = NULL) {
  json_file <- tempfile()
  args <- paste(.knitron_env$knitron_wrapper,
                if (is.null(kernel)) .knitron_env$gkernel else kernel,
                "chunk", json_file)
  system2("ipython", args, input = jsonlite::toJSON(options, auto_unbox = TRUE))
  jsonlite::fromJSON(readLines(json_file))
}

#' Execute a single Python command
#' @param code the command to execute
#' @param kernel the kernel ID to use
#' @export
knitron.execute_code <- function(code, kernel = NULL) {
  args <- paste(.knitron_env$knitron_wrapper, kernel,
                if (is.null(kernel)) .knitron_env$gkernel else kernel,
                "code", code)
  system2("ipython", args, wait = TRUE)
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
eng_ipython = function(options) {
  koptions <- .knitron_defaults(options)
  koptions$knitron.fig.path <- fig_path("", options, NULL)
  koptions$knitron.base.dir <- knitr::opts_knit$get("base.dir")
  
  # We set the engine to python for further processing (highlighting),
  options$engine <- "python"

  if (paste(options$code, sep = "", collapse = "") == "")
    return(knitr::engine_output(options, options$code, NULL, NULL))
  
  result <- knitron.execute_chunk(koptions, .knitron_env$knitron_kernel)

  out <- paste(result$stdout, result$stderr,
               if (koptions$knitron.print == TRUE |
                     (koptions$knitron.print == "auto" & .auto_print(result$text))) {
                 result$text
               }, sep = "")

  extra <- sapply(result$figures, function(f) knitr::knit_hooks$get("plot")(f, options))
  knitr::engine_output(options, options$code, out, extra)
}
