#!/bin/bash

time=$1
mem=$2

declare -a field
for i in `seq 1 $mem`
do
	field=(${field[@]} `yes | head -n 1048576 | tr \\n ' '`)
done
sleep $time

echo slept for $1 s and allocated $2 MB in an array with ${#field[@]} items
exit 0
