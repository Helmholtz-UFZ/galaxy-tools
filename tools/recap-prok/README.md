# RECAP-PROK Module 3 — Galaxy wrapper revision

This revision follows the Galaxy review by reducing the wrapper to the Module 3 CDS-comparison step.

## Scientific logic

The scientific logic in `module3_table3_columns.sh` is unchanged. It still uses the original reciprocal-overlap threshold (default `0.80`), strand-consistent overlaps, greedy one-to-one matching, and the same CDS classes and final CDS evidence construction.

## Galaxy design

Liftoff should be executed as a separate Galaxy tool/workflow step. Its mapped GFF is passed to this tool together with the Prodigal re-annotation GFF. The same tool can be used for bacterial chromosomes or plasmids; no duplicated bacterial/plasmid command block is required.

## Files used by the Galaxy tool

- `recap_prok_module3.xml`
- `module3_table3_columns.sh`
- `test-data/` for automated Galaxy/Planemo tests

The older Snakemake files can remain in the standalone RECAP-PROK repository, but they are not required by this Galaxy wrapper.
