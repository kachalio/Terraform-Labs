#!/usr/bin/env bash

set -Eeuo pipefail

readonly INSTALL_DIR="/install"
readonly DOWNLOAD_MANAGER_URL="https://d149oh3iywgk04.cloudfront.net/dwnldmgr/HANA2latest/HXEDownloadManager.jar"
readonly JDK_URL="https://download.oracle.com/java/26/latest/jdk-26_linux-x64_bin.rpm"

log() {
    printf '[INFO] %s\n' "$*"
}

fail() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    printf '[ERROR] Command failed on line %s (exit code %s): %s\n' \
        "${BASH_LINENO[0]}" "$exit_code" "$BASH_COMMAND" >&2
    exit "$exit_code"
}

trap on_error ERR

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

download() {
    local url=$1
    local destination=$2

    log "Downloading $(basename "$destination")..."
    curl --fail --location --show-error --silent \
        --retry 3 --retry-delay 2 \
        --output "$destination" "$url"
}

main() {
    [[ $EUID -eq 0 ]] || fail "This script must be run as root."

    log "Checking required commands..."
    require_command curl
    require_command rpm
    require_command zypper

    log "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    download "$DOWNLOAD_MANAGER_URL" "HXEDownloadManager.jar"
    download "$JDK_URL" "jdk-26_linux-x64_bin.rpm"

    log "Installing the Java JDK..."
    rpm --upgrade --replacepkgs "jdk-26_linux-x64_bin.rpm"
    require_command java

    log "Downloading the SAP HANA trial installer..."
    java -jar "HXEDownloadManager.jar" linuxx86_64 installer "hxe.tgz" -d ./

    log "Unzip installer file..."
    tar -xzf "hxe.tgz"

    log "Installing the libltdl7 dependency..."
    zypper --non-interactive install libltdl7

    log "SAP HANA installer download completed successfully: $INSTALL_DIR/hxe.tgz"

    sudo ./setup_hxe.sh -b \
    --sid HXE \
    -i 90 \
    --hostname "$(hostname -f)" \
    --skip_proxy \
    --master_pwd 'YourPassword1'

    # if fails with dependency issues, use sudo zypper lr -u to see if there's more than 1 repo configured.  Check sudo SUSEConnect --status-text to see these are registered.
}

main "$@"
