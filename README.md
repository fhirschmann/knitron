# knitron: knitr + IPython + matplotlib
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

That's it! Now you can use IPython in knitr using the `engine = 'ipython'` option.

## Examples


```python
import numpy as np
x = np.linspace(0, 2 * np.pi, 100)
y1 = np.sin(x)
y2 = np.sin(3 * x)
plt.fill(x, y1, 'b', x, y2, 'r', alpha=0.3)
```


![plot of chunk example1](figure/example1-1.png) 


```python
L = 6
x = np.linspace(0, L)
ncolors = len(plt.rcParams['axes.color_cycle'])
shift = np.linspace(0, L, ncolors, endpoint=False)
for s in shift:
    plt.plot(x, np.sin(x + s), 'o-')
```


![plot of chunk example2](figure/example2-1.png) 
