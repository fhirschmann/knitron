#!/usr/bin/env python
from __future__ import print_function
from json import dump, JSONEncoder
import os
import sys
from time import sleep
from Queue import Empty

from IPython import Config
from IPython.kernel import BlockingKernelClient
from IPython.lib.kernel import find_connection_file

DEBUG = bool(os.environ.get("DEBUG", False))


class KnitrEncoder(JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (list, dict, str, unicode, int, float, bool, type(None))):
            if isinstance(obj, str):
                return JSONEncoder.default(self, obj)
        return "__unserializable_python_object__"


def execute(code, client):
    client.execute(code)
    output = []

    while True:
        try:
            msg = client.get_iopub_msg()
            output.append(msg)

            if msg["content"].get("execution_state", None) == "idle":
                break
        except Empty:
            sleep(0.5)

    return output


if __name__ == "__main__":
    config = Config(InteractiveApp={"colors": "NoColor"})
    cf = find_connection_file(sys.argv[1])
    client = BlockingKernelClient(config=config, connection_file=cf)
    client.load_connection_file()
    client.start_channels()

    output = execute(sys.stdin.read(), client)
    with open(sys.argv[2], "w") as json_out:
        dump(output, json_out, cls=KnitrEncoder,
             indent=4, separators=(",", ":"))
        json_out.write("\n")

    if DEBUG:
        from pprint import pprint
        pprint(output)
