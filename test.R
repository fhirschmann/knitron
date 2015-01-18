#!/usr/bin/env Rscript
library(knitr)
source("R/ipython.R")

knitron(knit2html, "test.Rmd")
