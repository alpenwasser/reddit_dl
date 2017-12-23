#!/usr/bin/env bash

if [ -z "$1" ];then
    i=0
    for dir in *Porn oldmaps;do
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
elif [[ "$1" == "--clean" || "$1" == "-c" ]];then
    for dir in *Porn oldmaps;do
        tput bold
        printf '>>> Cleaning %s\n' "$dir"
        tput sgr0
        cd "$dir"
        bash 'clean.sh'
        cd ../
    done
fi
