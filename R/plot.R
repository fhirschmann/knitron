# code mostly copied from knitr

# matplotlib supports quartz, but I don't have a mac

auto_exts <- c(
  postscript = 'eps', ps = 'ps', pdf = 'pdf', png = 'png', svg = 'svg',
  jpeg = 'jpeg', pictex = 'tex',
  cairo_pdf = 'pdf', cairo_ps = 'eps',

  quartz_pdf = 'pdf', quartz_png = 'png', quartz_jpeg = 'jpeg',
  quartz_tiff = 'tiff', quartz_gif = 'gif', quartz_psd = 'psd',
  quartz_bmp = 'bmp',

  CairoJPEG = 'jpeg', CairoPNG = 'png', CairoPS = 'eps', CairoPDF = 'pdf',
  CairoSVG = 'svg', CairoTIFF = 'tiff',

  Cairo_pdf = 'pdf', Cairo_png = 'png', Cairo_ps = 'eps', Cairo_svg = 'svg',

  tikz = 'tikz'
)


dev2ext <- function(x) {
  res <- auto_exts[x]
  if (any(idx <- is.na(res)))
    stop('device "', x, '" is not supported.', call. = FALSE)
  unname(res)
}


dev2backend <- function(x) {
  if (grepl("cairo", x, ignore.case = TRUE))
    "cairo"
  else if (grepl("quartz", x, ignore.case = TRUE))
    "quartz"
  else if (x == "tikz")
    "pgf"
  else if (x == "png")
    "agg"
  else if (x == "jpeg")
    "cairo"
  else if (x == "pdf")
    "pdf"
  else if (x == "postscript")
    "ps"
  else if ( x == "svg")
    "svg"
  else stop('no backend for "', x, '" found.', call. = FALSE)
  
}
