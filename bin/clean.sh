#!/usr/bin/env bash

BLACKLIST='blacklist.txt'

readarray -t idList < "$BLACKLIST"

for id in "${idList[@]}";do
    find . -type d -iname "${id}*"  -print0 | xargs -0 rm -rfv
done
