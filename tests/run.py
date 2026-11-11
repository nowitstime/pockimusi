#!/usr/bin/env python3
"""Run the Lua test suite with lupa's LuaJIT (pip install lupa).

Usage (from anywhere):
    python3 tests/run.py            # all tests
    python3 tests/run.py looper     # only test files whose name contains "looper"
"""
import os
import sys

try:
    from lupa.luajit21 import LuaRuntime
except ImportError:
    sys.exit("lupa with LuaJIT is required: pip install lupa")


def main():
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    lua = LuaRuntime()
    g = lua.globals()
    g.TEST_EMBEDDED = True
    if len(sys.argv) > 1:
        g.TEST_FILTER = sys.argv[1]
    failed = lua.execute('return dofile("tests/run.lua")')
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
