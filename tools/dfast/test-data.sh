#!/bin/bash

set -e

wget https://dfast.annotation.jp/dfast_core_db.tar.gz
tar -xvf dfast_core_db.tar.gz
mv db/ tools/dfast/test-data/
rm dfast_core_db.tar.gz
