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
  json_file = tempfile()
  args = paste("--colors", "NoColor", ipython_wrapper, kernel, "chunk", json_file)
  system2("ipython", args, input = jsonlite::toJSON(code, auto_unbox = TRUE))
  jsonlite::fromJSON(readLines(json_file))
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
      stop("Execution was stopped due to an IPython error")
  }
  
  filtered <- output[!is.na(output$print), ]
  if ("pyout" %in% filtered$msg_type)
    if (is.logical(options$knitron.print))
      filtered[filtered$msg_type == "pyout", "print"] <- options$knitron.print

  out <- if(sum(filtered$print) > 0) {
    unname(filtered[filtered$print, , drop=F]$content$data)
  } else NULL

  extra <- if (!is.null(figure)) {
    knit_hooks$get("plot")(figure, options)
  } else NULL
  print(out)
  print(extra)

  # We set the engine to python for further processing (highlighting)
  options$engine <- "python"
  knitr::engine_output(options, options$code, out, extra)
}

knitron <- function(knit_fun, ...) {
  kernel <- knitron.start()
  on.exit(knitron.terminate(kernel))

  knitr::knit_engines$set(ipython = function(options) eng_ipython(options, kernel = kernel))
  knit_fun(...)
}