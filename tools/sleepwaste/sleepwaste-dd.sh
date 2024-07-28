#!/bin/bash

sleep $1
mem=`echo "1024*1024*$2"|bc`


VAR=$(dd if=/dev/urandom bs=1M count=$2 2>/dev/null)

# the following gives more precise estimate of the used memory, 
# but the memory error comes from fold -- not bash
#VAR=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $mem | head -n 1)
echo slept for $1 s and allocated $2 MB in an variable 

exit 0
