# RECAP-PROK Module 4 — Galaxy-native layout

Module 4 is implemented as a set of small Galaxy tools rather than a monolithic
orchestration script. Galaxy workflows connect these tools with existing Galaxy
tools for external analyses. There is no Snakemake workflow and no
`run_module4.sh`.

## External Galaxy tools

Existing Galaxy tools are used for:

- eggNOG-mapper
- DIAMOND against NCBI NR
- antiSMASH

These external applications are not dependencies of the RECAP-PROK wrappers.
RECAP-PROK wraps only project-specific reconstruction, comparison, and
interpretation logic.

## RECAP-PROK Module 4 tools

1. `recap_prok_module4_functional_comparison.xml`
   - inputs:
     - Re-annotated eggNOG-mapper annotations
     - Reference-mapped eggNOG-mapper annotations
     - corresponding Re-annotated and Reference-mapped FAA files
     - Gene Ontology reference selected from the Galaxy `gene_ontology`
       tool data table
   - output:
     - functional comparison TSV

2. `recap_prok_module4_genbank.xml`
   - inputs:
     - Re-annotated eggNOG-mapper annotations
     - metadata TSV
     - Prodigal FNA, FAA, and GFF
     - reconstruction parameters
   - output:
     - Re-annotated GenBank
   - packaged RECAP-PROK resource:
     - `resources/pfam_duf_map.tsv.gz`

3. `recap_prok_module4_hypothetical_comparison.xml`
   - inputs:
     - Re-annotated GenBank
     - Reference-mapped GenBank
   - outputs:
     - hypothetical-protein comparison TSV
     - comparison PDF
     - Re-annotated hypothetical-protein FAA
     - Reference-mapped hypothetical-protein FAA

4. The two hypothetical-protein FAA datasets can be passed to the existing
   Galaxy DIAMOND tool configured against NCBI NR.

5. `recap_prok_module4_nr_analysis.xml`
   - inputs:
     - Re-annotated DIAMOND/NR tabular result
     - Reference-mapped DIAMOND/NR tabular result
   - outputs:
     - Re-annotated best-hit TSV
     - Reference-mapped best-hit TSV
     - classification summary TSV
     - classification PDF

6. In parallel, the Re-annotated GenBank can be passed to the existing Galaxy
   antiSMASH tool.

7. `recap_prok_module4_antismash_analysis.xml`
   - input:
     - antiSMASH `regions.js`
   - outputs:
     - BGC summary TSV
     - BGC comparison PDF

## Gene Ontology reference data

Functional Annotation Comparison obtains the Gene Ontology reference through
the Galaxy `gene_ontology` tool data table.

The production reference is the complete official `go-basic.obo` ontology
installed through the Gene Ontology Galaxy Data Manager. The full ontology is
therefore not bundled with the RECAP-PROK tools.

`test-data/go-basic-test.obo` is a small deterministic fixture used only by the
Planemo test configuration. It is not the production Gene Ontology reference
and does not restrict the tool to the test genomes.

## DIAMOND/NCBI NR table contract

Use BLAST tabular output without a header and with exactly these fields:

`qseqid, sseqid, pident, qlen, slen, length, evalue, bitscore, stitle`

## Generic design

The wrappers do not contain separate bacterial or plasmid branches and do not
depend on filename prefixes such as `PLRe-annotated_*`. The same tools can be
applied to compatible bacterial, plasmid, or archaeal replicons.

CDS-only analysis from the previous Module 4 implementation is not included in
this Galaxy-native Module 4 workflow.

## Resources

`resources/pfam_duf_map.tsv.gz` is the RECAP-PROK resource used by GenBank
Reconstruction.

`kegg_pathway_titles.tsv` is not required by the current Module 4 wrappers and
is therefore not packaged.

## Validation

The five RECAP-PROK Module 4 wrappers contain Planemo tests. They can be
validated with:

```bash
planemo format tools/recap-prok/recap_prok_module4_*.xml
planemo lint tools/recap-prok/recap_prok_module4_*.xml
planemo test tools/recap-prok/recap_prok_module4_*.xml
```

The shared `tools/recap-prok/.shed.yml` remains the Tool Shed suite definition
for RECAP-PROK. Module 4 does not use a separate `.shed.yml`.
