#!/usr/bin/env bash

# ---------------------------------------------------------------------------------------------------- #
#
#                                                                                     GLOBAL VARIABLES
#
# ---------------------------------------------------------------------------------------------------- #
DATE="$(date '+%Y-%m-%d')"
TIMESTAMP="$(date '+%Y-%m-%d--%H-%M-%S')"
SUBREDDIT_NAME="$(basename "$(pwd)")"
[ -z "$1" ] && JSON_URL="https://reddit.com/r/${SUBREDDIT_NAME}.json"
LISTING=''
LIMIT=''
TIME=''
CURRENT_PAGE=1
PAGES=1
AFTER=''
COUNT=0
PAGINATION=100
JSON_FILE=''
IMGUR_BASE_URL='https://api.imgur.com/3/image/'
resize 1>/dev/null
TERM_COLS="$(tput cols)"
FAIL_FLAG=false
IMG_COUNT=0
BLACKLIST='blacklist.txt'
BLACKLIST_GLOBAL='../blacklist.txt'


# ---------------------------------------------------------------------------------------------------- #
#
#                                                                                            FUNCTIONS
#
# ---------------------------------------------------------------------------------------------------- #

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

check_blacklist()
{
    # Returns 0 if entry found in blacklist.

    id="$1"

    # Nothing to worry about if blacklist does not even exist.
    if ! [ -f "$BLACKLIST" ];then
        printf '1'
        return
    fi

    # Check local blacklist first.
    grep -qP "^${id}$" "$BLACKLIST"
    if [[ "$?" -eq 0 ]];then
        printf '0'
    else
        # If nothing found in local list, check global list.
        if ! [ -f "$BLACKLIST_GLOBAL" ];then
            printf '1'
            return
        fi
        grep -qP "^${id}$" "$BLACKLIST_GLOBAL"
        if [[ "$?" -eq 0 ]];then
            printf '0'
        else
            # No entry in blacklist.
            printf '1'
        fi
    fi
}

generate_json_url()
{
    JSON_URL="https://reddit.com/r/${SUBREDDIT_NAME}.json"

    if ! [ -z "$LISTING" ];then
        JSON_URL="https://reddit.com/r/${SUBREDDIT_NAME}/${LISTING}.json"
    fi
    if ! [ -z "$LIMIT" ];then
        # If no other parameters have been passed to GET yet, this is the
        # first one. Append with question mark.
        if [[ ! ${JSON_URL} =~ json\? ]];then
            JSON_URL="${JSON_URL}?limit=${LIMIT}"
        else
            JSON_URL="${JSON_URL}&limit=${LIMIT}"
        fi
    fi
    if ! [ -z "$TIME" ];then
        # If no other parameters have been passed to GET yet, this is the
        # first one. Append with question mark.
        if [[ ! ${JSON_URL} =~ json\? ]];then
            JSON_URL="${JSON_URL}?t=${TIME}"
        else
            JSON_URL="${JSON_URL}&t=${TIME}"
        fi
    fi
    if ! [ -z "$AFTER" ];then
        # If no other parameters have been passed to GET yet, this is the
        # first one. Append with question mark.
        if [[ ! ${JSON_URL} =~ json\? ]];then
            JSON_URL="${JSON_URL}?after=${AFTER}"
        else
            JSON_URL="${JSON_URL}&after=${AFTER}"
        fi
    fi
    if ! [ -z "$COUNT" ];then
        # If no other parameters have been passed to GET yet, this is the
        # first one. Append with question mark.
        if [[ ! ${JSON_URL} =~ json\? ]];then
            JSON_URL="${JSON_URL}?count=${COUNT}"
        else
            JSON_URL="${JSON_URL}&count=${COUNT}"
        fi
    fi
}

parse_input()
{
    local OPTIND

    while getopts ":L:l:t:s:p:" opt; do
        case ${opt} in
            L )
                LISTING="$OPTARG"
              ;;
            l )
                LIMIT="$OPTARG"
                PAGINATION="$OPTARG"
              ;;
            t )
                TIME="$OPTARG"
              ;;
            s )
                COUNT=$((OPTARG * PAGINATION))
              ;;
            p )
                PAGES="$OPTARG"
              ;;
            \? )
                tput bold
                echo ">>> Usage"
                tput sgr0
                echo "$0 [-L listing] [-l limit] [-t time] [-s starting page] [-p page]"
                tput bold
                echo -e "\n>>> Argument List:"
                tput sgr0
                echo "-L: String. Type of listing. Valid options: new, top, hot"
                echo "-l: Positive integer. Limit"
                echo "-t: String. Time. Valid options: week, month, year, all"
                echo "-s: Positive integer. Page on which to start parse."
                echo "-p: Positive integer. Number of pages to parse."
                exit 10
              ;;
            : )
                echo "Option $OPTARG requires an argument"
              ;;
        esac
    done
    shift $((OPTIND -1))
}

download_json()
{
    wget -q "$JSON_URL" -O "$JSON_FILE"
    if [[ "$?" -eq 0 ]];then
        print_status 'OK' 2
        printf '   Downloading JSON data for page %d of %d\n' "$CURRENT_PAGE" "$PAGES"
    else
        print_status 'FAIL' 1
        FAIL_FLAG=true
        printf ' Downloading JSON data for page %d of %d\n' "$CURRENT_PAGE" "$PAGES"
    fi
}

download_posts()
{
    i=0 # number of iterations
    for file in $(jq -r '.data.children[].data.url' "$JSON_FILE");do
        # Update width information
        resize 1>/dev/null
        TERM_COLS="$(tput cols)"

        # We want to make sure that the correct title getes associated
        # with its url, so we access the url and the title by numerical
        # index to be on the safe side.
        local url="$(jq -r ".data.children[${i}].data.url" "$JSON_FILE")"
        local title="$(jq -r ".data.children[${i}].data.title" "$JSON_FILE")"

        # Prepare some strings.
        local filename="$(basename "$url")"
        local id="$(jq -r ".data.children[${i}].data.id" "$JSON_FILE")"
        local sanitized_title="$(jq -r ".data.children[${i}].data.permalink" "$JSON_FILE")"
        local sanitized_title="${sanitized_title%%/}"
        local sanitized_title="${sanitized_title##*/}"
        local target_dir="${id}___${sanitized_title}"

        # Skip blacklisted entries
        if [[ "$(check_blacklist "$id")" -eq 0 ]];then
            i=$((i+1))
            continue
        fi

        # Skip rest of loop if post has already been synced.
        if [ -d "$target_dir" ];then
            i=$((i+1))
            continue
        else
            mkdir -p "$target_dir"
        fi
        if [[ ! ("$url" =~ jpg$ || "$url" =~ jpeg$ || "$url" =~ png$ || "$url" =~ PNG$ || "$url" =~ JPEG$ || "$url" =~ JPG$ ) ]];then
            # Images hosted on imgur
            if [[ "$url" =~ https:\/\/api.imgur ]];then
                # Prepare filenames
                imageHash="${url##*/}"
                imageJSON=$(mktemp)

                # Grab imgur JSON
                wget -q "${IMGUR_BASE_URL}${imageHash}" -O "$imageJSON"
                url="$(jq -r ".data.link" "$imageJSON")"

                # Download actual image
                mkdir -p "$target_dir"
                wget -q --no-clobber "$url" -P "$target_dir"

                # Evaluate success
                if [[ "$?" -eq 0 ]];then
                    print_status 'OK' 2
                    string_cols=$((TERM_COLS - 17))
                    printf "\t\t%s\n" "${title:0:${string_cols}}"
                    IMG_COUNT=$((IMG_COUNT+1))
                else
                    print_status 'FAIL' 1
                    string_cols=$((TERM_COLS - 19))
                    printf "\t%s\n" "${title:0:${string_cols}}"
                    rm -rf "$target_dir"
                    FAIL_FLAG=true
                fi
                rm -f "$imageJSON"
            elif [[ "$url" =~ https:\/\/i.imgur ]];then
                # No JSON Present; direct image link

                # Download actual image
                mkdir -p "$target_dir"
                wget -q --no-clobber "$url" -P "$target_dir"

                # Evaluate success
                if [[ "$?" -eq 0 ]];then
                    print_status 'OK' 2
                    string_cols=$((TERM_COLS - 17))
                    printf "\t\t%s\n" "${title:0:${string_cols}}"
                    IMG_COUNT=$((IMG_COUNT+1))
                else
                    print_status 'FAIL' 1
                    string_cols=$((TERM_COLS - 19))
                    printf "\t%s\n" "${title:0:${string_cols}}"
                    rm -rf "$target_dir"
                    FAIL_FLAG=true
                fi
            fi
        else
            # Download image if it is a direct image link.
            wget -q --no-clobber "$url" -P "$target_dir"

            # Evaluate success
            if [ -f "${target_dir}/${filename}" ];then
                if [[ "$?" -eq 0 ]];then
                    print_status 'OK' 2
                    string_cols=$((TERM_COLS - 17))
                    printf "\t\t%s\n" "${title:0:${string_cols}}"
                    IMG_COUNT=$((IMG_COUNT+1))
                else
                    print_status 'FAIL' 1
                    string_cols=$((TERM_COLS - 19))
                    printf "\t%s\n" "${title:0:${string_cols}}"
                    rm -rf "$target_dir"
                    FAIL_FLAG=true
                fi
            fi
        fi

        # Store metadata.
        basenameJSON="${filename%%.*}.json"
        [ -f "${target_dir}/${filename}" ] && \
            jq -r ".data.children[${i}]" "$JSON_FILE" > "${target_dir}/${basenameJSON}"

        i=$((i+1))
    done
}

# ---------------------------------------------------------------------------------------------------- #
#
#                                                                                        MAIN SEQUENCE
#
# ---------------------------------------------------------------------------------------------------- #
parse_input "$@"
generate_json_url
while [[ "$CURRENT_PAGE" -le "$PAGES" ]];do
    generate_json_url
    #echo "$JSON_URL"

    JSON_FILE="$(mktemp)"
    download_json

    download_posts
    #jq .data.after "$JSON_FILE"
    #jq .data.before "$JSON_FILE"
    #jq .data.children[].data.id "$JSON_FILE"

    AFTER="$(jq -r .data.after "$JSON_FILE")"
    COUNT=$((PAGINATION * $CURRENT_PAGE))
    CURRENT_PAGE=$((CURRENT_PAGE + 1))
    rm -f "$JSON_FILE"
done
if [[ "$FAIL_FLAG" == false ]];then
    print_status 'OK' 2
    printf '   Downloaded %d new images. No errors occurred.\n' "$IMG_COUNT"
    exit 0
else
    print_status 'FAIL' 1
    printf ' Downloaded %d new images. Some errors occurred.\n' "$IMG_COUNT"
    exit 2
fi
