#!/usr/bin/env python3
import argparse
import csv
import json
import re

import matplotlib.pyplot as plt


def extract_recorddata(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        txt = fh.read()

    match = re.search(r"var\s+recordData\s*=\s*", txt)
    if not match:
        raise SystemExit("Could not find antiSMASH recordData in regions.js")

    decoder = json.JSONDecoder()

    try:
        data, _ = decoder.raw_decode(txt[match.end():].lstrip())
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"Could not parse antiSMASH recordData in regions.js: {exc}"
        )

    if not isinstance(data, list):
        raise SystemExit("antiSMASH recordData is not a JSON array")

    return data


def classify(prod):
    p = (prod or "").lower()
    if "nrps" in p:
        return "NRPS"
    if any(x in p for x in ("t1pks", "t2pks", "t3pks", "pks")):
        return "PKS"
    if "ripp" in p:
        return "RiPP"
    if "terpene" in p:
        return "Terpene"
    if "phosphonate" in p:
        return "Phosphonate"
    if "autoinducer" in p or "auto-inducer" in p:
        return "Auto-inducer"
    if "deazapurine" in p:
        return "Deazapurine"
    return "Other"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regions-js", required=True)
    ap.add_argument("--label", default="Re-annotated")
    ap.add_argument("--out", required=True)
    ap.add_argument("--out-pdf", required=True)
    args = ap.parse_args()

    counts = {}
    for rec in extract_recorddata(args.regions_js):
        for region in rec.get("regions", []):
            products = region.get("products", []) or ["Other"]
            for prod in products:
                cls = classify(prod)
                counts[cls] = counts.get(cls, 0) + 1

    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["Dataset", "Canonical_Class", "BGC_count"])
        for cls in sorted(counts):
            w.writerow([args.label, cls, counts[cls]])

    classes = sorted(counts)
    values = [counts[c] for c in classes]
    fig, ax = plt.subplots(figsize=(8, max(4, 0.45 * len(classes))))
    ax.barh(classes, values)
    ax.set_xlabel("Number of BGCs")
    ax.set_title("antiSMASH BGC classes")
    fig.tight_layout()
    fig.savefig(args.out_pdf, format="pdf")
    plt.close(fig)


if __name__ == "__main__":
    main()
