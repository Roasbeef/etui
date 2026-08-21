#!/usr/bin/env python3
"""Does the documentation call functions that exist?

    python3 dev/check_docs_api.py

Reads the public API straight out of src/ and checks every `module.thing`
in every ```gleam block under docs/ (and in README.md) against it. It found
four sections describing widgets that had been rewritten underneath them —
a canvas with `set_pixel`, a scene with `add`, a line taking a direction, a
bar chart with a constructor that had been renamed — all of which had been
wrong for long enough that nobody had tried to run them.

It is a name check, not a type check: it catches documentation that has
drifted from the API, not documentation that misuses it. The compiler covers
the second half for the snippets that live in a test module.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Snippets that show pre-2.0 code on purpose.
HISTORICAL = {"geometry.split_flex"}


def public_api():
    """module short name -> every public name in it, constructors included."""
    api = {}
    for path in sorted((REPO / "src").rglob("*.gleam")):
        short = path.stem
        names = api.setdefault(short, set())
        src = path.read_text()
        names.update(re.findall(r"^pub fn (\w+)", src, re.M))
        names.update(re.findall(r"^pub const (\w+)", src, re.M))
        for m in re.finditer(r"^pub (?:opaque )?type (\w+)(?:\([^)]*\))?\s*\{(.*?)^\}", src, re.M | re.S):
            names.add(m.group(1))
            body = "\n".join(
                line for line in m.group(2).splitlines()
                if not line.strip().startswith("//")
            )
            names.update(re.findall(r"\b([A-Z]\w*)", body))
        # `pub type X = Y` aliases have no body
        names.update(re.findall(r"^pub type (\w+)\s*=", src, re.M))
    return api


def blocks(text):
    return re.findall(r"```gleam\n(.*?)```", text, re.S)


def main():
    api = public_api()
    problems = []

    docs = sorted((REPO / "docs").glob("*.md")) + [REPO / "README.md"]
    for doc in docs:
        for block in blocks(doc.read_text()):
            # A block that imports gleam/list means `list.` is the stdlib's,
            # not the widget's. So does a block that imports the widget under
            # another name, which is what every list example does.
            stdlib = set(re.findall(r"^import gleam/(\w+)", block, re.M))
            stdlib.update(
                m.rsplit("/", 1)[-1]
                for m in re.findall(r"^import (etui/\S+) as \w+", block, re.M)
            )
            for mod, name in re.findall(r"\b([a-z_]+)\.([a-zA-Z]\w*)", block):
                if mod not in api or mod in stdlib:
                    continue
                if f"{mod}.{name}" in HISTORICAL:
                    continue
                if name not in api[mod]:
                    problems.append(f"{doc.relative_to(REPO)}: {mod}.{name}")

    for p in sorted(set(problems)):
        print("  " + p)
    print(f"{len(set(problems))} name(s) in the docs that src/ does not define")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
