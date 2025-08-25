#!/bin/bash

# This script searches through .tgz archives in a given input directory for occurrences
# of a specified search string within daemon.log files (including rotated and compressed versions).
# It extracts only matching daemon log files into a 'matched_logs' directory and cleans up temporary data.

set -euo pipefail

# === GLOBAL VARIABLES ===
INPUT_DIR=""
SEARCH_STRING=""
WORK_DIR="./extracted_logs"
MATCH_DIR="./matched_logs"

print_usage() {
    printf "Usage: %s <input_directory> <search_string>\n" "$(basename "$0")" >&2
}

validate_arguments() {
    if [[ $# -ne 2 ]]; then
        print_usage
        return 1
    fi

    INPUT_DIR="$1"
    SEARCH_STRING="$2"

    if [[ ! -d "$INPUT_DIR" ]]; then
        printf "Error: Input directory not found: %s\n" "$INPUT_DIR" >&2
        return 1
    fi

    if [[ -z "$SEARCH_STRING" || "$SEARCH_STRING" =~ ^[[:space:]]*$ ]]; then
        printf "Error: Search string is empty or only whitespace\n" >&2
        return 1
    fi
}

sanitize_filename() {
    local input="$1"
    printf "%s\n" "${input//[^a-zA-Z0-9._-]/_}"
}

extract_daemon_logs_from_tgz() {
    local tgz_file="$1"
    local dest_dir="$2"

    mkdir -p "$dest_dir"

    local paths
    if ! paths=$(tar -tzf "$tgz_file" | grep -E '/var/log/daemon\.log(\.[0-9]+)?(\.gz)?$' || true); then
        printf "Could not list contents of %s\n" "$tgz_file" >&2
        return 1
    fi

    if [[ -z "$paths" ]]; then
        printf "No daemon.log files in %s\n" "$tgz_file" >&2
        return 1
    fi

    local path
    while IFS= read -r path; do
        if ! tar -xzf "$tgz_file" -C "$dest_dir" "$path" 2>/dev/null; then
            printf "Failed to extract: %s from %s\n" "$path" "$tgz_file" >&2
        fi
    done <<< "$paths"
}

find_daemon_logs() {
    local base_dir="$1"
    find "$base_dir" -type f -name "daemon.log*" ! -name "*.swp"
}

search_in_logs() {
    local search_dir="$1"
    local result_dir="$2"
    local tgz_name="$3"
    local found=1

    if ! matches=$(find_daemon_logs "$search_dir"); then
        printf "Failed to find daemon logs in %s\n" "$search_dir" >&2
        return 1
    fi

    while IFS= read -r file; do
        local match=0
        if [[ "$file" == *.gz ]]; then
            if zgrep -q -- "$SEARCH_STRING" "$file"; then
                match=1
            fi
        else
            if grep -q -- "$SEARCH_STRING" "$file"; then
                match=1
            fi
        fi

        if [[ $match -eq 1 ]]; then
            mkdir -p "$result_dir"
            cp "$file" "$result_dir/"
            found=0
        fi
    done <<< "$matches"

    return $found
}

prepare_output_dirs() {
    mkdir -p "$WORK_DIR"
    mkdir -p "$MATCH_DIR"
}

cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        chmod -R u+rw "$WORK_DIR" 2>/dev/null || true
        chown -R "$(whoami)" "$WORK_DIR" 2>/dev/null || true
        rm -rf "$WORK_DIR"
    fi
}

main() {
    if ! validate_arguments "$@"; then
        return 1
    fi

    prepare_output_dirs

    shopt -s nullglob
    local tgz_file
    for tgz_file in "$INPUT_DIR"/*.tgz; do
        local tgz_base; tgz_base=$(basename "$tgz_file")
        local safe_name; safe_name=$(sanitize_filename "$tgz_base")
        local extract_path="$WORK_DIR/$safe_name"

        if ! extract_daemon_logs_from_tgz "$tgz_file" "$extract_path"; then
            continue
        fi

        local match_path="$MATCH_DIR/$safe_name"
        if search_in_logs "$extract_path" "$match_path" "$safe_name"; then
            printf "Match found in: %s\n" "$tgz_base"
        fi
    done

    cleanup
}

main "$@"
