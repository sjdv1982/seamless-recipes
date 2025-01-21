"""
Removes all buffers in a bufferdir that do not correspond to a result
Does not require Seamless, but does require SEAMLESS_TOOLS_DIR to be defined
"""

import argparse
import os
import sys


"""
Adapted and improved from:

Bytes-to-human / human-to-bytes converter.
Based on: http://goo.gl/kTQMs
Working with Python 2.x and 3.x.

Author: Giampaolo Rodola' <g.rodola [AT] gmail [DOT] com>
License: MIT

https://code.activestate.com/recipes/578019-bytes-to-human-human-to-bytes-converter/
"""

SYMBOLS = {
    "decimal": ("B", "kB", "MB", "GB", "TB", "PB"),
    "decimal2": ("bytes", "kB", "MB", "GB", "TB", "PB"),
    "decimal_ext": (
        "bytes",
        "kilobytes",
        "megabytes",
        "gigabytes",
        "terabytes",
        "petabytes",
    ),
    "memory": ("bytes", "KB", "MB", "GB", "TB"),
    "memory2": ("B", "K", "M", "G", "T"),
    "binary": ("B", "KiB", "MiB", "GiB", "TiB", "PiB"),
    "binary2": ("bytes", "KiB", "MiB", "GiB", "TiB", "PiB"),
    "binary_ext": (
        "bytes",
        "kibibytes",
        "mebibytes",
        "gibibytes",
        "tebibytes",
        "pebibytes",
    ),
}


def bytes2human(
    n, format="%(value).1f %(symbol)s", symbols="decimal"
):  # pylint: disable=redefined-builtin
    """
    Convert n bytes into a human readable string based on format.
    """
    n = int(n)
    if n < 0:
        raise ValueError("n < 0")
    sset = SYMBOLS[symbols]
    prefix = {}
    if symbols.startswith("decimal"):
        for i, s in enumerate(sset[1:]):
            prefix[s] = 1000 ** (i + 1)
    else:
        for i, s in enumerate(sset[1:]):
            prefix[s] = 1 << (i + 1) * 10
    for symbol in reversed(sset[1:]):
        if n >= prefix[symbol]:
            value = float(n) / prefix[symbol]  # pylint: disable=W0641
            return format % locals()
    return format % dict(symbol=sset[0], value=n)


# /bytes2human

seamless_tools_dir = os.environ["SEAMLESS_TOOLS_DIR"]
sys.path.append(os.path.join(seamless_tools_dir, "tools"))

from database_models import (
    db_init,
    db_atomic,
    Transformation,
)


# from the Seamless code
def parse_checksum(checksum, as_bytes=False):
    """Parses checksum and returns it as string"""
    if isinstance(checksum, bytes):
        checksum = checksum.hex()
    if isinstance(checksum, str):
        checksum = bytes.fromhex(checksum)

    if isinstance(checksum, bytes):
        assert len(checksum) == 32, len(checksum)
        if as_bytes:
            return checksum
        else:
            return checksum.hex()

    if checksum is None:
        return
    raise TypeError(type(checksum))


p = argparse.ArgumentParser()

p.add_argument(
    "buffer_directory",
    help="""Directory where buffers are located.

Buffers have the same file name as their (SHA3-256) checksum.""",
)

p.add_argument(
    "database_file",
    help="""File (seamless.db, SQLite file) where the database is stored.""",
)

args = p.parse_args()

database_file = args.database_file
print("DATABASE FILE", database_file)
db_init(database_file)

transformations = Transformation.select().execute()
buffers_to_keep = set()
print("Transformations:", len(transformations))
for transformation in transformations:
    buffers_to_keep.add(parse_checksum(transformation.result))

space_freed = 0
files_kept = 0
files_to_delete = []
for root, dirs, files in os.walk(args.buffer_directory):
    if root != args.buffer_directory:
        dirs.clear()
    for f in files:
        if f.startswith("."):
            continue
        if root != args.buffer_directory:
            subdir = os.path.split(root)[-1]
            if not f.startswith(subdir):
                continue
        fullpath = os.path.join(root, f)
        try:
            cs = parse_checksum(f)
        except Exception:
            continue
        if cs not in buffers_to_keep:
            files_to_delete.append(fullpath)
            space_freed += os.path.getsize(fullpath)
        else:
            files_kept += 1


print("Buffer files kept:", files_kept)
print("Buffer files deleted:", len(files_to_delete))
print("Space freed:", bytes2human(space_freed))

for f in files_to_delete:
    os.remove(f)
