#!/usr/bin/env python3

import argparse
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import pandas as pd

matplotlib.use("Agg")

# =========================================================
# Arguments
# =========================================================

parser = argparse.ArgumentParser(
    description=(
        "Interpret RECAP-PROK Module 3 classified CDS pairs "
        "and generate the final summary table and figures."
    )
)

parser.add_argument(
    "--manifest",
    required=True,
    help="TSV with columns: path, label, sequence_type",
)

parser.add_argument(
    "--output-table",
    required=True,
    help="Final Module 3 CDS interpretation summary TSV.",
)

parser.add_argument(
    "--legend",
    required=True,
    help="Output legend TXT file.",
)

parser.add_argument(
    "--output-dir",
    required=True,
    help="Output directory for figures.",
)

args = parser.parse_args()

manifest_path = Path(args.manifest)
output_table = Path(args.output_table)
legend_file = Path(args.legend)
outdir = Path(args.output_dir)

output_table.parent.mkdir(parents=True, exist_ok=True)
legend_file.parent.mkdir(parents=True, exist_ok=True)
outdir.mkdir(parents=True, exist_ok=True)


# =========================================================
# Helper functions
# =========================================================

def cds_length(start, end):
    return abs(int(end) - int(start)) + 1


def classify_direction(row):
    """
    Strand-aware CDS extension/truncation interpretation.

    Scientific logic retained from the original RECAP-PROK
    Module 3 interpretation.
    """

    strand = str(row["ref_strand"]).strip()

    ref_start = int(row["ref_start"])
    ref_end = int(row["ref_end"])
    re_start = int(row["reann_start"])
    re_end = int(row["reann_end"])

    ref_len = cds_length(ref_start, ref_end)
    re_len = cds_length(re_start, re_end)

    if ref_len == re_len:
        return "same"

    if strand == "+":
        if re_start < ref_start:
            return "extension_after_reannotation"

        if re_start > ref_start:
            return "truncation_after_reannotation"

    elif strand == "-":
        if re_end > ref_end:
            return "extension_after_reannotation"

        if re_end < ref_end:
            return "truncation_after_reannotation"

    # Fallback based on total CDS length.
    if re_len > ref_len:
        return "extension_after_reannotation"

    if re_len < ref_len:
        return "truncation_after_reannotation"

    return "same"


# =========================================================
# Read manifest
# =========================================================

manifest = pd.read_csv(
    manifest_path,
    sep="\t",
    dtype=str,
)

required_manifest_columns = {
    "path",
    "label",
    "sequence_type",
}

missing = required_manifest_columns - set(manifest.columns)

if missing:
    raise ValueError(
        "Manifest missing required column(s): "
        + ", ".join(sorted(missing))
    )

if manifest.empty:
    raise ValueError("Manifest contains no input datasets.")

manifest["sequence_type"] = (
    manifest["sequence_type"]
    .astype(str)
    .str.strip()
    .str.lower()
)

allowed_types = {"bacteria", "plasmid"}

invalid = sorted(
    set(manifest["sequence_type"]) - allowed_types
)

if invalid:
    raise ValueError(
        "Invalid sequence_type value(s): "
        + ", ".join(invalid)
    )

print(f"Found {len(manifest)} input dataset(s)")


# =========================================================
# Main analysis
# =========================================================

summaries = []

for _, entry in manifest.iterrows():

    file = Path(entry["path"])
    label = str(entry["label"]).strip()
    seq_type = str(entry["sequence_type"]).strip().lower()

    if not file.exists():
        raise FileNotFoundError(
            f"Input file not found: {file}"
        )

    print(f"Processing: {label}")

    df = pd.read_csv(
        file,
        sep="\t",
    )

    required_columns = {
        "ref_id",
        "reann_id",
        "class",
        "ref_chr",
        "ref_start",
        "ref_end",
        "ref_strand",
        "reann_start",
        "reann_end",
        "reann_strand",
        "ovl",
        "roA",
        "roB",
    }

    missing_columns = required_columns - set(df.columns)

    if missing_columns:
        raise ValueError(
            f"{label}: missing required column(s): "
            + ", ".join(sorted(missing_columns))
        )

    sequence_type = (
        "bacterial chromosome"
        if seq_type == "bacteria"
        else "plasmid"
    )

    total_pairs = len(df)

    # -----------------------------------------------------
    # Exact matches
    # -----------------------------------------------------

    exact_matches = (
        df["class"]
        .astype(str)
        .eq("MATCH_ALL")
        .sum()
    )

    # -----------------------------------------------------
    # CDS lengths and direction
    # -----------------------------------------------------

    mapped = df.dropna(
        subset=[
            "ref_start",
            "ref_end",
            "reann_start",
            "reann_end",
        ]
    ).copy()

    mapped["ref_len"] = mapped.apply(
        lambda r: cds_length(
            r["ref_start"],
            r["ref_end"],
        ),
        axis=1,
    )

    mapped["reann_len"] = mapped.apply(
        lambda r: cds_length(
            r["reann_start"],
            r["reann_end"],
        ),
        axis=1,
    )

    mapped["length_diff"] = (
        mapped["reann_len"]
        - mapped["ref_len"]
    )

    mapped["direction_class"] = mapped.apply(
        classify_direction,
        axis=1,
    )

    extensions = int(
        (
            mapped["direction_class"]
            == "extension_after_reannotation"
        ).sum()
    )

    truncations = int(
        (
            mapped["direction_class"]
            == "truncation_after_reannotation"
        ).sum()
    )

    # In the final Module 3 interpretation table,
    # LS represents CDS boundary/locus shifts.
    locus_shifts = extensions + truncations

    # -----------------------------------------------------
    # Percentages
    # -----------------------------------------------------

    if total_pairs > 0:

        exact_percent = round(
            exact_matches / total_pairs * 100,
            2,
        )

        extension_percent = round(
            extensions / total_pairs * 100,
            2,
        )

        truncation_percent = round(
            truncations / total_pairs * 100,
            2,
        )

    else:
        exact_percent = 0.0
        extension_percent = 0.0
        truncation_percent = 0.0

    # -----------------------------------------------------
    # Mean CDS length change
    # -----------------------------------------------------

    if not mapped.empty:
        mean_length_change = round(
            mapped["length_diff"].mean(),
            2,
        )
    else:
        mean_length_change = 0.0

    # -----------------------------------------------------
    # Final compact table
    # -----------------------------------------------------

    summaries.append(
        {
            "Genome": label,

            "ST_{a}":
                sequence_type,

            "EM_{b}":
                int(exact_matches),

            "EM_(%)_{c}":
                exact_percent,

            "EXT_{d}":
                extensions,

            "EXT_(%)_{e}":
                extension_percent,

            "TRUNC_{f}":
                truncations,

            "TRUNC_(%)_{g}":
                truncation_percent,

            "LS_{h}":
                locus_shifts,

            "Mean_∆CDS_(bp)_{i}":
                mean_length_change,
        }
    )


summary_df = pd.DataFrame(summaries)

summary_df.to_csv(
    output_table,
    sep="\t",
    index=False,
)


# =========================================================
# Separate bacteria and plasmids for figures
# =========================================================

bacteria_df = summary_df[
    summary_df["ST_{a}"]
    == "bacterial chromosome"
].copy()

plasmid_df = summary_df[
    summary_df["ST_{a}"]
    == "plasmid"
].copy()


# =========================================================
# Plot functions
# =========================================================

def add_segment_label(
    ax,
    x,
    y_center,
    percent,
    count,
    total,
    color="black",
):

    ax.text(
        x,
        y_center,
        f"{percent:.1f}%\n({count}/{total})",
        ha="center",
        va="center",
        fontsize=8,
        color=color,
        fontweight="bold",
    )


def plot_stacked_percent(
    df,
    title,
    filename,
    xlabel,
):

    if df.empty:
        print(f"Skipping {filename}: no input data")
        return

    fig, ax = plt.subplots(
        figsize=(13, 6)
    )

    x = list(range(len(df)))

    exact = df["EM_(%)_{c}"]
    ext = df["EXT_(%)_{e}"]
    trunc = df["TRUNC_(%)_{g}"]

    ax.bar(
        x,
        exact,
        label=(
            "Exact match: NCBI reference CDS = "
            "Prodigal re-annotation CDS"
        ),
    )

    ax.bar(
        x,
        ext,
        bottom=exact,
        label=(
            "Prodigal CDS extension relative "
            "to NCBI reference"
        ),
    )

    bottom_ext = exact + ext

    ax.bar(
        x,
        trunc,
        bottom=bottom_ext,
        label=(
            "Prodigal CDS truncation relative "
            "to NCBI reference"
        ),
    )

    for i, row in df.reset_index(
        drop=True
    ).iterrows():

        total = (
            int(row["EM_{b}"])
            + int(row["EXT_{d}"])
            + int(row["TRUNC_{f}"])
        )

        if row["EM_(%)_{c}"] >= 5:
            add_segment_label(
                ax,
                i,
                row["EM_(%)_{c}"] / 2,
                row["EM_(%)_{c}"],
                int(row["EM_{b}"]),
                total,
                color="white",
            )

        if row["EXT_(%)_{e}"] >= 5:
            add_segment_label(
                ax,
                i,
                (
                    row["EM_(%)_{c}"]
                    + row["EXT_(%)_{e}"] / 2
                ),
                row["EXT_(%)_{e}"],
                int(row["EXT_{d}"]),
                total,
            )

        if row["TRUNC_(%)_{g}"] >= 5:
            add_segment_label(
                ax,
                i,
                (
                    row["EM_(%)_{c}"]
                    + row["EXT_(%)_{e}"]
                    + row["TRUNC_(%)_{g}"] / 2
                ),
                row["TRUNC_(%)_{g}"],
                int(row["TRUNC_{f}"]),
                total,
            )

    ax.set_ylim(0, 100)

    ax.set_ylabel(
        "CDS proportion of mapped CDS pairs (%)"
    )

    ax.set_xlabel(xlabel)
    ax.set_title(title)

    ax.set_xticks(x)

    ax.set_xticklabels(
        df["Genome"],
        rotation=45,
        ha="right",
    )

    ax.legend(
        frameon=False,
        bbox_to_anchor=(1.02, 1),
        loc="upper left",
    )

    plt.tight_layout()

    plt.savefig(
        outdir / f"{filename}.png",
        dpi=300,
        bbox_inches="tight",
    )

    plt.close()


def plot_mean_length(
    df,
    title,
    filename,
    xlabel,
):

    if df.empty:
        print(f"Skipping {filename}: no input data")
        return

    fig, ax = plt.subplots(
        figsize=(12, 5)
    )

    x = list(range(len(df)))

    values = df["Mean_∆CDS_(bp)_{i}"]

    ax.bar(
        x,
        values,
    )

    ax.axhline(
        0,
        linewidth=1,
    )

    for i, row in df.reset_index(
        drop=True
    ).iterrows():

        value = row["Mean_∆CDS_(bp)_{i}"]

        ax.text(
            i,
            value,
            f"{value:.2f} bp",
            ha="center",
            va=(
                "bottom"
                if value >= 0
                else "top"
            ),
            fontsize=8,
        )

    ax.set_ylabel(
        "Mean CDS length change (bp)\n"
        "Prodigal re-annotation minus NCBI reference"
    )

    ax.set_xlabel(xlabel)
    ax.set_title(title)

    ax.set_xticks(x)

    ax.set_xticklabels(
        df["Genome"],
        rotation=45,
        ha="right",
    )

    plt.tight_layout()

    plt.savefig(
        outdir / f"{filename}.png",
        dpi=300,
        bbox_inches="tight",
    )

    plt.close()


# =========================================================
# Figures
# =========================================================

plot_stacked_percent(
    bacteria_df,
    (
        "CDS loci comparison: NCBI reference annotations "
        "vs Prodigal-based re-annotations "
        "in bacterial chromosomes"
    ),
    "Figure_1A_bacterial_chromosomes_NCBI_vs_Prodigal_CDS_mapping",
    "Bacterial chromosome",
)

plot_stacked_percent(
    plasmid_df,
    (
        "CDS loci comparison: NCBI reference annotations "
        "vs Prodigal-based re-annotations in plasmids"
    ),
    "Figure_1B_plasmids_NCBI_vs_Prodigal_CDS_mapping",
    "Plasmid sequence",
)

plot_mean_length(
    bacteria_df,
    (
        "Mean CDS length change after Prodigal "
        "re-annotation in bacterial chromosomes"
    ),
    "Figure_2A_bacterial_chromosomes_mean_CDS_length_change",
    "Bacterial chromosome",
)

plot_mean_length(
    plasmid_df,
    (
        "Mean CDS length change after Prodigal "
        "re-annotation in plasmids"
    ),
    "Figure_2B_plasmids_mean_CDS_length_change",
    "Plasmid sequence",
)


# =========================================================
# Legend
# =========================================================

legend_text = """Definitions of column acronyms/
Table 1+2: CDS mapping categories between the Prodigal and the reference NCBI bacterial_&_plasmid CDS sets per genome.

REF_CDS_{a} / Number of CDS in the mapped reference annotation.
REANN_CDS_{b} / Number of CDS predicted by Prodigal.
MATCH_ALL_{c} / Number of CDS where the start codon, stop codon and loci match.
START_LOC_STOP_PRO_{d} / Number of CDS where the start codon and its loci match, but the stop codon in Prodigal does not.
STOP_LOC_START_PRO_{e} / Number of CDS where the stop codon and its loci match, but the start codon in Prodigal does not.
START_STOP_LOC_CHANGE_{f} / Number of CDS where the start codon and stop codons match, but their loci change.
REF_ONLY_{g} / Number of CDS present in the reference but absent in Prodigal.
PRO_ONLY_{h} / Number of CDS present in Prodigal but absent in the reference.
FINAL_CDS_{i} / The total number of re-annotated CDS after integrating mapping categories.

-----------------------------------------------------------------------------------------------------------------------

Table 3: Summary of CDS Boundary Refinements Between Reference and Prodigal Genomes.

ST_{a} / indicates the sequence type.
EM_{b} / indicates exact matches between reference and Prodigal CDS sets.
EM(%)_{c} / indicates the percentage of exact matches between the reference and Prodigal CDS sets.
EXT_{d} / indicates Prodigal CDS extensions relative to the reference CDS sets.
EXT(%)_{e} / indicates the percentage of Prodigal CDS extensions relative to the reference CDS sets.
TRUNC_{f} / indicates Prodigal CDS truncations relative to the reference CDS sets.
TRUNC(%)_{g} / indicates the percentage of Prodigal CDS truncations relative to the reference CDS sets.
LS_{h} / indicates the locus shifts.
Mean_∆CDS(bp)_{i} / indicates mean CDS length difference between Prodigal and reference CDS sets.
"""

legend_file.write_text(
    legend_text,
    encoding="utf-8",
)


print("Done.")
print(f"Summary: {output_table}")
print(f"Legend:  {legend_file}")
print(f"Figures: {outdir}")
