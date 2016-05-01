#' Starts an IPython cluster with one engine
#' 
#' @param profile the name of the profile
#' @param wait wait for the engine to start up
#' @param quiet be quiet about IPython's startup messages
#' @export
knitron.start <- function(profile = "knitr", wait = TRUE) {
  ipcluster <- getOption("ipcluster", "ipcluster")
  tmp <- tempfile("ipcluster_")
  args <- c("start", paste("--profile", profile, sep="="), "--n=1")
  flog.info(paste("Starting cluster for profile", profile, "via",
                  ipcluster, paste(args, collapse = " ")), name = "knitron")
  system2(ipcluster, args, wait = FALSE, stderr = tmp)
  
  # Keep a list so that we can kill the clusters later
  .knitron_env$profiles <- append(.knitron_env$profiles, profile)

  if (wait) {
    Sys.sleep(1)
    stderr <- file(tmp, "r")
    running <- FALSE

    while (!running) {
      Sys.sleep(4)
      lines <- readLines(tmp)
      running <- any(grepl("Engines appear to have started successfully", lines))
      flog.debug(paste("Waiting for IPython engine to start up (see ", tmp, ")", sep=""),
                 name = "knitron")
      if (any(grepl("Cluster is already running", lines))) {
        flog.warn("Cluster is already running - reusing")
        running <- TRUE
      }
    }
    flog.info("Engine started up successfully")
    
    if (knitron.is_running(profile)) {
      flog.info(paste("Communication with engine for profile", profile, "succeeded"))
    } else {
      flog.error(paste("Communication with engine for profile", profile, "failed"))
      stop()
    }
  }
  close(stderr)
}

#' Check for invalid Python 2/3 combinations
#' 
#' @param profile the name of the profile
#' @export
knitron.checkversion <- function(profile) {
  python <- getOption("ipython", "ipython")
  ipcluster <- getOption("ipcluster", "ipcluster")
  ipcluster_version <- knitron.execute_code("'import sys;print(sys.version_info.major)'",
                                            profile)
  ipython_version <- system2(python,
                             "-c 'import sys;print(sys.version_info.major)'",
                             stdout = TRUE)
  
  if (ipcluster_version != ipython_version) {
    flog.warn(paste("Version mismatch: ", python, " has version ", ipython_version,
                    ", but ", ipcluster, " is of version ", ipcluster_version, ". ",
                    "This will likely result in unicode errors. ", 
                    "Please set options(ipython = IPYTHON_PATH, ipcluster = IPCLUSTER_PATH).", sep = ""))
  }
}

#' Stops an IPython cluster
#' 
#' @param profile the name of the profile
#' @param quiet be quiet about IPython's shutdown messages
#' @export
knitron.stop <- function(profile = "knitr", quiet = TRUE) {
  flog.info(paste("Stopping IPython engine for profile", profile), name = "knitron")
  ipcluster <- getOption("ipcluster", "ipcluster")
  system2(ipcluster, c("stop", paste("--profile", profile, sep="=")),
          stderr = if(quiet) FALSE else "")
  .knitron_env$profiles <- setdiff(.knitron_env$profiles, profile)
}

#' Returns true if the cluster is running
#' 
#' @param profile the name of the profile
#' @return \code{TRUE} if cluster is running
#' @export
knitron.is_running <- function(profile = "knitr") {
  python <- getOption("ipython", "ipython")
  
  profiles <- gsub("^\\s+|\\s+$", "", system2(python, c("profile",  "list"), stdout = TRUE))
  if (profile %in% profiles) {
    profile_dir <- system2(python, c("profile", "locate", profile), stdout = TRUE)
    pidfile <- file.path(profile_dir, "pid", "ipcluster.pid")
    if (!file.exists(pidfile)) return(FALSE)
  } else {
    return(FALSE)
  }
  
  args <- paste(.knitron_env$knitron_wrapper, profile, "isrunning")
  flog.debug(paste("Executing", python, args), name = "knitron")
  res <- system2(python, args, wait = TRUE, stdout = TRUE, stderr = TRUE)
  tail(res, 1) == "True"
}

#' Execute a code chunk from a knitr option list
#' 
#' @param options a knitr option list
#' @param profile the name of the profile
#' @return a data frame of messages from the Python wrapper
#' @export
knitron.execute_chunk <- function(options, profile = "knitr") {
  json_file <- tempfile()
  args <- paste(.knitron_env$knitron_wrapper, profile, "chunk", json_file)
  python <- getOption("ipython", "ipython")
  flog.debug(paste("Executing code chunk via", python, args), name = "knitron")
  out <- system2(python, args, input = jsonlite::toJSON(options, auto_unbox = TRUE),
                 wait = TRUE, stdout = TRUE, stderr = TRUE)
  cat(paste(out, collapse=""))
  jsonlite::fromJSON(readLines(json_file))
}

#' Execute a single Python command
#' 
#' @param code the command to execute
#' @param profile the name of the profile
#' @return the command's stdout and stderr
#' @export
knitron.execute_code <- function(code, profile = "knitr") {
  args <- paste(.knitron_env$knitron_wrapper, profile, "code", code)
  python <- getOption("ipython", "ipython")
  flog.debug(paste("Executing", code, "via", python, args), name = "knitron")
  system2(python, args, wait = TRUE, stdout = TRUE, stderr = TRUE)
}

.knitron_defaults <- function(options) {
  defaults <- list(
    knitron.autoplot = TRUE,
    knitron.matplotlib = TRUE,
    knitron.print = "auto",
    knitron.profile = "knitr"
  )
  append(defaults[!names(defaults) %in% names(options)], options)
}

.auto_print <- function(text) {
  if (length(text) == 0)
    FALSE
  else !grepl("matplotlib", text)
}

#' An IPython engine that can be registered with knitr
#' 
#' @param options an knitr option list
#' @return output for knitr
#' @export
#' @import knitr
eng_ipython = function(options) {
  koptions <- .knitron_defaults(options)
  koptions$knitron.fig.path <- fig_path("", options, NULL)
  koptions$knitron.base.dir <- knitr::opts_knit$get("base.dir")
  if (is.null(koptions$knitron.base.dir))
    koptions$knitron.base.dir = getwd()

  if (is.null(koptions$fig.ext))
    koptions$fig.ext <- dev2ext(koptions$dev)
  koptions$knitron.backend <- dev2backend(koptions$dev)

  profile <- koptions$knitron.profile

  # Start the cluster automatically
  if (!profile %in% .knitron_env$profiles)
    if (!knitron.is_running(profile))
      knitron.start(profile)
  
  # We set the engine to python for further processing (highlighting)
  options$engine <- "python"

  if (paste(options$code, sep = "", collapse = "") == "")
    return(knitr::engine_output(options, options$code, NULL, NULL))
  
  knitron.checkversion()
  
  result <- knitron.execute_chunk(koptions, profile)

  out <- paste(result$stdout, result$stderr,
               if (koptions$knitron.print == TRUE |
                     (koptions$knitron.print == "auto" & .auto_print(result$text))) {
                 result$text
               }, sep = "")

  extra <- sapply(result$figures, function(f) knitr::knit_hooks$get("plot")(f, options))
  knitr::engine_output(options, options$code, out, extra)
}
