# dDocent test data

## Raw reads (`*.F.fq.gz` / `*.R.fq.gz`)

`PopA_01`-`PopA_04` and `PopB_01`-`PopB_04` are two synthetic populations of
simulated double-digest RAD (ddRAD) reads, derived from the SimRAD simulator that
ships with the dDocent tutorials (<https://github.com/jpuritz/dDocent>,
`tutorials/data.zip`).

Derivation:

1. The 40 tutorial samples were demultiplexed with Stacks `process_radtags`
   (`-e ecoRI --renz_2 mspI -r -i gzfastq`); the run retained 100% of the
   1,525,844 demultiplexed reads.
2. Eight samples (`SimRAD_A01`-`A04` and `SimRAD_B01`-`B04`) were relabelled to
   `PopA_01`-`PopA_04` and `PopB_01`-`PopB_04`, following the
   `Locality_Individual` convention that dDocent requires.
3. The first 1,500 read pairs of every sample were kept, giving the
   `*.F.fq.gz` / `*.R.fq.gz` pairs in this directory (512 KB in total).

The data set is large enough to exercise the whole pipeline (assembly, clustering,
mapping, variant calling, and the 90% completeness filter) and small enough to run
in a few seconds. With `K1 = 5`, `K2 = 6`, CD-HIT similarity 0.9 and paired-end
assembly, it produces a 29-contig `reference.fasta` (`reference.fasta` in this
directory) and 100 variants in `Final.recode.vcf`.

Simulated data are appropriate here: the tests only verify that dDocent's stages
run and hand data from one tool to the next, not that a particular biological
result is recovered.

## Pipeline intermediates

`reference.fasta`, `Final.recode.vcf` and `*.forward.fq.gz` / `*.reverse.fq.gz`
are the outputs of the `ddocent` tool on the eight samples above (dDocent 2.9.8,
freebayes 1.3.6, vcflib 1.0.3, fastp 0.26.0). They are the inputs of the
post-processing tools, so those tools can be tested without running the pipeline
first:

* `reference.fasta` - expected assembly of `dDocent Remake Reference`
* `Final.recode.vcf` - input of `dDocent Filters` and `dDocent Error Count`;
  `dDocent Filters` with `overlapping = no`, `mixed libraries = no` and the
  automatic depth cutoff keeps 80 of the 100 sites (cutoff 26)
* `*.forward.fq.gz` / `*.reverse.fq.gz` - trimmed reads of the pipeline runs
* `*.forward.fq` / `*.reverse.fq` - the same reads uncompressed, input of
  `dDocent Remake Reference`

Reassembling the trimmed reads with the pipeline parameters reproduces
`reference.fasta` byte for byte. `dDocent Remake Reference` is tested on the
uncompressed files, so that its run also covers the `fastqsanger` input path,
and the collection elements carry a dot and a dash in their identifiers, so that
its run also covers the identifier sanitization of the wrapper.
