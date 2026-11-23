#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Usage:
#   $0 NCBI_reference_mapped.gff BASIHUMIx.prodigal.gff OUTDIR
# -------------------------------------------------------------------
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 NCBI_reference_mapped.gff BASIHUMIx.prodigal.gff OUTDIR" >&2
  exit 1
fi

REF_GFF="$1"        # mapped reference annotation (used for counts + overlaps)
REANN_GFF="$2"      # prodigal re-annotation
OUTDIR="$3"
mkdir -p "$OUTDIR"/{tmp,gff,FINAL_Re-annotated_CDS}
FINAL_DIR="$OUTDIR/FINAL_Re-annotated_CDS"

RO_TH="${RO_TH:-0.80}"   # reciprocal overlap threshold (0.80 default)
echo "[INFO] Reciprocal overlap threshold: $RO_TH" >&2

# -----------------------------
# 1) Extract CDS -> BED6
# BED: chrom  start0  end  id  score  strand
# -----------------------------
gff_to_bed () {
  local gff="$1"
  local out="$2"

  awk -F'\t' -v OFS='\t' '
    $0 ~ /^#/ {next}
    NF>=9 && $3=="CDS"{
      chr=$1; s=$4; e=$5; strand=$7; attr=$9;

      # normalize coords
      if (s>e){t=s;s=e;e=t}

      # extract ID=... (Prodigal has ID=1_1; Liftoff has ID=cds-WP_...)
      id=""
      if (match(attr, /(^|;)ID=[^;]+/)) {
        id=substr(attr, RSTART, RLENGTH)
        sub(/(^|;)ID=/, "", id)
      } else if (match(attr, /locus_tag=[^;]+/)) {
        id=substr(attr, RSTART, RLENGTH); sub(/locus_tag=/,"",id)
      } else if (match(attr, /protein_id=[^;]+/)) {
        id=substr(attr, RSTART, RLENGTH); sub(/protein_id=/,"",id)
      } else {
        next
      }

      # BED is 0-based start
      print chr, s-1, e, id, 0, strand
    }
  ' "$gff" > "$out"
}

REF_BED="$OUTDIR/tmp/ref_cds.bed"
REA_BED="$OUTDIR/tmp/reann_cds.bed"
gff_to_bed "$REF_GFF"   "$REF_BED"
gff_to_bed "$REANN_GFF" "$REA_BED"

# REF CDS count (a) now comes from mapped reference GFF
REF_TOTAL=$(awk -F'\t' '$0 !~ /^#/ && NF>=9 && $3=="CDS"{c++} END{print c+0}' "$REF_GFF")

# Re-annotation CDS count (b)
REA_TOTAL=$(wc -l < "$REA_BED" | tr -d ' ')

# For logging only
REF_MAPPED_TOTAL=$(wc -l < "$REF_BED" | tr -d ' ')

echo "[INFO] REF CDSs (mapped reference): $REF_TOTAL" >&2
echo "[INFO] REF CDSs (BED extracted):    $REF_MAPPED_TOTAL" >&2
echo "[INFO] REANN CDSs:                  $REA_TOTAL" >&2

# -----------------------------
# 2) All strand-consistent overlaps
# bedtools intersect output:
# A(ref) fields (6) + B(reann) fields (6) + overlap_len
# -----------------------------
OVL_RAW="$OUTDIR/tmp/overlaps_raw.tsv"
command -v bedtools >/dev/null 2>&1 || {
  echo "[ERROR] bedtools is not installed or not available in PATH" >&2
  exit 127
}

bedtools intersect -s -wo \
  -a "$REF_BED" \
  -b "$REA_BED" \
  > "$OVL_RAW"

if [[ ! -s "$OVL_RAW" ]]; then
  echo "[ERROR] No overlaps found by bedtools intersect. Check strand/contigs." >&2
  exit 2
fi

# -----------------------------
# 3) Filter by reciprocal overlap and score pairs
# Keep: ref_id re_id ref_chr ref_s ref_e ref_str re_s re_e re_str ovl ref_len re_len roA roB score
# score = min(roA, roB) then tie-break by ovl
# -----------------------------
OVL_FILT="$OUTDIR/tmp/overlaps_filt.tsv"

awk -v OFS='\t' -v th="$RO_TH" '
{
  # ref
  rchr=$1; rs0=$2; re=$3; rid=$4; rstr=$6;
  # reann
  qchr=$7; qs0=$8; qe=$9; qid=$10; qstr=$12;
  ovl=$13;

  rlen = re - rs0;
  qlen = qe - qs0;

  if (rlen<=0 || qlen<=0) next;

  roA = ovl / rlen;
  roB = ovl / qlen;

  if (roA+0 >= th && roB+0 >= th) {
    score = (roA<roB?roA:roB);
    print rid, qid, rchr, rs0, re, rstr, qs0, qe, qstr, ovl, rlen, qlen, roA, roB, score
  }
}
' "$OVL_RAW" > "$OVL_FILT"

if [[ ! -s "$OVL_FILT" ]]; then
  echo "[ERROR] No pairs passed reciprocal overlap >= $RO_TH. Try lower RO_TH=0.50" >&2
  exit 3
fi

# -----------------------------
# 4) One-to-one greedy matching by score then overlap
# Sort by: score desc, ovl desc
# then pick if both ids unused
# -----------------------------
PAIRS="$OUTDIR/pairs_one2one.tsv"

sort -t $'\t' -k15,15gr -k10,10nr "$OVL_FILT" \
| awk -v OFS='\t' '
  !usedR[$1] && !usedQ[$2] {
    usedR[$1]=1; usedQ[$2]=1;
    print
  }
' > "$PAIRS"

PAIR_N=$(wc -l < "$PAIRS" | tr -d ' ')
echo "[INFO] One-to-one pairs: $PAIR_N" >&2

# -----------------------------
# 5) Classify pairs (strand-aware start/stop)
# Use CODON sense:
#   if + : start_codon = start, stop_codon = end
#   if - : start_codon = end,   stop_codon = start
# Note: our BED starts are 0-based; convert to 1-based for codon coords.
# -----------------------------
CLASS_TSV="$OUTDIR/pairs_classified.tsv"

awk -v OFS='\t' '
BEGIN{
  print "ref_id","reann_id","class","ref_chr","ref_start","ref_end","ref_strand","reann_start","reann_end","reann_strand","ovl","roA","roB"
}
NR>0{
  rid=$1; qid=$2;
  chr=$3; rs0=$4; re=$5; str=$6;
  qs0=$7; qe=$8; qstr=$9;
  ovl=$10; roA=$13; roB=$14;

  # convert to 1-based inclusive coords for codon logic
  rs=rs0+1; qs=qs0+1;

  # strand consistency already enforced by bedtools -s
  # codon start/stop
  if (str=="+") { r_start=rs; r_stop=re; q_start=qs; q_stop=qe; }
  else          { r_start=re; r_stop=rs; q_start=qe; q_stop=qs; }

  same_start = (r_start==q_start);
  same_stop  = (r_stop==q_stop);

  cls="START_STOP_LOC_CHANGE";
if (same_start && same_stop) cls="MATCH_ALL";
else if (same_start && !same_stop) cls="START_LOC_STOP_PRO";
else if (!same_start && same_stop) cls="STOP_LOC_START_PRO";
else cls="START_STOP_LOC_CHANGE";

  print rid,qid,cls,chr,rs,re,str,qs,qe,qstr,ovl,roA,roB
}
' "$PAIRS" > "$CLASS_TSV"

# Counts
MATCH_N=$(awk -F'\t' '$3=="MATCH_ALL"{c++} END{print c+0}' "$CLASS_TSV")
START_LOC_STOP_PRO_N=$(awk -F'\t' '$3=="START_LOC_STOP_PRO"{c++} END{print c+0}' "$CLASS_TSV")
STOP_LOC_START_PRO_N=$(awk -F'\t' '$3=="STOP_LOC_START_PRO"{c++} END{print c+0}' "$CLASS_TSV")
START_STOP_LOC_CHANGE_N=$(awk -F'\t' '$3=="START_STOP_LOC_CHANGE"{c++} END{print c+0}' "$CLASS_TSV")

# -----------------------------
# 6) Unmapped (true no paired gene after greedy)
# Any residual not represented in classes or basic unmapped
# is added directly to unmapped counts.
# -----------------------------
cut -f1 "$CLASS_TSV" | tail -n +2 | sort -u > "$OUTDIR/tmp/ref_paired_ids.txt"
cut -f2 "$CLASS_TSV" | tail -n +2 | sort -u > "$OUTDIR/tmp/reann_paired_ids.txt"

cut -f4 "$REF_BED" | sort -u > "$OUTDIR/tmp/ref_all_ids.txt"
cut -f4 "$REA_BED" | sort -u > "$OUTDIR/tmp/reann_all_ids.txt"

comm -23 "$OUTDIR/tmp/ref_all_ids.txt" "$OUTDIR/tmp/ref_paired_ids.txt" > "$OUTDIR/tmp/ref_unmapped_ids.txt"
comm -23 "$OUTDIR/tmp/reann_all_ids.txt" "$OUTDIR/tmp/reann_paired_ids.txt" > "$OUTDIR/tmp/reann_unmapped_ids.txt"

# Base unmapped counts from ID comparison
REF_UNMAPPED_BASE=$(wc -l < "$OUTDIR/tmp/ref_unmapped_ids.txt" | tr -d ' ')
REA_UNMAPPED_BASE=$(wc -l < "$OUTDIR/tmp/reann_unmapped_ids.txt" | tr -d ' ')

# Residual counts not represented in classes or base unmapped
REF_RESIDUAL=$(( REF_TOTAL - (MATCH_N + START_LOC_STOP_PRO_N + STOP_LOC_START_PRO_N + START_STOP_LOC_CHANGE_N + REF_UNMAPPED_BASE) ))
REA_RESIDUAL=$(( REA_TOTAL - (MATCH_N + START_LOC_STOP_PRO_N + STOP_LOC_START_PRO_N + START_STOP_LOC_CHANGE_N + REA_UNMAPPED_BASE) ))

if (( REF_RESIDUAL < 0 )); then
  echo "[ERROR] Negative reference residual detected: $REF_RESIDUAL" >&2
  exit 10
fi

if (( REA_RESIDUAL < 0 )); then
  echo "[ERROR] Negative re-annotation residual detected: $REA_RESIDUAL" >&2
  exit 11
fi

# Final unmapped counts = base unmapped + residual lost counts
REF_UNMAPPED_N=$((REF_UNMAPPED_BASE + REF_RESIDUAL))
REA_UNMAPPED_N=$((REA_UNMAPPED_BASE + REA_RESIDUAL))

if (( REF_RESIDUAL > 0 )); then
  echo "[WARN] Added $REF_RESIDUAL residual reference CDS(s) to REF_ONLY count." >&2
fi

if (( REA_RESIDUAL > 0 )); then
  echo "[WARN] Added $REA_RESIDUAL residual re-annotation CDS(s) to REANN_ONLY count." >&2
fi

# -----------------------------
# 7) Wide table (single row)
# -----------------------------
TABLE="$OUTDIR/module3_table3_wide.tsv"
GENOME="${GENOME:-$(basename "$OUTDIR")}"

FINAL_CDS_N=$(( MATCH_N + START_LOC_STOP_PRO_N + STOP_LOC_START_PRO_N + START_STOP_LOC_CHANGE_N + REF_UNMAPPED_N + REA_UNMAPPED_N ))

{
  echo -e "Genome\tREF_CDS_{a}\tPRO_CDS_{b}\tMATCH_ALL_{c}\tSTART_LOC_STOP_PRO_{d}\tSTOP_LOC_START_PRO_{e}\tSTART_STOP_LOC_CHANGE_{f}\tREF_ONLY_{g}\tPRO_ONLY_{h}\tFINAL_CDS_{i}"
  echo -e "${GENOME}\t${REF_TOTAL}\t${REA_TOTAL}\t${MATCH_N}\t${START_LOC_STOP_PRO_N}\t${STOP_LOC_START_PRO_N}\t${START_STOP_LOC_CHANGE_N}\t${REF_UNMAPPED_N}\t${REA_UNMAPPED_N}\t${FINAL_CDS_N}"
} > "$TABLE"

# -----------------------------
# 8) Write GFF per class (evidence)
# We pull CDS lines by ID=... from original GFFs
# -----------------------------
extract_gff_by_ids () {
  local gff="$1"
  local ids="$2"
  local out="$3"

  if [[ ! -s "$ids" ]]; then
    : > "$out"
    return
  fi

  # Build an awk set of ids, then match ID=... in attributes.
  awk -F'\t' -v idsfile="$ids" '
    BEGIN{
      while((getline line < idsfile)>0){gsub(/\r/,"",line); if(line!="") ids[line]=1}
      close(idsfile)
    }
    $0 ~ /^#/ {next}
    NF>=9 && $3=="CDS"{
      attr=$9
      # quick parse ID
      id=""
      if (match(attr, /(^|;)ID=[^;]+/)) {
        id=substr(attr, RSTART, RLENGTH); sub(/(^|;)ID=/,"",id)
      }
      if (id!="" && ids[id]) print $0
    }
  ' "$gff" > "$out"
}

# IDs per class (REF IDs are column 1, REANN IDs are column 2, CLASS is column 3)
tail -n +2 "$CLASS_TSV" | awk -F'\t' -v OFS='\t' '
$3=="MATCH_ALL"              {print $1 > ref_exact;      print $2 > re_exact}
$3=="START_LOC_STOP_PRO"   {print $1 > ref_startchg;   print $2 > re_startchg}
$3=="STOP_LOC_START_PRO"   {print $1 > ref_stopchg;    print $2 > re_stopchg}
$3=="START_STOP_LOC_CHANGE"  {print $1 > ref_loci;       print $2 > re_loci}
' \
ref_exact="$OUTDIR/tmp/ref_exact_ids.txt" \
re_exact="$OUTDIR/tmp/reann_exact_ids.txt" \
ref_startchg="$OUTDIR/tmp/ref_start_change_ids.txt" \
re_startchg="$OUTDIR/tmp/reann_start_change_ids.txt" \
ref_stopchg="$OUTDIR/tmp/ref_stop_change_ids.txt" \
re_stopchg="$OUTDIR/tmp/reann_stop_change_ids.txt" \
ref_loci="$OUTDIR/tmp/ref_loci_ids.txt" \
re_loci="$OUTDIR/tmp/reann_loci_ids.txt"

# Evidence GFFs
extract_gff_by_ids "$REF_GFF"   "$OUTDIR/tmp/ref_exact_ids.txt"          "$OUTDIR/gff/ref_matches_exact.gff"
extract_gff_by_ids "$REF_GFF"   "$OUTDIR/tmp/ref_start_change_ids.txt"   "$OUTDIR/gff/ref_start_change.gff"
extract_gff_by_ids "$REF_GFF"   "$OUTDIR/tmp/ref_stop_change_ids.txt"    "$OUTDIR/gff/ref_stop_change.gff"
extract_gff_by_ids "$REF_GFF"   "$OUTDIR/tmp/ref_loci_ids.txt"           "$OUTDIR/gff/ref_loci_change.gff"
extract_gff_by_ids "$REF_GFF"   "$OUTDIR/tmp/ref_unmapped_ids.txt"       "$OUTDIR/gff/ref_unmapped.gff"

extract_gff_by_ids "$REANN_GFF" "$OUTDIR/tmp/reann_exact_ids.txt"        "$OUTDIR/gff/reann_matches_exact.gff"
extract_gff_by_ids "$REANN_GFF" "$OUTDIR/tmp/reann_start_change_ids.txt" "$OUTDIR/gff/reann_start_change.gff"
extract_gff_by_ids "$REANN_GFF" "$OUTDIR/tmp/reann_stop_change_ids.txt"  "$OUTDIR/gff/reann_stop_change.gff"
extract_gff_by_ids "$REANN_GFF" "$OUTDIR/tmp/reann_loci_ids.txt"         "$OUTDIR/gff/reann_loci_change.gff"
extract_gff_by_ids "$REANN_GFF" "$OUTDIR/tmp/reann_unmapped_ids.txt"     "$OUTDIR/gff/reann_unmapped.gff"

# Ensure uniqueness
for f in "$OUTDIR/tmp/"*.txt; do
  [[ -s "$f" ]] && sort -u "$f" -o "$f"
done
# -----------------------------
# 9) Build FINAL CDS evidence set
# FINAL_CDS = MATCH_ALL + START_LOC_STOP_PRO + STOP_LOC_START_PRO
#           + START_STOP_LOC_CHANGE + REF_ONLY + PRO_ONLY
#
# NOTE:
# REF_ONLY records come from mapped reference GFF.
# PRO_ONLY records come from Prodigal GFF.
# Therefore this is a final union CDS evidence set, not Prodigal-only CDSs.
# -----------------------------

FINAL_IDS="$FINAL_DIR/${GENOME}_FINAL_CDS_ids.tsv"
FINAL_GFF="$FINAL_DIR/${GENOME}_FINAL_CDS.gff"

{
  echo -e "class\tsource\tcds_id"

  # paired CDSs
  tail -n +2 "$CLASS_TSV" | awk -F'\t' -v OFS='\t' '
    {
      print $3, "REF", $1
      print $3, "PRO", $2
    }
  '

  # REF_ONLY
  awk -v OFS='\t' '{print "REF_ONLY", "REF", $1}' "$OUTDIR/tmp/ref_unmapped_ids.txt"

  # PRO_ONLY
  awk -v OFS='\t' '{print "PRO_ONLY", "PRO", $1}' "$OUTDIR/tmp/reann_unmapped_ids.txt"

} > "$FINAL_IDS"

# Merge GFF evidence
{
  echo "##gff-version 3"
  cat "$OUTDIR/gff/ref_matches_exact.gff"
  cat "$OUTDIR/gff/ref_start_change.gff"
  cat "$OUTDIR/gff/ref_stop_change.gff"
  cat "$OUTDIR/gff/ref_loci_change.gff"
  cat "$OUTDIR/gff/ref_unmapped.gff"

  cat "$OUTDIR/gff/reann_matches_exact.gff"
  cat "$OUTDIR/gff/reann_start_change.gff"
  cat "$OUTDIR/gff/reann_stop_change.gff"
  cat "$OUTDIR/gff/reann_loci_change.gff"
  cat "$OUTDIR/gff/reann_unmapped.gff"
} > "$FINAL_GFF"

test -s "$FINAL_IDS"
test -s "$FINAL_GFF"

echo "Final CDS IDs: $FINAL_IDS"
echo "Final CDS GFF: $FINAL_GFF"
echo "✅ Done"
echo "Wide table: $TABLE"
echo "Pairs:      $CLASS_TSV"
echo "GFFs:       $OUTDIR/gff/"
