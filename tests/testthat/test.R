run_knit <- function(code, echo = FALSE, strip = TRUE, ...) {
  tmp <- tempfile(pattern = "knitron.test.")
  dir.create(tmp)
  opts_knit$set(base.dir = tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  options <- c(..., echo = echo)
  args <- if (length(options) == 0)
    ""
  else
    paste(", ", paste(names(options),
                      sapply(options,
                             function(x) ifelse(is.character(x),
                                                paste("'", x, "'", sep=""), x)),
                      sep = "=", collapse = ","), sep = "")

  text <- paste("```{r, engine = 'ipython'", args, "}\n", code, "\n```", sep="")

  # Set quiet to FALSE when something goes wrong
  out <- knit(text=text, quiet = TRUE)
  files <- list.files(tmp, recursive = TRUE)

  if (strip)
    list(out = gsub("\n```", "", gsub("\n```\n## ", "", out)), files = files)
  else
    list(out = out, files = files)
}

test_that("Matplotlib is not loaded", {
  expect_equal(run_knit("import sys; 'matplotlib' in sys.modules", knitron.matplotlib = FALSE)$out, "False")
})

test_that("Matplotlib is loaded", {
  expect_equal(run_knit("import sys; 'matplotlib' in sys.modules")$out, "True")
})

test_that("Waiting for code exeuction", {
  expect_equal(run_knit("from time import sleep; sleep(4); 4")$out, "4")
})

test_that("Implicit printing: automatic", {
  expect_equal(run_knit(4, echo = TRUE), list(out = "python\n4\n4", files = character(0)))
  expect_equal(run_knit(4, echo = FALSE), list(out = "4", files = character(0)))
})

test_that("Implicit printing: off", {
  expect_equal(run_knit(4, echo = FALSE, knitron.autoprint = FALSE), list(out = "4", files = character(0)))
})

test_that("Empty input outputs empty output", {
  expect_equal(run_knit(""), list(out = "", files = character(0)))
})

test_that("Plot is created", {
  res <- run_knit("plt.plot([1, 2, 3])")
  expect_equal(res$out, "![plot of chunk unnamed-chunk-1](figure/unnamed-chunk-1-1.png) ")
  expect_equal(res$files, "figure/unnamed-chunk-1-1.png")
})

test_that("Two plots are created", {
  res <- run_knit(paste("x = plt.figure(); x1 = x.add_subplot(111); x1.plot([1, 2, 3])",
                    "y = plt.figure(); y1 = y.add_subplot(111); y1.plot([5, 6])", sep="\n"))
  expect_equal(res$out, paste("![plot of chunk unnamed-chunk-1](figure/unnamed-chunk-1-1.png)",
                              "\n![plot of chunk unnamed-chunk-1](figure/unnamed-chunk-1-2.png) "))
  expect_equal(res$files, c("figure/unnamed-chunk-1-1.png", "figure/unnamed-chunk-1-2.png"))
})