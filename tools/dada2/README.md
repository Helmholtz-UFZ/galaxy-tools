Wrappers for the core functionality of the dada2 package https://benjjneb.github.io/dada2/index.html. 

- filterAndTrim
- derep
- learnErrors
- dada
- mergePairs
- makeSequenceTable
- removeBimeraDenovo

Datatypes
=========

The dada2 Galaxy wrappers use a few extra data types to ensure that only inputs of the correct type can be used. 

For the outputs of derep, dada, learnErrors, and mergePairs the following datatypes are used that derive from  Rdata (which contains the named list that is returned from the corresponding dada function):

- dada2_derep (Rdata: named list see docs for derep-class)
- dada2_dada (Rdata: named list, see docs for dada-class)
- dada2_errorrates (Rdata: named list, see docs for learnErrors)
- dada2_mergepairs (Rdata: named list, see docs for mergePairs)

For the outputs of makeSequenceTable and removeBimeraDenovo the following data types are used which derive from tabular:

- dada2_uniques
-- in R a named integer vector (names are the unique sequences)
-- in Galaxy written as a table (each row corresponding to a unique sequence, column 1: the sequence, column 2: the count)
- dada2_sequencetable
-- in R a named integer matrix (rows = samples, columns = unique sequences)
-- in Galaxy written as a table (rows = unique sequences, columns = samples)

Note the difference between the R and Galaxy representations! The main motivation is that the dada2_sequencetable is analogous to OTU tables as produced for instance by qiime (and it seemed natural to extend this to the uniques which are essentially a sequencetables of single samples).


TODOs 
=====

- implememt getUniques tool to view intermediate results?
- implement tests for cached reference data
