run_knit <- function(code, echo = FALSE, strip = TRUE, latex = FALSE, profile = "knitr", ...) {
  tmp <- tempfile(pattern = "knitron.test.")
  dir.create(tmp)
  opts_knit$set(base.dir = tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  options <- c(..., echo = echo, knitron.profile = profile)
  args <- if (length(options) == 0)
    ""
  else
    paste(", ", paste(names(options),
                      sapply(options,
                             function(x) ifelse(is.character(x),
                                                paste("'", x, "'", sep=""), x)),
                      sep = "=", collapse = ","), sep = "")

  text <- if (latex)
    paste("<<engine = 'ipython'", args, ">>=\n", code, "\n", "@", sep="")
  else
    paste("```{r, engine = 'ipython'", args, "}\n", code, "\n```", sep="")

  # Set quiet to FALSE when something goes wrong
  out <- knit(text=text, quiet = FALSE)
  files <- list.files(tmp, recursive = TRUE)

  if (strip)
    list(out = gsub("\n```", "", gsub("\n```\n## ", "", out)), files = files)
  else
    list(out = out, files = files)
}

test_that("[markdown] Matplotlib is not loaded", {
  expect_equal(run_knit("import sys; 'matplotlib' in sys.modules", knitron.matplotlib = FALSE)$out, "False")
})

test_that("[markdown] Matplotlib is loaded", {
  expect_equal(run_knit("import sys; 'matplotlib' in sys.modules")$out, "True")
})

test_that("[markdown] Waiting for code exeuction", {
  expect_equal(run_knit("from time import sleep; sleep(4); 4")$out, "4")
})

test_that("[markdown] Implicit printing: automatic", {
  expect_equal(run_knit(4, echo = TRUE), list(out = "python\n4\n4", files = character(0)))
  expect_equal(run_knit(4, echo = FALSE), list(out = "4", files = character(0)))
})

test_that("[markdown] Implicit printing: off", {
  expect_equal(run_knit(4, echo = FALSE, knitron.autoprint = FALSE), list(out = "4", files = character(0)))
})

test_that("[markdown] Empty input outputs empty output", {
  expect_equal(run_knit(""), list(out = "", files = character(0)))
})

test_that("[markdown] Plot is created", {
  res <- run_knit("plt.plot([1, 2, 3])")
  expect_equal(res$out, "![plot of chunk unnamed-chunk-1](figure/unnamed-chunk-1-1.png) ")
  expect_equal(res$files, "figure/unnamed-chunk-1-1.png")
})

test_that("[latex] Plot is created", {
  res <- run_knit("plt.plot([1, 2, 3])", latex = TRUE)
  expect_match(res$out, "includegraphics.*figure/unnamed-chunk-1-1")
  expect_equal(res$files, "figure/unnamed-chunk-1-1.pdf")
})

test_that("[markdown] Two plots are created", {
  res <- run_knit(paste("x = plt.figure(); x1 = x.add_subplot(111); x1.plot([1, 2, 3])",
                    "y = plt.figure(); y1 = y.add_subplot(111); y1.plot([5, 6])", sep="\n"))
  expect_equal(res$out, paste("![plot of chunk unnamed-chunk-1](figure/unnamed-chunk-1-1.png)",
                              "\n![plot of chunk unnamed-chunk-1](figure/unnamed-chunk-1-2.png) "))
  expect_equal(res$files, c("figure/unnamed-chunk-1-1.png", "figure/unnamed-chunk-1-2.png"))
})

test_that("[latex] Two plots are created", {
  res <- run_knit(paste("x = plt.figure(); x1 = x.add_subplot(111); x1.plot([1, 2, 3])",
                        "y = plt.figure(); y1 = y.add_subplot(111); y1.plot([5, 6])", sep="\n"),
                  latex = TRUE)
  expect_match(res$out, "includegraphics.*figure/unnamed-chunk-1-1.*includegraphics.*figure/unnamed-chunk-1-2")
  expect_equal(res$files, c("figure/unnamed-chunk-1-1.pdf", "figure/unnamed-chunk-1-2.pdf"))
})

test_that("profiles are distinct", {
  run_knit("x = 1", profile="knitr_test_1")
  run_knit("x = 2", profile="knitr_test_2")
  expect_equal(run_knit("x", profile="knitr_test_1")$out, "1")
  expect_equal(run_knit("x", profile="knitr_test_2")$out, "2")
})