#!/usr/bin/env python3
import argparse
import csv
import json

import matplotlib.pyplot as plt


def extract_records(path):
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"Could not read antiSMASH JSON: {exc}") from exc

    if not isinstance(data, dict) or not isinstance(data.get("records"), list):
        raise SystemExit("antiSMASH JSON must contain a records array")

    for record in data["records"]:
        if not isinstance(record, dict) or not isinstance(record.get("areas"), list):
            raise SystemExit("Each antiSMASH record must contain an areas array")

    return data["records"]


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
    ap.add_argument("--antismash-json", required=True)
    ap.add_argument("--label", default="Re-annotated")
    ap.add_argument("--out", required=True)
    ap.add_argument("--out-pdf", required=True)
    args = ap.parse_args()

    counts = {}
    for rec in extract_recorddata(args.antismash_json):
        for region in rec["areas"]:
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
