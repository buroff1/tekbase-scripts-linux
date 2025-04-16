#!/bin/bash

# TekLabs TekBase - Auto-Updater Script
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

# Setup Paths & Logging
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"

mkdir -p "$LOGP/logs"
chmod 0777 "$LOGP/logs"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

# Git Check and Installation
if ! command -v git >/dev/null 2>&1; then
    if grep -qi "CentOS\|Fedora\|Red Hat" /etc/*-release; then
        yum install git -y
    elif grep -qi "Debian\|Ubuntu" /etc/*-release; then
        apt-get install git -y
    elif grep -qi "SUSE" /etc/*-release; then
        zypper install git -y
    fi
fi
# Re-check Git availability after install
if ! command -v git >/dev/null 2>&1; then
    log_msg "Git installation failed. Exiting updater."
    exit 1
fi
# Update Logic
if [ ! -d ".git" ]; then
    git clone https://github.com/teklab-de/tekbase-scripts-linux.git tmp-tekbase
    cd tmp-tekbase || exit 1
    mv * ../
    mv .git ../
    cd ..
    rm -rf tmp-tekbase
    version="initial"
    newversion="cloned"
else
    version=$(git rev-parse HEAD)
    git fetch
    git reset --hard origin/master
    newversion=$(git rev-parse HEAD)
fi

# Result Logging
if [ "$version" != "$newversion" ]; then
    log_msg "The scripts have been updated from $version to $newversion"
else
    log_msg "There are no script updates available (current: $version)"
fi

# TekBASE 8.x Compatibility: .sh → executable
for FILE in ./*.sh; do
    cp "$FILE" "${FILE%.sh}"
done

exit 0