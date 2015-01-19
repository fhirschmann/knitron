#!/usr/bin/env python
from __future__ import print_function
from json import dump, loads, JSONEncoder
import os
import sys
from time import sleep
from pprint import pprint
from Queue import Empty

from IPython.kernel import BlockingKernelClient
from IPython.lib.kernel import find_connection_file

DEBUG = bool(os.environ.get("DEBUG", False))


class KnitrEncoder(JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (list, dict, str, unicode, int, float, bool, type(None))):
            if isinstance(obj, str):
                return JSONEncoder.default(self, obj)
        return "__unserializable_python_object__"


def auto_print(obj):
    content = obj["content"]

    if "matplotlib" in str(content):
        return False

    return True


class KnitrWrapper(object):
    DEV_MAP = {
        "png": "AGG",
    }

    def __init__(self, kernel):
        cf = find_connection_file(kernel)
        self.client = BlockingKernelClient(connection_file=cf)
        self.client.load_connection_file()
        self.client.start_channels()

    def load_matplotlib(self, backend):
        self.execute_code(
            "import matplotlib",
            "matplotlib.use('{0}')".format(backend),
            "import matplotlib.pyplot as plt",
            "for fignum in plt.get_fignums():",
            "   plt.close(fignum)")

    @property
    def has_figure(self):
        for msg in self.execute_code("bool(plt.get_fignums())"):
            try:
                return msg["content"]["data"]["text/plain"] == "True"
            except KeyError:
                pass

        return False

    def save_figure(self, filename, dpi, width, height):
        self.execute_code(
            "plt.gcf().set_size_inches({0}, {1})".format(width, height),
            "plt.gcf().savefig('{0}', dpi={1})".format(filename, dpi))

    def execute_code(self, *lines):
        self.client.execute("\n".join(lines))
        output = []

        while True:
            try:
                msg = self.client.get_iopub_msg()
                output.append(msg)

                if msg["msg_type"] == "pyout":
                    msg["print"] = auto_print(msg)

                if msg["content"].get("execution_state", None) == "idle":
                    break
            except Empty:
                sleep(0.1)

        return output

    def execute(self, options):
        if DEBUG:
            pprint(options)

        self.load_matplotlib(self.DEV_MAP.get(options["dev"], options["dev"]))
        output = self.execute_code(*options["code"])

        if options["knitron.autoplot"] and self.has_figure:
            figure = "{0[fig.path]}{0[label]}.{0[dev]}".format(options)
            self.save_figure(figure, options["dpi"],
                             options["fig.width"], options["fig.height"])

            return output, figure

        return output, None


if __name__ == "__main__":
    kw = KnitrWrapper(sys.argv[1])

    if sys.argv[2] == "chunk":
        options = loads(sys.stdin.read())
        if type(options["code"]) in [str, unicode]:
            options["code"] = [options["code"]]

        output, figure = kw.execute(options)

        with open(sys.argv[3], "w") as json_out:
            dump({"output": output, "figure": figure}, json_out, cls=KnitrEncoder,
                indent=4, separators=(",", ":"))
            json_out.write("\n")

        if DEBUG:
            pprint(output)
    else:
        code = sys.argv[3]
        if type(code) in [str, unicode]:
            code = [code]
        kw.execute_code(*code)
