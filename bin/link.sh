#!/usr/bin/env bash

poolDir='pool'
mkdir -p "$poolDir"

print_status()
{
    msg="$1"
    clr="$2"
    printf '[ '
    tput setaf "$clr"
    printf '%s' "$msg"
    tput sgr0
    printf ' ]'
}

# Read file path, basename and directory into array
readarray -td: fileList <<< "$(find . -type f '(' -iname '*jpg' -o -iname '*jpeg' -o -iname '*png' ')' -printf '%p,%f,%h:')"
#declare -p fileList

# Remove last element of array, which is just a newline entry
unset 'fileList[-1]'

for file in "${fileList[@]}";do

    # split attributes for each file into new array
    readarray -td, fileAttrs <<< "${file},"
    unset 'fileAttrs[-1]'

    #declare -p fileAttrs
    sourcePath="../${fileAttrs[0]}"
    linkPath="${poolDir}/${fileAttrs[2]#*___}___${fileAttrs[1]}"

    # Don't create existing links again.
    [ -L "$linkPath" ] && continue

    ln -s "$sourcePath" "$linkPath"
    if [[ "$?" -eq 0 ]];then
        print_status 'OK' 2
        printf "\t\t%s\n" "${fileAttrs[2]#*___}"
    else
        print_status 'FAIL' 1
        printf "\t%s\n" "$sourcePath"
        exit 1
    fi
done
