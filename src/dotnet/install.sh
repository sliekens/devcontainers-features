#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Docs: https://github.com/devcontainers/features/tree/main/src/dotnet
# Maintainer: The Dev Container spec maintainers
DOTNET_VERSION="${VERSION}"
ADDITIONAL_VERSIONS="${ADDITIONALVERSIONS}"

DOTNET_INSTALL_SCRIPT='scripts/vendor/dotnet-install.sh'
DOTNET_INSTALL_DIR='/usr/share/dotnet'

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

# Setup STDERR.
err() {
    echo "(!) $*" >&2
}

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

fetch_latest_sdk_version_in_channel() {
    local channel="$1"
    wget -qO- "https://dotnetcli.azureedge.net/dotnet/Sdk/$channel/latest.version"
}

fetch_latest_sdk_version() {
    local sts_version
    local lts_version
    sts_version=$(fetch_latest_sdk_version_in_channel "STS")
    lts_version=$(fetch_latest_sdk_version_in_channel "LTS")
    if [[ "$sts_version" > "$lts_version" ]]; then
        echo "$sts_version"
    else
        echo "$lts_version"
    fi
}

# Splits comma-separated values into an array
split_csv() {
    local OLD_IFS=$IFS
    IFS=","
    read -a values <<< "$1"
    IFS=$OLD_IFS
    echo "${values[@]}"
}

# Removes leading and trailing whitespace from an input string
trim_whitespace() {
    echo $1 | tr -d '[:space:]'
}

if [ "$(id -u)" -ne 0 ]; then
    err 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# For our own convenience, combine DOTNET_VERSION and ADDITIONAL_VERSIONS into a single 'versions' array
# Ensure there are no leading or trailing spaces that can break regex pattern matching
versions=($(trim_whitespace "$DOTNET_VERSION"))
for additional_version in $(split_csv "$ADDITIONAL_VERSIONS"); do
    versions+=($(trim_whitespace "$additional_version"))
done

# Fail fast in case of bad input to avoid unneccesary work
for version in "${versions[@]}"; do
    if [[ "$version" =~ ^[0-9]+$ ]]; then
        # v1 of the .NET feature allowed specifying only a major version 'X' like '3'
        # v2 removed this ability
        # - because install-dotnet.sh does not support it directly
        # - because the previous behavior installed an old version like '3.0.103', not the newest version '3.1.426', which was counterintuitive
        err "Unsupported .NET SDK version '${version}'. Use 'latest' for the latest version, 'lts' for the latest LTS version, 'X.Y' or 'X.Y.Z' for a specific version."
        exit 1
    fi
done

# Install .NET versions and dependencies
# icu-devtools includes dependencies for .NET
check_packages wget ca-certificates icu-devtools


for version in "${versions[@]}"; do
    install_version $version
done

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf scripts

echo "Done!"
