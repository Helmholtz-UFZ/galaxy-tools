#!/usr/bin/env python3
import argparse
import csv
import re

KO_RE = re.compile(r"(?:^|[,\s])(?:ko:)?K\d{5}(?=$|[,\s])")
GO_RE = re.compile(r"GO:\d+")


def sniff_delimiter(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.strip() or line.startswith("##"):
                continue
            return "\t" if "\t" in line else ","
    return "\t"


def load_eggnog(path):
    delimiter = sniff_delimiter(path)

    with open(path, newline="", encoding="utf-8", errors="replace") as handle:
        reader = csv.DictReader(handle, delimiter=delimiter)
        rows = list(reader)

    if not rows:
        raise SystemExit(f"No data rows found in eggNOG table: {path}")

    required = {"#query", "COG_category", "GOs", "KEGG_ko"}
    missing = required - set(rows[0].keys())
    if missing:
        raise SystemExit(
            f"Missing required eggNOG columns {sorted(missing)} in {path}. "
            f"Found: {list(rows[0].keys())}"
        )

    return rows


def count_fasta_sequences(path):
    count = 0
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if line.startswith(">"):
                count += 1
    return count


def load_go_namespace_map(path):
    namespace_to_short = {
        "biological_process": "BP",
        "molecular_function": "MF",
        "cellular_component": "CC",
    }

    go_to_namespace = {}
    current_id = None
    current_namespace = None

    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")

            if line == "[Term]":
                current_id = None
                current_namespace = None
                continue

            if not line or line.startswith("!"):
                continue

            if line.startswith("id: GO:"):
                current_id = line.split("id: ", 1)[1].strip()
                continue

            if line.startswith("namespace:"):
                current_namespace = line.split("namespace:", 1)[1].strip()

            if current_id and current_namespace:
                short = namespace_to_short.get(current_namespace)
                if short:
                    go_to_namespace[current_id] = short
                current_id = None
                current_namespace = None

    return go_to_namespace


def letters_only(value):
    return re.sub(r"[^A-Za-z]", "", (value or "").upper())


def compute_metrics(rows, faa_path, go_to_namespace):
    total = count_fasta_sequences(faa_path)

    cog_known = 0
    cog_unknown = 0
    no_hit = 0
    kegg_annotated = 0
    unique_kos = set()

    bp_genes = set()
    mf_genes = set()
    cc_genes = set()

    for row in rows:
        cog = (row.get("COG_category") or "").strip()

        if not cog or cog == "-":
            no_hit += 1
        else:
            letters = letters_only(cog)
            if letters and letters.replace("S", "") == "":
                cog_unknown += 1
            else:
                cog_known += 1

        ko_cell = (row.get("KEGG_ko") or "").strip()
        if ko_cell and ko_cell != "-" and KO_RE.search(ko_cell):
            kegg_annotated += 1

            for token in re.split(r"[,;\s|]+", ko_cell):
                token = re.sub(r"^ko:", "", token)
                if re.fullmatch(r"K\d{5}", token):
                    unique_kos.add(token)

        gene = (row.get("#query") or "").strip()
        go_cell = (row.get("GOs") or "").strip()

        if gene and gene != "-" and go_cell and go_cell != "-":
            go_ids = set(GO_RE.findall(go_cell))
            namespaces = {
                go_to_namespace.get(go_id)
                for go_id in go_ids
            }

            if "BP" in namespaces:
                bp_genes.add(gene)
            if "MF" in namespaces:
                mf_genes.add(gene)
            if "CC" in namespaces:
                cc_genes.add(gene)

    present = cog_known + cog_unknown + no_hit
    missing = max(total - present, 0)

    return {
        "Total Proteins": total,
        "COG_Known Function": cog_known,
        "COG_Unknown Function": cog_unknown,
        "No Hit": no_hit,
        "Missing": missing,
        "KEGG Annotated": kegg_annotated,
        "Unique KO": len(unique_kos),
        "GO_BP": len(bp_genes),
        "GO_MF": len(mf_genes),
        "GO_CC": len(cc_genes),
    }


def percent_change(new_value, old_value):
    if old_value == 0:
        return "NA"
    return f"{((new_value - old_value) / old_value) * 100:.2f}"


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Compare functional annotation summaries between re-annotated "
            "and reference-mapped protein sets."
        )
    )
    parser.add_argument("--reann-eggnog", required=True)
    parser.add_argument("--ref-eggnog", required=True)
    parser.add_argument("--reann-faa", required=True)
    parser.add_argument("--ref-faa", required=True)
    parser.add_argument("--go-obo", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    go_to_namespace = load_go_namespace_map(args.go_obo)

    reann_metrics = compute_metrics(
        load_eggnog(args.reann_eggnog),
        args.reann_faa,
        go_to_namespace,
    )
    ref_metrics = compute_metrics(
        load_eggnog(args.ref_eggnog),
        args.ref_faa,
        go_to_namespace,
    )

    with open(args.out, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(
            [
                "Metric",
                "Re-annotated",
                "Reference-mapped",
                "Difference",
                "Percent_change",
            ]
        )

        for metric in reann_metrics:
            new_value = reann_metrics[metric]
            old_value = ref_metrics[metric]
            writer.writerow(
                [
                    metric,
                    new_value,
                    old_value,
                    new_value - old_value,
                    percent_change(new_value, old_value),
                ]
            )


if __name__ == "__main__":
    main()
