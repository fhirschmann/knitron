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

IPython.execute <- function(kernel, code) {
  require(jsonlite)
  
  json_file = tempfile()
  args = paste("--colors", "NoColor", ipython_wrapper, kernel, json_file)
  system2("ipython", args, input = code)
  fromJSON(readLines(json_file))
}

IPython.terminate <- function(kernel) {
  IPython.execute(kernel, "quit")
  message("Terminated IPython kernel with ID", kernel)
}

eng_ipython = function(options, kernel) {
  require(jsonlite)

  output <- IPython.execute(kernel, options$code)
  
  # Collapse the stdout stream
  streams <- paste(output[output$msg_type == "stream", ]$content$data, collapse="")
  
  knitr::engine_output(options, options$code, streams, extra = NULL)
}

knitron <- function(knit_fun, ...) {
  kernel <- IPython.start()
  on.exit(IPython.terminate(kernel))

  knit_engines$set(ipython = function(options) eng_ipython(options, kernel = kernel))
  knit_fun(...)
}