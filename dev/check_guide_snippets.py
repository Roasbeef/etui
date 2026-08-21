#!/usr/bin/env python3
"""Does the migration guide still say what the code does?

    python3 dev/check_guide_snippets.py

docs/migrating-to-2.0.md claims that every snippet in it is compiled by
test/migration_examples_test.gleam. This checks that claim the only way it can
be checked: every identifier the guide's "2.0" snippets call has to appear in
the test module, and every figure in its tables has to appear there too.

It is deliberately crude — a substring check, not a parser. A guide that
drifts usually drifts by renaming a function or changing a number, and that is
what this catches. Whether the numbers are *right* is the test module's job:
it asserts them against the library.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GUIDE = REPO / "docs" / "migrating-to-2.0.md"
TESTS = REPO / "test" / "migration_examples_test.gleam"

# Calls that belong to the "before" column: they are 1.x and cannot compile.
OLD_ONLY = {"split_flex"}


def gleam_blocks(text):
    return re.findall(r"```gleam\n(.*?)```", text, re.S)


def called_names(block):
    # module-qualified calls: style.new(, buffer.set_string(, keys.parse(
    return set(re.findall(r"\b([a-z_]+\.[a-z_]+)\(", block))


def table_numbers(text):
    """Size lists from the 2.0.0 column only.

    The 1.0.1 column is what the old code did and cannot be asserted from
    this repository; the guide says as much, and says how to reproduce it.
    """
    found = set()
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) != 3:
            continue
        found.update(re.findall(r"`(\[\d+(?:, \d+)*\])`", cells[2]))
    return found


def main():
    guide, tests = GUIDE.read_text(), TESTS.read_text()
    problems = []

    for block in gleam_blocks(guide):
        for name in called_names(block):
            bare = name.split(".", 1)[1]
            if bare in OLD_ONLY:
                continue
            if name not in tests:
                problems.append(f"guide calls {name}(), which the test module never does")

    for numbers in table_numbers(guide):
        # `[60, 60]` and friends appear in the 1.0.1 column too; only the ones
        # the test module asserts matter, so a missing one is reported once.
        if numbers not in tests:
            problems.append(f"guide shows {numbers}, which the test module never asserts")

    for p in sorted(set(problems)):
        print("  " + p)
    print(f"{len(set(problems))} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
