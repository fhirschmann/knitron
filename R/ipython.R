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
  system2("ipython", args, input = toJSON(code))
  fromJSON(readLines(json_file))
}

IPython.terminate <- function(kernel) {
  IPython.execute(kernel, list(code="quit"))
  message("Terminated IPython kernel with ID", kernel)
}

eng_ipython = function(options, kernel) {
  require(jsonlite)
  print(options)

  result <- IPython.execute(kernel, options)
  figure <- result$figure
  output <- result$output
  
  # Collapse the stdout stream
  streams <- output[output$msg_type == "stream", ]
  out <- if (nrow(streams) > 0) streams$content$data else NULL
  
  extra <- if (!is.null(figure)) {
    #paste("![plot of chunk", options$label, "](", figure, ")", sep="")
    knit_hooks$get("plot")(figure, options)
  } else NULL
  knitr::engine_output(options, options$code, out, extra)
}

knitron <- function(knit_fun, ...) {
  kernel <- IPython.start()
  on.exit(IPython.terminate(kernel))

  knit_engines$set(ipython = function(options) eng_ipython(options, kernel = kernel))
  knit_fun(...)
}