#!/usr/bin/env python3
import argparse
import csv

import matplotlib.pyplot as plt
from Bio import SeqIO

TERMS = [
    "hypothetical protein",
    "uncharacterized protein",
    "unknown protein",
    "unnamed protein product",
    "predicted protein",
    "putative uncharacterized",
]


def is_hypothetical(product):
    p = (product or "").lower()
    return any(t in p for t in TERMS)


def analyze(path, dataset, out_faa):
    total = hypo = 0
    rows = []
    with open(out_faa, "w", encoding="utf-8") as out:
        for record in SeqIO.parse(path, "genbank"):
            for feature in record.features:
                if feature.type != "CDS":
                    continue
                total += 1
                product = feature.qualifiers.get("product", [""])[0]
                if not is_hypothetical(product):
                    continue
                translation = feature.qualifiers.get("translation", [""])[0]
                if not translation:
                    continue
                hypo += 1
                locus = feature.qualifiers.get(
                    "locus_tag",
                    feature.qualifiers.get("protein_id", ["unknown"])
                )[0]
                protein_id = feature.qualifiers.get("protein_id", ["NA"])[0]
                header = f"{dataset}|{record.id}|locus={locus}|protein={protein_id}"
                out.write(f">{header}\n{translation}\n")
                rows.append([dataset, record.id, locus, protein_id, product, header])
    return total, hypo, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reann-gb", required=True)
    ap.add_argument("--ref-gb", required=True)
    ap.add_argument("--out-table", required=True)
    ap.add_argument("--out-reann-faa", required=True)
    ap.add_argument("--out-ref-faa", required=True)
    ap.add_argument("--out-pdf", required=True)
    args = ap.parse_args()

    r_total, r_hypo, r_rows = analyze(args.reann_gb, "Re-annotated", args.out_reann_faa)
    f_total, f_hypo, f_rows = analyze(args.ref_gb, "Reference-mapped", args.out_ref_faa)

    with open(args.out_table, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["Dataset", "Protein_coding_CDSs", "Hypothetical_proteins",
                    "Hypothetical_percent", "Functionally_annotated_proteins"])
        for label, total, hypo in [
            ("Re-annotated", r_total, r_hypo),
            ("Reference-mapped", f_total, f_hypo),
        ]:
            pct = (hypo / total * 100) if total else 0
            w.writerow([label, total, hypo, f"{pct:.2f}", total - hypo])

    labels = ["Reference-mapped", "Re-annotated"]
    vals = [
        (f_hypo / f_total * 100) if f_total else 0,
        (r_hypo / r_total * 100) if r_total else 0,
    ]
    fig, ax = plt.subplots(figsize=(7, 5))
    bars = ax.bar(labels, vals)
    ax.set_ylabel("Hypothetical proteins (%)")
    ax.set_ylim(0, 100)
    ax.set_title("Hypothetical proteins: Re-annotated vs Reference-mapped")
    for bar, val in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, val + 1, f"{val:.1f}%", ha="center")
    fig.tight_layout()
    fig.savefig(args.out_pdf, format="pdf")
    plt.close(fig)


if __name__ == "__main__":
    main()
