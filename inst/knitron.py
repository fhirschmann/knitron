#!/usr/bin/env python
from __future__ import print_function
from json import dump, loads
import os
import sys
from time import sleep
from pprint import pprint
from Queue import Empty

from IPython.kernel import BlockingKernelClient
from IPython.lib.kernel import find_connection_file

DEBUG = bool(os.environ.get("DEBUG", False))


class Knitron(object):
    """
    Two-way communication with an existing IPython kernel to be used
    in the dynamic report generation framework knitr.
    """
    DEV_MAP = {
        "png": "AGG",
    }

    def __init__(self, kernel):
        """
        :param kernel: the kernel id (process id)
        :type kernel: integer
        """
        cf = find_connection_file(kernel)
        self.client = BlockingKernelClient(connection_file=cf)
        self.client.load_connection_file()
        self.client.start_channels()

    def execute(self, *lines, **kwargs):
        """
        Execute code initialized kernel.

        :param lines: lines to execute
        :type lines: strings
        :param print_errors: print remote errors
        :type print_errors: boolean
        :returns: (stdout, stderr, text) where text is text output
                  of msg_type == 'pyout'
        """
        code = "\n".join(lines)
        wait_for = self.client.execute(code)

        stdout = []
        text = []
        stderr = []

        while True:
            try:
                msg = self.client.get_iopub_msg(timeout=0.5)

                if DEBUG:
                    pprint(msg)

                if msg["parent_header"]["msg_id"] == wait_for:
                    if msg["content"].get("execution_state", None) == "idle":
                        break

                if msg["msg_type"] == "pyout":
                    if msg["content"]["data"].get("text/plain"):
                        text.append(msg["content"]["data"]["text/plain"])
                elif msg["msg_type"] == "pyerr":
                    stderr.extend(msg["content"]["traceback"])
                elif "data" in msg["content"]:
                    stdout.append(msg["content"]["data"])

            except Empty:
                sleep(0.1)

        if kwargs.get("print_errors", True) and stderr:
            print(os.linesep.join(stderr))

        return stdout, stderr, text

    def load_matplotlib(self, backend):
        """
        Loads matplotlib into the kernel.

        :param backend: backend to use (e.g. AGG)
        :type backend: str
        """
        _, stderr, _ = self.execute(
            "import matplotlib",
            "matplotlib.use('{0}')".format(self.DEV_MAP.get(backend, backend)),
            "import matplotlib.pyplot as plt",
            "for fignum in plt.get_fignums():",
            "   plt.close(fignum)")

    @property
    def figures(self):
        """
        List of figures in the pylab state machine.
        """
        res = self.execute("','.join(map(str, plt.get_fignums()))")
        try:
            return map(int, res[2][0][1:-1].split(","))
        except ValueError:
            return []

    def save_figure(self, fignum, filename, dpi, width, height):
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
        dirname = os.path.dirname(filename)

        self.execute(
            "import os",
            "if not os.path.exists('{0}'):".format(dirname),
            "   os.makedirs('{0}')".format(dirname),
            "plt.figure({0})".format(fignum),
            "plt.gcf().set_size_inches({0}, {1})".format(width, height),
            "plt.gcf().savefig('{0}', dpi={1})".format(filename, dpi))


if __name__ == "__main__":
    kw = Knitron(sys.argv[1])

    if sys.argv[2] == "chunk":
        options = loads(sys.stdin.read())

        # This isn't perfect, we should restore the cwd
        if options.get("knitron.base.dir", None):
            kw.execute("import os", "os.chdir('{0}')".format(options["knitron.base.dir"]))
            curdir = kw.execute("import os", "os.getcwd()")[2][0][1:-1]
        else:
            curdir = None

        if options["knitron.matplotlib"]:
            kw.load_matplotlib(options["dev"])

        if type(options["code"]) in [str, unicode]:
            options["code"] = [options["code"]]

        stdout, stderr, text = kw.execute(*options["code"])

        figures = []
        if options["knitron.matplotlib"] and options["knitron.autoplot"]:
            for fignum in kw.figures:
                filename = (options["knitron.fig.path"] + "-" + str(fignum) +
                            "." + options["dev"])
                figure = options["knitron.fig.path"]
                kw.save_figure(fignum, filename, options["dpi"], options["fig.width"],
                               options["fig.height"])
                figures.append(filename)

        with open(sys.argv[3], "w") as json_out:
            dump({"stdout": stdout, "stderr": stderr, "text": text, "figures": figures},
                 json_out, indent=4, separators=(",", ":"))
            json_out.write("\n")

        if curdir:
            kw.execute("os.chdir('{0}')".format(curdir))

    else:
        code = sys.argv[3]
        if type(code) in [str, unicode]:
            code = [code]
        kw.execute_code(*code)
