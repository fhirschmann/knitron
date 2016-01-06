#!/usr/bin/env python
from __future__ import print_function
from functools import partial
from json import dump, loads
import os
import sys

try:
    from ipyparallel import Client
    from ipyparallel.client.remotefunction import RemoteFunction
except ImportError:
    from IPython.parallel import Client
    from IPython.parallel.client.remotefunction import RemoteFunction

DEBUG = bool(os.environ.get("DEBUG", False))

if sys.version_info[0] >= 3:
    unicode = str


class remote(object):
    def __init__(self, f):
        self.f = f

    def __get__(self, instance, owner):
        def wrap(*args, **kwargs):
            return RemoteFunction(instance.view, self.f,
                                  block=True)(*args, **kwargs)[0]
        return wrap


class Knitron(object):
    """
    Two-way communication with an existing IPython kernel to be used
    in the dynamic report generation framework knitr.
    """
    def __init__(self, profile):
        """
        :param kernel: the kernel id (process id)
        :type kernel: integer
        """
        self.client = Client(profile=profile)
        self.client[:].execute("%colors nocolor")
        self.view = self.client[:]

    def execute(self, *lines, **kwargs):
        """
        Execute code remotely.

        :param lines: lines to execute
        :type lines: strings
        :param print_errors: print remote errors
        :type print_errors: boolean
        :returns: (stdout, stderr, text) where text is text output
                  of msg_type == 'pyout'
        """
        code = "\n".join(lines)
        md = self.view.execute(code, block=True, silent=False).metadata[0]

        if kwargs.get("print_errors", True) and md["stderr"]:
            print(os.linesep.join(md["stderr"]))

        try:
            pyout = md["pyout"]["data"]["text/plain"]
        except (KeyError, TypeError):
            pyout = ""

        try:
            pyout += md["execute_result"]["data"]["text/plain"]
        except (KeyError, TypeError):
            pass

        return md["stdout"], md["stderr"], pyout

    @property
    def figures(self):
        """
        List of figures in the pylab state machine.
        """
        return self._figures()

    @remote
    def _figures():
        return plt.get_fignums()

    @remote
    def clear_figures():
        """
        Delete all figures in the pylab state machine.
        """
        for fignum in plt.get_fignums():
            plt.close(fignum)

    @remote
    def chdir(path):
        """
        Changes the working directory remotely and returns
        the previous working directory.

        :param path: path to change the working dir to
        :returns: path of the previous workign directory
        """
        import os

        cwd = os.getcwd()
        os.chdir(path)
        return cwd

    def ensure_matplotlib(self, backend):
        """
        Ensures that matplotlib is loaded remotely.

        :param backend: the packend to use
        :returns: True if matplotlib was loaded
        """
        return self.execute("import matplotlib",
                            "matplotlib.use('{0}', warn=False)".format(backend),
                            "import matplotlib.pyplot as plt",
                            "plt.ioff()",
                            "plt.switch_backend('{0}')".format(backend))

    @remote
    def save_figure(fignum, filename, dpi, width, height):
        """
        Save a figure to a file.

        :param fignum: the figure number
        :type fignum: int
        :param filename: file name to save to
        :type filename: str
        :param dpi: dots per inch
        :type dpi: int
        :param width: height in inches
        :type width: int
        :param height: height in inches
        :type height int
        """
        import os

        dirname = os.path.dirname(filename)
        if not os.path.exists(dirname):
            os.makedirs(dirname)

        plt.figure(fignum)
        plt.gcf().set_size_inches(width, height)
        plt.gcf().savefig(filename, dpi=dpi)


if __name__ == "__main__":
    # Usage:
    #   knitron.py PROFILE chunk JSON_OUTPUT << JSON_INPUT
    #   knitron.py PROFILE code COMMAND
    kw = Knitron(sys.argv[1])

    if sys.argv[2] == "chunk":
        options = loads(sys.stdin.read())

        if options.get("knitron.base.dir", None):
            curdir = kw.chdir(options["knitron.base.dir"])
        else:
            curdir = None

        if options["knitron.matplotlib"]:
            kw.ensure_matplotlib(options["knitron.backend"])

        if type(options["code"]) in [str, unicode]:
            options["code"] = [options["code"]]

        stdout, stderr, text = kw.execute(*options["code"])

        # Save all figures in the current chunk to files
        figures = []
        if options["knitron.matplotlib"] and options["knitron.autoplot"]:
            for fignum in kw.figures:
                filename = (options["knitron.fig.path"] + "-" + str(fignum) +
                            "." + options["fig.ext"])
                figure = options["knitron.fig.path"]
                kw.save_figure(fignum, filename, options["dpi"],
                               options["fig.width"], options["fig.height"])
                figures.append(filename)
            kw.clear_figures()

        with open(sys.argv[3], "w") as json_out:
            dump({"stdout": stdout, "stderr": stderr,
                  "text": text, "figures": figures},
                 json_out, indent=4, separators=(",", ":"))
            json_out.write("\n")

        if curdir:
            kw.chdir(curdir)
    else:
        code = sys.argv[3]
        if type(code) in [str, unicode]:
            code = [code]
        output = kw.execute(*code)
        print("".join(output), end="")
