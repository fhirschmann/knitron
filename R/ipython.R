library(knitr)
ipython_wrapper <- "ipython_wrapper.py"

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
  args = paste('--colors', 'NoColor', ipython_wrapper, kernel,
               'eval', json_file)
  system2("ipython", args, input = code)
  fromJSON(readLines(json_file))
}

IPython.terminate <- function(kernel) {
  system2("ipython", paste(ipython_wrapper, kernel, "quit"))
  message("Terminated IPython kernel with ID", kernel)
}

delayedAssign("global_kernel", {
  kernel <- IPython.start()
  on.exit(IPython.terminate(kernel))
  kernel
})

eng_ipython = function(options) {
  require(jsonlite)

  output <- IPython.execute(global_kernel, options$code)
  
  # Collapse the stdout stream
  streams = paste(output[output$msg_type == "stream", ]$content$data, collapse="")
  
  knitr::engine_output(options, options$code, streams, extra = NULL)
}
knit_engines$set(ipython = eng_ipython)


knitron <- function(fun, ...) {
  kernel <- IPython.start()
  on.exit(IPython.terminate(kernel))
  
  fun(...)
}