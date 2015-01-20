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
  message(paste("Started IPython kernel with ID", kernel))

  # Keep a list so that we can kill the kernels later (if persist is FALSE)
  if (!persist)
    knitron_env$kernels <- append(knitron_env$kernels, kernel)
  
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
  args <- paste(knitron_env$knitron_wrapper,
                if (is.null(kernel)) knitron_env$gkernel else kernel,
                "chunk", json_file)
  system2("ipython", args, input = jsonlite::toJSON(options, auto_unbox = TRUE))
  jsonlite::fromJSON(readLines(json_file))
}

knitron.execute_code <- function(code, kernel = NULL) {
  args <- paste(knitron_env$knitron_wrapper, kernel,
                if (is.null(kernel)) knitron_env$gkernel else kernel,
                "code", code)
  system2("ipython", args, wait = TRUE)
}

#' Terminate an IPython kernel
#' 
#' @param kernel the kernel ID
#' @export
knitron.terminate <- function(kernel) {
  pskill(kernel)
  message(paste("Terminated kernel with ID", kernel))
}

knitron_defaults <- function(options) {
  defaults <- list(
    knitron.autoplot = TRUE,
    knitron.print = "auto"
  )
  append(defaults[!names(defaults) %in% names(options)], options)
}

#' An IPython engine that gets registered with knitr
#' 
#' @param options an knitr option list
#' @return output for knitr
#' @export
eng_ipython = function(options) {
  koptions <- knitron_defaults(options)
  
  result <- knitron.execute_chunk(koptions, knitron_env$knitron_kernel)
  figure <- result$figure
  output <- result$output
  
  # Print errors
  err <- paste(output[output$msg_type == "pyerr", ]$content$traceback[[1]],
               collapse="\n")
  if (err != "") {
    message("Error executing the following code:")
    cat(koptions$code, err, sep="\n")
    if (!koptions$error)
      stop("Execution was stopped due to an IPython error")
  }
  
  filtered <- output[!is.na(output$print), ]
  if ("pyout" %in% filtered$msg_type)
    if (is.logical(koptions$knitron.print))
      filtered[filtered$msg_type == "pyout", "print"] <- koptions$knitron.print

  out <- if(sum(filtered$print) > 0) {
    unname(filtered[filtered$print, , drop=F]$content$data)
  } else NULL

  extra <- if (!is.null(figure)) {
    knit_hooks$get("plot")(figure, options)
  } else NULL

  # We set the engine to python for further processing (highlighting),
  options$engine <- "python"
  knitr::engine_output(options, options$code, out, extra)
}

knitron_env <- new.env(parent = emptyenv())
knitron_env$kernels <- c()

.knitr.finalizer <- function(obj) {
  sapply(obj$knitron_env$kernels, knitron.terminate)
}

.onLoad <- function(lib, pkg) {
  knitron_wrapper <- system.file('python', 'ipython_wrapper.py', package=pkg)
  if (knitron_wrapper == "")
    knitron_wrapper <- "inst/ipython_wrapper.py"
  assign("knitron_wrapper", knitron_wrapper, envir = knitron_env)
  
  # We'll start a global kernel lazily. Yes, this isn't pretty.
  delayedAssign("gkernel", knitron.start(FALSE), assign.env = knitron_env)

  # Kill all kernels when an R session ends.
  reg.finalizer(parent.env(environment()), .knitr.finalizer, onexit = TRUE)
  
  # Register this engine with knitr,
  knit_engines$set(ipython = eng_ipython)
}

.onUnload <- function(lib, pkg) {
  # Kill all kernels when detaching the package
  .knitr.finalizer(parent.env(environment()))
}