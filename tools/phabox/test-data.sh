#!/bin/bash

wget https://github.com/KennthShang/PhaBOX/releases/download/v2/phabox_db_v2.zip
unzip phabox_db_v2.zip
rm phabox_db_v2.zip
mv phabox_db_v2/ test-data/
