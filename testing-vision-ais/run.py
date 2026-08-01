#!/usr/bin/env python3
"""Convenience entry point: `python run.py --generate 10 --models gemma4:12b`.
Equivalent to `python -m receipt_bench`."""

from receipt_bench.cli import main

if __name__ == "__main__":
    main()
