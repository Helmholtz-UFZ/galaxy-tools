#!/bin/bash

set -ex

wget https://dfast.annotation.jp/dfast_core_db.tar.gz
tar -xvf dfast_core_db.tar.gz
mv db/ test-data/
rm dfast_core_db.tar.gz
tree .