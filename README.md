# knitron
Use IPython in knitr!

Knitron brings the power of IPython and matplotlib to [knitr](http://yihui.name/knitr/).

Currently a work in progress; it is already usable.

## Installation

```r
library(devtools)
install_github("knitron", "fhirschmann")
```

## Usage

```r
library(knitron)
```

That's it! Now you can use IPython in knitr. For markdown:

    ```{r, engine = "ipython"}
    plt.plot([1, 2, 3])
    ```
