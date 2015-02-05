.knitr.finalizer <- function(obj) {
  sapply(obj$.knitron_env$profiles, obj$knitron.stop)
}

.onLoad <- function(lib, pkg) {
  delayedAssign("knitron_wrapper",
                system.file("python", "knitron.py", package="knitron", mustWork = TRUE),
                assign.env = .knitron_env)
  
  knitr::knit_engines$set(ipython = eng_ipython)
  
  # Kill all kernels when an R session ends.
  reg.finalizer(parent.env(environment()), .knitr.finalizer, onexit = TRUE)
}

.onUnload <- function(lib, pkg) {
  # Kill all kernels when detaching the package
  .knitr.finalizer(parent.env(environment()))
}
