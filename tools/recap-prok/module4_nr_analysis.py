#!/usr/bin/env python3
import argparse
import csv
from collections import Counter

import matplotlib.pyplot as plt

COLUMNS = ["qseqid", "sseqid", "pident", "qlen", "slen", "length", "evalue", "bitscore", "stitle"]

STRICT = [
    "hypothetical protein", "uncharacterized protein", "unknown protein",
    "unnamed protein product", "predicted protein", "putative uncharacterized",
]
PUTATIVE = [
    "duf", "domain-containing protein", "family protein", "putative",
    "tigr", "y-family", "conserved protein",
]


def classify(title):
    t = (title or "").lower()
    if any(x in t for x in STRICT):
        return "Strict hypothetical/unclassified"
    if any(x in t for x in PUTATIVE):
        return "Putative functional evidence"
    return "Clear functional annotation"


def read_raw(path):
    rows = []
    with open(path, newline="", encoding="utf-8", errors="replace") as fh:
        reader = csv.reader(fh, delimiter="\t")
        for row in reader:
            if not row:
                continue
            if len(row) < 9:
                raise SystemExit(f"Expected at least 9 DIAMOND columns in {path}; found {len(row)}")
            d = dict(zip(COLUMNS, row[:9]))
            try:
                d["bitscore_num"] = float(d["bitscore"])
                d["evalue_num"] = float(d["evalue"])
            except ValueError:
                raise SystemExit("DIAMOND input must not contain a header line.")
            rows.append(d)
    return rows


def best_hits(rows):
    best = {}
    for row in rows:
        q = row["qseqid"]
        current = best.get(q)
        if current is None or (-row["bitscore_num"], row["evalue_num"]) < (-current["bitscore_num"], current["evalue_num"]):
            best[q] = row
    return list(best.values())


def summarize(rows):
    c = Counter(r["nr_class"] for r in rows)
    total = len(rows)
    result = []
    for cls in ["Strict hypothetical/unclassified", "Putative functional evidence", "Clear functional annotation"]:
        n = c.get(cls, 0)
        result.append((cls, n, (n / total * 100 if total else 0)))
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reann", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--out-best-reann", required=True)
    ap.add_argument("--out-best-ref", required=True)
    ap.add_argument("--out-summary", required=True)
    ap.add_argument("--out-pdf", required=True)
    args = ap.parse_args()

    datasets = []
    for label, path, out_best in [
        ("Re-annotated", args.reann, args.out_best_reann),
        ("Reference-mapped", args.ref, args.out_best_ref),
    ]:
        rows = best_hits(read_raw(path))
        for r in rows:
            r["nr_class"] = classify(r["stitle"])
        with open(out_best, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=COLUMNS + ["nr_class"], delimiter="\t", extrasaction="ignore")
            w.writeheader()
            w.writerows(rows)
        datasets.append((label, rows))

    with open(args.out_summary, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["Dataset", "Class", "Count", "Percent"])
        for label, rows in datasets:
            for cls, n, pct in summarize(rows):
                w.writerow([label, cls, n, f"{pct:.2f}"])

    classes = ["Strict hypothetical/unclassified", "Putative functional evidence", "Clear functional annotation"]
    x = range(len(classes))
    width = 0.35
    fig, ax = plt.subplots(figsize=(9, 5))
    for i, (label, rows) in enumerate(datasets):
        sm = dict((cls, pct) for cls, _, pct in summarize(rows))
        xs = [v + (i - 0.5) * width for v in x]
        ax.bar(xs, [sm.get(c, 0) for c in classes], width=width, label=label)
    ax.set_xticks(list(x))
    ax.set_xticklabels(["Strict hypothetical", "Putative functional", "Clear functional"], rotation=20, ha="right")
    ax.set_ylabel("Best NR hits (%)")
    ax.set_title("NR-based classification of hypothetical proteins")
    ax.legend()
    fig.tight_layout()
    fig.savefig(args.out_pdf, format="pdf")
    plt.close(fig)


if __name__ == "__main__":
    main()
