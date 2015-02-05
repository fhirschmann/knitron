#' IPython and Matplotlib integration for knitr
#' 
#' After loading this package, you can make use of the \code{engine = 'ipython'}
#' chunk option in \pkg{knitr}.
#' 
#' @author Fabian Hirschmann <\url{http://0x0b.de}>
#' @docType package
#' @name knitron
NULL

.knitron_env <- new.env(parent = emptyenv())
.knitron_env$profiles <- c()