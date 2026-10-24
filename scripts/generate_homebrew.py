#!/usr/bin/env python3
"""Generate a tap formula from the exact release archives being published."""

import hashlib
from pathlib import Path
import re
import sys


def generate(version, artifacts, output):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Homebrew releases require a stable major.minor.patch version")
    template = Path(__file__).resolve().parents[1] / "packaging/homebrew/ci-book-tracker.rb.in"
    formula = template.read_text().replace("@VERSION@", version)
    for target in ("macos-arm64", "macos-x86_64", "linux-x86_64"):
        archive = artifacts / f"ci-book-tracker-{version}-{target}.tar.gz"
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        formula = formula.replace("@" + target.upper().replace("-", "_") + "_SHA256@", digest)
    output.write_text(formula)


if __name__ == "__main__":
    generate(sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]))
