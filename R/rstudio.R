#' Test
#' 
#' @export
knitrPreambleAddin <- function() {
  path <- rstudioapi::getActiveDocumentContext()$path
  if (grepl("Rmd$", path))
    rstudioapi::insertText(paste("```{r, echo = FALSE}",
                                 "suppressPackageStartupMessages(library(knitron))",
                                 "```", sep = "\n"))
  else if (grepl("Rtex$", path) || grepl("Rnw$", path) )
    rstudioapi::insertText(paste("<<r, echo = FALSE>>=",
                                 "suppressPackageStartupMessages(library(knitron))",
                                 "@", sep = "\n"))
}