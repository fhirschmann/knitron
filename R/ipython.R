library(knitr)

ipython_wrapper <- system.file('python', 'ipython_wrapper.py', package='knitron')
if (ipython_wrapper == "") ipython_wrapper <- "inst/ipython_wrapper.py"

knitron.start <- function() {
  ipython_tmp <- tempfile()

  # Start new kernel
  system2("ipython", "kernel", stdout = ipython_tmp, wait = FALSE)
  
  # We wait a while for IPython to write its kernel ID to ipython_tmp
  Sys.sleep(1)
  
  kernel <- as.integer(gsub("\\D", "", grep("--existing", readLines(ipython_tmp), value = TRUE)))
  message(paste("Started IPython kernel with ID", kernel))

  kernel
}

knitron.execute_chunk <- function(kernel, code) {
  require(jsonlite)
  
  json_file = tempfile()
  args = paste("--colors", "NoColor", ipython_wrapper, kernel, "chunk", json_file)
  system2("ipython", args, input = toJSON(code, auto_unbox = TRUE))
  fromJSON(readLines(json_file))
}

knitron.execute_code <- function(kernel, code) {
  args = paste(ipython_wrapper, kernel, "code", code)
  system2("ipython", args)
}

knitron.terminate <- function(kernel) {
  knitron.execute_code(kernel, "quit")
  message("Terminated IPython kernel with ID", kernel)
}

knitron_defaults <- function(options) {
  defaults <- list(
    knitron.autoplot = TRUE,
    knitron.print = "auto"
  )
  append(defaults[!names(defaults) %in% names(options)], options)
}

eng_ipython = function(options, kernel) {
  require(jsonlite)
  options <- knitron_defaults(options)
  
  result <- knitron.execute_chunk(kernel, options)
  figure <- result$figure
  output <- result$output
  
  # Print errors
  err <- paste(output[output$msg_type == "pyerr", ]$content$traceback[[1]], collapse="\n")
  if (err != "") {
    message("Error executing the following code:")
    cat(options$code, err, sep="\n")
    if (!options$error)
      stop("Execution was stopped due to a IPython error")
  }
  
  output <- output[output$msg_type %in% c("stream", "pyout"), ]
  if (options$knitron.print == TRUE) {
    # User overwrites automatic selection
    output$print <- TRUE
  } else {
    # Always print stdout stream
    output[output$msg_type == "stream", "print"] <- TRUE
  }
  
  out <- if (sum(output$print) > 0) {
    output[output$print, ]$content$data
  } else NULL
    
  extra <- if (!is.null(figure)) {
    knit_hooks$get("plot")(figure, options)
  } else NULL

  # We set the engine to python for further processing (highlighting)
  options$engine <- "python"
  knitr::engine_output(options, options$code, out, extra)
}

knitron <- function(knit_fun, ...) {
  kernel <- knitron.start()
  on.exit(knitron.terminate(kernel))

  knit_engines$set(ipython = function(options) eng_ipython(options, kernel = kernel))
  knit_fun(...)
}