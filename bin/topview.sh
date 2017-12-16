#!/usr/bin/env bash

# ---------------------------------------------------------------------------------------------------- #
#
#                                                                                     GLOBAL VARIABLES
#
# ---------------------------------------------------------------------------------------------------- #
declare -a TIMESTAMPED_IMAGES
FILE_LIST='fehlist.txt'
LIMIT=0
TIME=0
SLIDESHOW=false
FULLSCREEN=false
MMIN=0
MTIME=0
MINS_PER_DAY=1440

# ---------------------------------------------------------------------------------------------------- #
#
#                                                                                            FUNCTIONS
#
# ---------------------------------------------------------------------------------------------------- #
print_help()
{
    tput bold
    echo ">>> Usage"
    tput sgr0
    echo "$0 [-l limit] [-t minutes] [-d days] [-f] [-s]"
    tput bold
    echo -e "\n>>> Argument List:"
    tput sgr0
    echo "-l: Positive integer. Limit number of images to cycle through."
    echo "-t: Integer. File was last modified t minutes ago."
    echo "-d: Integer. File was last modified d days ago."
    echo "-s: Switch. Slide show mode. Takes precedence over -f."
    echo "-f: Switch. Full screen mode."
}
parse_input()
{
    local OPTIND

    while getopts ":l:t:d:sfh" opt; do
        case ${opt} in
            l ) # Limit of images
                LIMIT="$OPTARG"
              ;;
            t ) # modified t minutes ago
                MMIN="$OPTARG"
              ;;
            d ) # modified d days ago
                MTIME="$OPTARG"
              ;;
            s ) # Slideshow mode
                SLIDESHOW=true
              ;;
            f ) # Fullscreen mode
                FULLSCREEN=true
              ;;
            h ) # Help
                print_help
                exit 0
              ;;
            \? )
                print_help
                exit 10
              ;;
            : )
                echo "Option $OPTARG requires an argument"
              ;;
        esac
    done
    shift $((OPTIND -1))
}

get_files()
{
    if [[ $MMIN -gt 0 ]];then
        jsonFilesFound="$(find . -mindepth 3 -type f -mmin +0 -mmin "-${MMIN}" -iname '*json' -printf '%T@:%p\n' | sort )"
    elif [[ $MTIME -gt 0 ]];then
        # find -mtime  0: find files modified between now and one day ago. Does not seem to work with -mtime -n.
        # find -mtime +0: find files modified greater than one day ago
        # NOTE: -mmin does not seem to have similar behavior and always requires a +, maybe?
        #jsonFilesFound="$(find . -mindepth 2 -type f -mtime 0 -mtime "-${MTIME}" -iname '*json' -printf '%T@:%p\n' | sort )"
        MTIME=$((MTIME * MINS_PER_DAY))
        jsonFilesFound="$(find . -mindepth 3 -type f -mmin +0 -mmin "-${MTIME}" -iname '*json' -printf '%T@:%p\n' | sort )"
    else
        jsonFilesFound="$(find . -mindepth 3 -type f -iname '*json' -printf '%T@:%p\n' | sort )"
    fi
    if [ -z "$jsonFilesFound" ];then
        tput bold
        tput setaf 1
        echo ">>> No files found!"
        tput sgr0
        exit 20
    fi
    readarray -t jsonFiles  <<< "$jsonFilesFound"
}

gen_data()
{
    # Assembles data structure of fimage filename and timestamp.

    i=0
    while [[ $i -lt ${#jsonFiles[@]} ]];do

        local timestamp="$( sed -E 's/^(.*):.*$/\1/' <<< "${jsonFiles[$i]}")"
        local jsonFile="$( sed -E 's/^.*:(.*)/\1/' <<< "${jsonFiles[$i]}")"
        local image_name="$(basename "$(jq -r ".data.url" "$jsonFile")")"
        local id="$(jq -r ".data.id" "$jsonFile")"
        local sanitized_title="$(jq -r ".data.permalink" "$jsonFile")"
        local sanitized_title="${sanitized_title%%/}"
        local sanitized_title="${sanitized_title##*/}"
        local subreddit="$(jq -r ".data.subreddit" "$jsonFile")"
        local file_dir="${id}___${sanitized_title}"
        local file_path="${subreddit}/${file_dir}/${image_name}"
        #local timestamp="$(jq -r '.data.created_utc' "${jsonFiles[$i]}")"

        TIMESTAMPED_IMAGES[$i]="${timestamp}:${file_path}"
        i=$((i+1))
    done
}

make_filelist()
{
    if [[ $LIMIT -gt 0 ]];then
        for file in "${TIMESTAMPED_IMAGES[@]}";do
            printf '%s\n' "$file"
        done | sort -nr | sed -E 's/^.*:(.*)$/\1/' | head -n "${LIMIT}" > "$FILE_LIST"
    else
        for file in "${TIMESTAMPED_IMAGES[@]}";do
            printf '%s\n' "$file"
        done | sort -nr | sed -E 's/^.*:(.*)$/\1/' > "$FILE_LIST"
    fi
}

view_fullscreen()
{
    feh --quiet \
        --fullscreen \
        --image-bg black \
        --recursive \
        --auto-zoom \
        --action1 'imageName=%F;jsonName="${imageName%%.*}.json";id="$(jq -r .data.id "$jsonName")";echo "$id" >> blacklist.txt' \
        --filelist "${FILE_LIST}" &
}

view_slideshow()
{
    feh --quiet \
        --fullscreen \
        --image-bg black \
        --recursive \
        --auto-zoom \
        --slideshow-delay 5.0 \
        --filelist "${FILE_LIST}" &
}

view_normal_constrained()
{
    feh --quiet \
        --scale-down \
        --image-bg black \
        --recursive \
        --sort mtime \
        --auto-zoom \
        --action1 'imageName=%F;jsonName="${imageName%%.*}.json";id="$(jq -r .data.id "$jsonName")";echo "$id" >> blacklist.txt' \
        --filelist "${FILE_LIST}"
}

view_normal()
{
    feh --quiet \
        --scale-down \
        --image-bg black \
        --recursive \
        --sort mtime \
        --auto-zoom \
        --action1 'imageName=%F;jsonName="${imageName%%.*}.json";id="$(jq -r .data.id "$jsonName")";echo "$id" >> blacklist.txt' \
        . &
}

# ---------------------------------------------------------------------------------------------------- #
#
#                                                                                        MAIN SEQUENCE
#
# ---------------------------------------------------------------------------------------------------- #
if [ -z "$1" ];then
    view_normal
    exit 0
fi

parse_input "$@"
get_files
gen_data
make_filelist

if [[ $SLIDESHOW == true ]];then
    view_slideshow
    exit 0
fi
if [[ $FULLSCREEN == true ]];then
    view_fullscreen
    exit 0
fi
view_normal_constrained
