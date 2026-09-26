#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TARGET_DEVICE="${1:-${TARGET_DEVICE:-enduro3}}"
readonly BUILD_MODE="${2:-${BUILD_MODE:-debug}}"
readonly APP_FILE="${OUTPUT_FILE:-${PROJECT_DIR}/bin/Liam.prg}"
readonly APP_NAME="$(basename "${APP_FILE}")"
readonly MTP_APPS_PATH="${MTP_APPS_PATH:-/GARMIN/Apps}"
readonly AUTO_INSTALL_LIBMTP="${AUTO_INSTALL_LIBMTP:-1}"

install_libmtp() {
    if command -v mtp-sendfile >/dev/null && command -v mtp-folders >/dev/null && command -v mtp-files >/dev/null && command -v mtp-delfile >/dev/null; then
        return
    fi

    if [[ "${AUTO_INSTALL_LIBMTP}" != "1" ]]; then
        printf 'Error: libmtp tools are required. Install them with: brew install libmtp\n' >&2
        exit 1
    fi

    if ! command -v brew >/dev/null; then
        printf 'Error: Homebrew is required to install libmtp. See https://brew.sh\n' >&2
        exit 1
    fi

    printf 'Installing libmtp with Homebrew...\n'
    brew install libmtp
}

list_mtp_folders() {
    local output
    if ! output="$(mtp-folders 2>&1)"; then
        printf '%s\n' "${output}" >&2
        printf 'Error: unable to query the MTP device. Quit Garmin Express, reconnect the watch, and try again.\n' >&2
        exit 1
    fi

    if [[ "${output}" == *"no devices found"* || "${output}" == *"No devices found"* ]]; then
        printf 'Error: no MTP device found. Connect and unlock the watch, then try again.\n' >&2
        exit 1
    fi

    printf '%s\n' "${output}"
}

find_apps_folder_id() {
    local folders="$1"
    local folder_name="${MTP_APPS_PATH##*/}"
    printf '%s\n' "${folders}" | awk -v name="${folder_name}" '
        /^[0-9]+[[:space:]]+/ {
            id = $1
            line = $0
            sub(/^[0-9]+[[:space:]]+/, "", line)
            sub(/^[[:space:]]+/, "", line)
            if (tolower(line) == tolower(name)) {
                print id
                exit
            }
        }
    '
}

find_existing_app_id() {
    local apps_folder_id="$1"
    local output
    output="$(mtp-files 2>&1)"

    printf '%s\n' "${output}" | awk -v filename="${APP_NAME}" -v parent_id="${apps_folder_id}" '
        BEGIN { RS="File ID: "; FS="\n" }
        NR > 1 {
            id = $1
            current_filename = ""
            current_parent_id = ""
            for (i = 2; i <= NF; i++) {
                if ($i ~ /^[[:space:]]*Filename:/) {
                    current_filename = $i
                    sub(/^[[:space:]]*Filename:[[:space:]]*/, "", current_filename)
                } else if ($i ~ /^[[:space:]]*Parent ID:/) {
                    current_parent_id = $i
                    sub(/^[[:space:]]*Parent ID:[[:space:]]*/, "", current_parent_id)
                }
            }
            if (match_id == "" && tolower(current_filename) == tolower(filename) && current_parent_id == parent_id) {
                match_id = id
            }
        }
        END {
            if (match_id != "") {
                print match_id
            }
        }
    '
}

install_libmtp

printf 'Building %s for %s in %s mode...\n' "${APP_NAME}" "${TARGET_DEVICE}" "${BUILD_MODE}"
"${PROJECT_DIR}/build.sh" "${TARGET_DEVICE}" "${BUILD_MODE}"

if [[ ! -r "${APP_FILE}" ]]; then
    printf 'Error: build output not found at %s\n' "${APP_FILE}" >&2
    exit 1
fi

printf 'Looking for a connected Garmin watch...\n'
folders="$(list_mtp_folders)"
apps_folder_id="$(find_apps_folder_id "${folders}")"
if [[ -z "${apps_folder_id}" ]]; then
    printf 'Error: MTP folder %s was not found. Available folders:\n%s\n' "${MTP_APPS_PATH}" "${folders}" >&2
    printf 'Set MTP_APPS_PATH to the Apps folder path reported by mtp-folders.\n' >&2
    exit 1
fi

readonly REMOTE_FILE="${MTP_APPS_PATH}/${APP_NAME}"
printf 'Checking for an existing %s...\n' "${REMOTE_FILE}"
existing_app_id="$(find_existing_app_id "${apps_folder_id}")"
if [[ -n "${existing_app_id}" ]]; then
    printf 'Removing existing MTP object %s...\n' "${existing_app_id}"
    mtp-delfile -n "${existing_app_id}"
else
    printf 'No existing %s found; skipping removal.\n' "${APP_NAME}"
fi

printf 'Uploading %s to %s...\n' "${APP_FILE}" "${MTP_APPS_PATH}"
mtp-sendfile "${APP_FILE}" "${apps_folder_id}"

printf 'Deployed %s. Disconnect the watch from USB to let Garmin load it.\n' "${APP_NAME}"
