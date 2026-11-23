#!/usr/bin/env python3
"""Download Gene Ontology reference files and generate Galaxy data-manager JSON."""

import json
import os
import re
import sys
import urllib.request
from pathlib import Path

BASE_URL = "https://current.geneontology.org/ontology"
FILES = [
    "go-base.owl",
    "go-basic.json",
    "go-basic.json.gz",
    "go-basic.obo",
    "go-basic.ofn",
    "go-basic.owl",
    "go.json",
    "go.obo",
    "go.owl",
]


def main(output_dir, output_json, base_url=BASE_URL):
    go_dir = Path(output_dir) / "go"
    go_dir.mkdir(parents=True, exist_ok=True)

    for filename in FILES:
        print(f"Downloading {filename}", flush=True)
        urllib.request.urlretrieve(
            f"{base_url}/{filename}",
            go_dir / filename,
        )

    obo_text = (go_dir / "go-basic.obo").read_text(
        encoding="utf-8", errors="replace"
    )

    match = re.search(r"^data-version:\s*releases/(\d{4}-\d{2}-\d{2})\s*$",
                      obo_text, re.MULTILINE)
    if not match:
        raise RuntimeError("Could not determine GO release from go-basic.obo")

    version = match.group(1)

    for filename in ("go-basic.obo", "go.obo"):
        text = (go_dir / filename).read_text(
            encoding="utf-8", errors="replace"
        )
        if f"data-version: releases/{version}" not in text.splitlines()[:30]:
            raise RuntimeError(f"GO release mismatch in {filename}")

    data = {
        "data_tables": {
            "gene_ontology": [
                {
                    "path": "go/",
                    "name": f"Gene Ontology {version} {filename}",
                    "version": version,
                    "value": f"go-{version}-{filename}",
                    "file": filename,
                }
                for filename in FILES
            ]
        }
    }

    Path(output_json).write_text(
        json.dumps(data, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Downloaded GO release {version}", flush=True)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit("Usage: download_go.py OUTPUT_DIRECTORY OUTPUT_JSON [BASE_URL]")
    main(
        sys.argv[1],
        sys.argv[2],
        sys.argv[3] if len(sys.argv) == 4 else os.environ.get("GO_TEST_BASE_URL", BASE_URL),
    )
