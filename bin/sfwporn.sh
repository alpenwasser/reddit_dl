#!/usr/bin/env bash

i=0
for dir in *porn;do
    cd "$dir"
    if [[ "$i" -eq 0 ]];then
        tput bold
        printf '>>> Synchronizing r/%s\n' "$dir"
        i=$((i+1))
        tput sgr0
    else
        tput bold
        printf '\n>>> Synchronizing r/%s\n' "$dir"
        tput sgr0
    fi
    bash 'sync.sh'
    cd ../
done
