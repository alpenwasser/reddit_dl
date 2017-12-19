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
declare -a DIRECTORIES

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

file_not_found_error()
{
    local file_path="$1"

    tput bold
    printf '>>> '
    tput setaf 1
    printf 'ERROR: '
    tput sgr0
    printf 'File not found: %s\n' "$file_path"
    tput sgr0
}

ensure_camelcasing()
{
    local subreddit="$1"

    if [[ "$subreddit" == "spaceporn" ]];then
        subreddit="SpacePorn"
    elif [[ "$subreddit" == "winterporn" ]];then
        subreddit="WinterPorn"
    elif [[ "$subreddit" == "seaporn" ]];then
        subreddit="SeaPorn"
    elif [[ "$subreddit" == "waterporn" ]];then
        subreddit="WaterPorn"
    fi

    printf '%s' "$subreddit"
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
        dirsFound="$(find . -mindepth 2 -type d -mmin +0 -mmin "-${MMIN}" -printf '%T@:%p\n' | sort )"
    elif [[ $MTIME -gt 0 ]];then
        # find -mtime  0: find files modified between now and one day ago. Does not seem to work with -mtime -n.
        # find -mtime +0: find files modified greater than one day ago
        # NOTE: -mmin does not seem to have similar behavior and always requires a +, maybe?
        MTIME=$((MTIME * MINS_PER_DAY))
        jsonFilesFound="$(find . -mindepth 3 -type f -mmin +0 -mmin "-${MTIME}" -iname '*json' -printf '%T@:%p\n' | sort )"
        dirsFound="$(find . -mindepth 2 -type d -mmin +0 -mmin "-${MTIME}" -printf '%T@:%p\n' | sort )"
    else
        jsonFilesFound="$(find . -mindepth 3 -type f -iname '*json' -printf '%T@:%p\n' | sort )"
        dirsFound="$(find . -mindepth 2 -type d -printf '%T@:%p\n' | sort )"
    fi
    if [ -z "$dirsFound" ];then
        tput bold
        tput setaf 1
        echo ">>> No files found!"
        tput sgr0
        exit 20
    fi
    readarray -t DIRECTORIES  <<< "$dirsFound"
}

gen_data()
{
    # Assembles data structure of fimage filename and timestamp.
    i=0
    while [[ $i -lt ${#DIRECTORIES[@]} ]];do
        image="$(find "${DIRECTORIES[$i]#*:}" -type f -not -iname '*json')"
        if [ -z "$image" ];then
            rmdir -v "${DIRECTORIES[$i]#*:}"
            i=$((i+1))
            continue
        fi
        timestamp="${DIRECTORIES[$i]%:*}"
        TIMESTAMPED_IMAGES[$i]="${timestamp}:${image}"
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
        --filelist "${FILE_LIST}" &
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
