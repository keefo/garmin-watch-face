#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GARMIN_HOME="${HOME}/Library/Application Support/Garmin/ConnectIQ"
readonly TARGET_DEVICE="${1:-${TARGET_DEVICE:-enduro3}}"
readonly BUILD_MODE="${2:-${BUILD_MODE:-debug}}"
readonly DEVELOPER_KEY="${CONNECTIQ_DEVELOPER_KEY:-${HOME}/.config/garmin/developer_key.der}"
readonly OUTPUT_FILE="${OUTPUT_FILE:-${PROJECT_DIR}/bin/Liam.prg}"

case "${BUILD_MODE}" in
    debug)
        BUILD_FLAGS=(-w)
        ;;
    release)
        BUILD_FLAGS=(-w -r -O 2)
        ;;
    *)
        printf 'Error: build mode must be "debug" or "release", got "%s".\n' "${BUILD_MODE}" >&2
        exit 1
        ;;
esac

if [[ -n "${CONNECTIQ_SDK_HOME:-}" ]]; then
    SDK_HOME="${CONNECTIQ_SDK_HOME}"
elif [[ -d "${GARMIN_HOME}/Sdks" ]]; then
    SDK_HOME="$(find "${GARMIN_HOME}/Sdks" -mindepth 1 -maxdepth 1 -type d -name 'connectiq-sdk-mac-*' 2>/dev/null | sort -V | tail -n 1)"
else
    SDK_HOME=""
fi

if [[ -z "${SDK_HOME}" || ! -x "${SDK_HOME}/bin/monkeyc" ]]; then
    printf 'Error: Connect IQ SDK not found. Install it with Garmin SDK Manager or set CONNECTIQ_SDK_HOME.\n' >&2
    exit 1
fi

if [[ ! -d "${GARMIN_HOME}/Devices/${TARGET_DEVICE}" ]]; then
    printf 'Error: device definition "%s" is not installed. Add it with Garmin SDK Manager.\n' "${TARGET_DEVICE}" >&2
    exit 1
fi

if [[ ! -r "${DEVELOPER_KEY}" ]]; then
    printf 'Error: developer key not found at %s. Set CONNECTIQ_DEVELOPER_KEY.\n' "${DEVELOPER_KEY}" >&2
    exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

printf 'Building Liam for %s in %s mode with Connect IQ SDK %s...\n' "${TARGET_DEVICE}" "${BUILD_MODE}" "$(basename "${SDK_HOME}")"
"${SDK_HOME}/bin/monkeyc" \
    -f "${PROJECT_DIR}/monkey.jungle" \
    -d "${TARGET_DEVICE}" \
    -y "${DEVELOPER_KEY}" \
    -o "${OUTPUT_FILE}" \
    "${BUILD_FLAGS[@]}"

printf 'Built %s\n' "${OUTPUT_FILE}"