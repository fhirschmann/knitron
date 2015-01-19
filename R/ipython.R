library(knitr)

ipython_wrapper <- system.file('python', 'ipython_wrapper.py', package='knitron')
if (ipython_wrapper == "") ipython_wrapper <- "inst/ipython_wrapper.py"

IPython.start <- function() {
  ipython_tmp <- tempfile()

  # Start new kernel
  system2("ipython", "kernel", stdout = ipython_tmp, wait = FALSE)
  
  # We wait a while for IPython to write its kernel ID to ipython_tmp
  Sys.sleep(1)
  
  kernel <- as.integer(gsub("\\D", "", grep("--existing", readLines(ipython_tmp), value = TRUE)))
  message(paste("Started IPython kernel with ID", kernel))

  kernel
}

IPython.execute_chunk <- function(kernel, code) {
  require(jsonlite)
  
  json_file = tempfile()
  args = paste("--colors", "NoColor", ipython_wrapper, kernel, "chunk", json_file)
  system2("ipython", args, input = toJSON(code, auto_unbox = TRUE))
  fromJSON(readLines(json_file))
}

IPython.execute_code <- function(kernel, code) {
  args = paste(ipython_wrapper, kernel, "code", code)
  system2("ipython", args)
}

IPython.terminate <- function(kernel) {
  IPython.execute_code(kernel, "quit")
  message("Terminated IPython kernel with ID", kernel)
}

eng_ipython = function(options, kernel) {
  require(jsonlite)

  result <- IPython.execute_chunk(kernel, options)
  figure <- result$figure
  output <- result$output
  
  # Print errors
  err <- paste(output[output$msg_type == "pyerr", ]$content$traceback[[1]], collapse="\n")
  if (err != "") {
    message("Error executing the following code:")
    cat(options$code, err, sep="\n")
    stop("Execution was stopped due to a IPython error")
  }
  
  # Collapse the stdout stream
  streams <- output[output$msg_type == "stream", ]
  out <- if (nrow(streams) > 0) streams$content$data else NULL

  # We could also get the pyout stream so that you don't have to write
  # print(foo). However, this also means that we'll see the the string
  # representation of plt.plot in our output. Suggestions welcome.
  
  extra <- if (!is.null(figure)) {
    knit_hooks$get("plot")(figure, options)
  } else NULL

  # We set the engine to python for further processing (highlighting)
  options$engine <- "python"
  knitr::engine_output(options, options$code, out, extra)
}

knitron <- function(knit_fun, ...) {
  kernel <- IPython.start()
  on.exit(IPython.terminate(kernel))

  knit_engines$set(ipython = function(options) eng_ipython(options, kernel = kernel))
  knit_fun(...)
}