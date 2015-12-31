PKGNAME := $(shell sed -n "s/Package: *\([^ ]*\)/\1/p" DESCRIPTION)
PKGVERS := $(shell sed -n "s/Version: *\([^ ]*\)/\1/p" DESCRIPTION)
PKGSRC  := $(shell basename `pwd`)
.PHONY: tests

build-cran:
	cd ..;\
	R CMD build $(PKGSRC)

install: build-cran
	cd ..;\
	R CMD INSTALL $(PKGNAME)_$(PKGVERS).tar.gz

README.md: README.Rmd
	Rscript -e 'library(knitron); knit("README.Rmd")'

check: build-cran
	cd ..;\
	R CMD check $(PKGNAME)_$(PKGVERS).tar.gz --as-cran

tests:
	cd tests;\
	./testthat.R
