#!/usr/bin/env python3
import argparse
import csv
import gzip
import re
from collections import OrderedDict
from datetime import datetime
from pathlib import Path

from Bio import SeqIO
from Bio.SeqFeature import FeatureLocation, SeqFeature
from Bio.SeqRecord import SeqRecord

EMPTY = {"", "na", "none", "-", "nan"}


def norm_empty(value):
    if value is None:
        return ""
    value = str(value).strip()
    return "" if value.lower() in EMPTY else value


def strip_version(accession):
    return re.sub(r"\.\d+$", "", accession.strip())


def parse_tsv(path):
    with open(path, newline="", encoding="utf-8", errors="replace") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def find_metadata_row(rows, key):
    query = norm_empty(key)
    query_no_version = strip_version(query)
    for row in rows:
        candidates = [
            norm_empty(row.get("Replicon_accession")),
            norm_empty(row.get("Replicon_accession_norm")),
            norm_empty(row.get("Genome_ID")),
            norm_empty(row.get("Inf")),
        ]
        for candidate in candidates:
            if not candidate:
                continue
            if query == candidate or query_no_version == strip_version(candidate):
                return row
    raise ValueError(
        f"Could not match '{key}' to metadata using Replicon_accession, "
        "Replicon_accession_norm, Genome_ID, or Inf."
    )


def sniff_delimiter(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.strip() or line.startswith("##"):
                continue
            return "\t" if "\t" in line else ","
    return "\t"


def load_eggnog(path):
    delimiter = sniff_delimiter(path)
    mapping = {}
    with open(path, newline="", encoding="utf-8", errors="replace") as handle:
        reader = csv.DictReader(handle, delimiter=delimiter)
        fields = [f.strip() for f in (reader.fieldnames or [])]
        query_col = "#query" if "#query" in fields else ("query" if "query" in fields else None)
        if query_col is None:
            raise ValueError(
                "eggNOG input must contain a '#query' or 'query' column. "
                f"Found: {fields}"
            )
        for row in reader:
            query = norm_empty(row.get(query_col)).split()[0]
            if not query:
                continue
            mapping[query] = {
                "COG_category": norm_empty(row.get("COG_category")),
                "Description": norm_empty(row.get("Description")),
                "Preferred_name": norm_empty(row.get("Preferred_name")),
                "GOs": norm_empty(row.get("GOs")) or norm_empty(row.get("GO_Term")),
                "EC": norm_empty(row.get("EC")),
                "KEGG_ko": norm_empty(row.get("KEGG_ko")) or norm_empty(row.get("KEGG_KO")),
                "PFAMs": norm_empty(row.get("PFAMs")),
                "KEGG_Pathway": norm_empty(row.get("KEGG_Pathway")),
                "KEGG_Module": norm_empty(row.get("KEGG_Module")),
            }
    return mapping


def read_fasta(path):
    return OrderedDict((record.id, record) for record in SeqIO.parse(path, "fasta"))


def parse_prodigal_faa(path):
    proteins = {}
    gff_to_protein = {}
    for record in SeqIO.parse(path, "fasta"):
        proteins[record.id] = record.seq
        match = re.search(r"ID=([^; \t]+)", record.description)
        if match:
            gff_to_protein[match.group(1)] = record.id
    return proteins, gff_to_protein


def parse_gff_cds(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 9:
                continue
            seqid, _, feature_type, start, end, _, strand, phase, attrs = fields
            if feature_type.lower() != "cds":
                continue
            attributes = {}
            for item in attrs.split(";"):
                if "=" in item:
                    key, value = item.split("=", 1)
                    attributes[key] = value
            feature_id = (
                attributes.get("ID")
                or attributes.get("locus_tag")
                or attributes.get("protein_id")
                or attributes.get("Name")
                or ""
            )
            yield {
                "seqid": seqid,
                "start": int(start),
                "end": int(end),
                "strand": strand,
                "phase": phase,
                "gff_id": feature_id,
            }


UNKNOWN_RE = re.compile(
    r"\b(unknown function|function unknown|uncharacteri[sz]ed|hypothetical)\b",
    flags=re.I,
)
BAD_PRODUCT_RE = re.compile(
    r"\b(psort|location|subcellular|cellular\s+location|extracellular|"
    r"periplasm(ic)?|membrane\s+location|unknown|function\s+unknown|"
    r"uncharacteri[sz]ed)\b",
    flags=re.I,
)


def load_pfam_duf_map(path):
    if not path:
        return {}

    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        return {}

    opener = gzip.open if p.suffix == ".gz" else open

    with opener(
        p,
        mode="rt",
        newline="",
        encoding="utf-8",
        errors="replace",
    ) as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fields = [f.strip() for f in (reader.fieldnames or [])]
        id_cols = [
            f
            for f in fields
            if f.lower()
            in {
                "pfam",
                "pfam_id",
                "id",
                "name",
                "accession",
                "acc",
                "pfam_acc",
            }
        ]
        desc_cols = [
            f
            for f in fields
            if f.lower() in {"desc", "description", "pfam_desc"}
        ]

        mapping = {}
        for row in reader:
            ident = next(
                (
                    norm_empty(row.get(c))
                    for c in id_cols
                    if norm_empty(row.get(c))
                ),
                "",
            )
            desc = next(
                (
                    norm_empty(row.get(c))
                    for c in desc_cols
                    if norm_empty(row.get(c))
                ),
                "",
            )
            if ident:
                mapping[ident.upper()] = desc

        return mapping


def split_tokens(value):
    value = norm_empty(value)
    return [x for x in re.split(r"[,\s;|]+", value) if x] if value else []


def build_note(annotation):
    parts = []
    values = [
        ("COG", annotation.get("COG_category")),
        ("KO", annotation.get("KEGG_ko")),
        ("GO", annotation.get("GOs")),
        ("EC", annotation.get("EC")),
        ("PFAMs", annotation.get("PFAMs")),
        ("KEGG_Pathway", annotation.get("KEGG_Pathway")),
        ("KEGG_Module", annotation.get("KEGG_Module")),
    ]
    for label, value in values:
        value = norm_empty(value)
        if value:
            parts.append(f"{label}={value}")
    return "; ".join(parts) if parts else None


def only_cog_s(note):
    compact = re.sub(r"\s+", "", note or "")
    return compact.strip(";") == "COG=S"


def duf_only_unknown(pfam_field, mapping):
    tokens = split_tokens(pfam_field)
    if not tokens:
        return False

    def is_duf(token):
        token = token.upper()
        if token.startswith("DUF"):
            return True
        return token.startswith("PF") and "DUF" in mapping.get(token, "").upper()
    if not all(is_duf(token) for token in tokens):
        return False
    for token in tokens:
        desc = mapping.get(token.upper(), "")
        if not desc or UNKNOWN_RE.search(desc):
            return True
    return False


def choose_product(annotation):
    for value in (annotation.get("Preferred_name"), annotation.get("Description")):
        value = norm_empty(value)
        if value and not BAD_PRODUCT_RE.search(value):
            return value if len(value) <= 200 else value[:197] + "..."
    return "putative protein"


def decide_product_and_note(annotation, pfam_map):
    note = build_note(annotation)
    if not note or only_cog_s(note):
        return "hypothetical protein", note
    cog = norm_empty(annotation.get("COG_category")).upper()
    has_non_s_cog = bool(re.sub(r"[^A-Z]", "", cog).replace("S", ""))
    has_other_evidence = any(
        norm_empty(annotation.get(key))
        for key in ("KEGG_ko", "GOs", "EC", "KEGG_Pathway", "KEGG_Module")
    )
    if has_non_s_cog or has_other_evidence:
        return choose_product(annotation), note
    pfam = norm_empty(annotation.get("PFAMs"))
    if pfam:
        if duf_only_unknown(pfam, pfam_map):
            return "hypothetical protein", note
        return choose_product(annotation), note
    return "hypothetical protein", note


def taxonomy_from_metadata(metadata):
    ranks = ["Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species"]
    return [norm_empty(metadata.get(rank)) for rank in ranks if norm_empty(metadata.get(rank))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--metadata", required=True)
    ap.add_argument("--metadata-key", required=True)
    ap.add_argument("--fna", required=True)
    ap.add_argument("--faa", required=True)
    ap.add_argument("--gff", required=True)
    ap.add_argument("--eggnog", required=True)
    ap.add_argument("--pfam-duf-map")
    ap.add_argument("--topology", choices=["circular", "linear"], default="circular")
    ap.add_argument("--locus-prefix")
    ap.add_argument("--taxon", type=int)
    ap.add_argument("--transl-table", type=int, default=11)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    metadata = find_metadata_row(parse_tsv(args.metadata), args.metadata_key)
    genome = read_fasta(args.fna)
    proteins, gff_to_protein = parse_prodigal_faa(args.faa)
    eggnog = load_eggnog(args.eggnog)
    pfam_map = load_pfam_duf_map(args.pfam_duf_map)

    organism = (
        norm_empty(metadata.get("Species"))
        or norm_empty(metadata.get("Host"))
        or norm_empty(metadata.get("Genus"))
        or "Unknown organism"
    )
    strain = norm_empty(metadata.get("Strain"))
    accession = (
        norm_empty(metadata.get("Replicon_accession_norm"))
        or norm_empty(metadata.get("Replicon_accession"))
        or args.metadata_key
    )
    record_id = strip_version(accession)

    records = OrderedDict()
    taxonomy = taxonomy_from_metadata(metadata)
    date = datetime.now().strftime("%d-%b-%Y").upper()

    for contig_id, contig in genome.items():
        rid = record_id if len(genome) == 1 else contig_id
        record = SeqRecord(
            contig.seq,
            id=rid,
            name=rid,
            description=strain or f"{organism} sequence",
        )
        record.annotations["molecule_type"] = "DNA"
        record.annotations["topology"] = args.topology
        record.annotations["date"] = date
        if taxonomy:
            record.annotations["taxonomy"] = taxonomy
        record.annotations["comment"] = (
            "RECAP-PROK re-annotation using Prodigal CDS predictions and "
            "eggNOG-mapper functional annotations."
        )
        source_qualifiers = {"organism": [organism], "mol_type": ["genomic DNA"]}
        if strain:
            source_qualifiers["strain"] = [strain]
        if args.taxon:
            source_qualifiers["db_xref"] = [f"taxon:{args.taxon}"]
        record.features.append(
            SeqFeature(
                FeatureLocation(0, len(record.seq), strand=1),
                type="source",
                qualifiers=source_qualifiers,
            )
        )
        records[contig_id] = record

    cds_count = 0
    for feature in parse_gff_cds(args.gff):
        seqid = feature["seqid"]
        if seqid not in records:
            seqid = seqid.split()[0]
        if seqid not in records:
            continue
        gff_id = feature["gff_id"]
        protein_id = gff_to_protein.get(gff_id)
        aa = proteins.get(protein_id)
        annotation = eggnog.get(protein_id, {}) if protein_id else {}
        product, note = decide_product_and_note(annotation, pfam_map)
        locus_tag = (
            f"{args.locus_prefix}_{cds_count + 1:05d}"
            if args.locus_prefix else (gff_id or f"cds_{cds_count + 1}")
        )
        qualifiers = {
            "locus_tag": [locus_tag],
            "product": [product],
            "protein_id": [locus_tag],
            "transl_table": [str(args.transl_table)],
        }
        if note:
            qualifiers["note"] = [note]
        if aa is not None and len(aa) > 0:
            qualifiers["translation"] = [str(aa)]
        records[seqid].features.append(
            SeqFeature(
                FeatureLocation(
                    feature["start"] - 1,
                    feature["end"],
                    strand=-1 if feature["strand"] == "-" else 1,
                ),
                type="CDS",
                qualifiers=qualifiers,
            )
        )
        cds_count += 1

    if cds_count == 0:
        raise SystemExit(
            "No CDS features were written. Check Prodigal GFF IDs, FAA headers, and eggNOG query IDs."
        )

    with open(args.out, "w", encoding="utf-8") as handle:
        SeqIO.write(list(records.values()), handle, "genbank")


if __name__ == "__main__":
    main()
