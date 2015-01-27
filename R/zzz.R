.knitron_env <- new.env(parent = emptyenv())
.knitron_env$kernels <- c()

.knitr.finalizer <- function(obj) {
  sapply(obj$.knitron_env$kernels, tools::pskill)
}

.onLoad <- function(lib, pkg) {
  delayedAssign("knitron_wrapper",
                system.file("python", "knitron.py", package="knitron", mustWork = TRUE),
                assign.env = .knitron_env)
  
  # We'll start a global kernel lazily. Yes, this isn't pretty.
  delayedAssign("gkernel", knitron.start(FALSE), assign.env = .knitron_env)
  
  # Kill all kernels when an R session ends.
  reg.finalizer(parent.env(environment()), .knitr.finalizer, onexit = TRUE)
  
  # Register this engine with knitr,
  knitr::knit_engines$set(ipython = eng_ipython)
}

.onUnload <- function(lib, pkg) {
  # Kill all kernels when detaching the package
  .knitr.finalizer(parent.env(environment()))
}
