#!/bin/bash

set -e

mkdir -p test-data/ref
cd test-data/ref
wget http://ftp.ebi.ac.uk/pub/databases/metagenomics/eukcc/eukcc2_db_ver_1.2.tar.gz
tar -xvf eukcc2_db_ver_1.2.tar.gz
rm eukcc2_db_ver_1.2.tar.gz
