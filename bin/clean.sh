#!/usr/bin/env bash

BLACKLIST='blacklist.txt'
BLACKLIST_GLOBAL='../blacklist.txt'

if [ -f "$BLACKLIST" ];then
    readarray -t idList < "$BLACKLIST"

    for id in "${idList[@]}";do
        find . -type d -iname "${id}*"  -print0 | xargs -0 rm -rfv
    done
fi

if [ -f "$BLACKLIST_GLOBAL" ];then
    readarray -t idListGlobal < "$BLACKLIST_GLOBAL"

    for id in "${idListGlobal[@]}";do
        if [ -z "$id" ];then
            continue
        fi
        find . -type d -iname "${id}*"  -print0 | xargs -0 rm -rfv
    done
fi
