#!/bin/bash

# TekLabs TekBase - Dedicated Server Utility Script
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

VAR_A="$1"
VAR_B="$2"
VAR_C="$3"

# Setup
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"
RESTART_PATH="$LOGP/restart"

mkdir -p "$LOGP/logs" "$RESTART_PATH"
chmod 0777 "$LOGP/logs" "$RESTART_PATH"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

[ -z "$VAR_A" ] && ./tekbase && exit 0

# --- MEMORY, SWAP, TRAFFIC, UPTIME, HDD ---
if [ "$VAR_A" = "info" ]; then
    read memt memu memf memb memc <<< $(free -k | awk '/^Mem:/ {print $2, $3, $4, $6, $7}')
    ((memb += memc))
    ((memf += memb))
    ((memu -= memb))
    memall="$memt $memu $memf"

    swapall=$(free -k | awk '/^Swap:/ {print $2, $3, $4}')
    traffic=$(vnstat -m 2>/dev/null | grep -i "$VAR_B" | awk '{print $9, $10}')
    runtime=$(uptime -p | sed 's/up //')
    hddall=$(df -h | grep /dev/[hsmx][abcdefgv] | awk '{print $1, $2, $3, $4}')

    echo "$memall%TD%$swapall%TD%$traffic%TD%$runtime%TD%$hddall"
fi

# --- LIST INIT SERVICES ---
if [ "$VAR_A" = "list" ]; then
    cd /etc/init.d || exit 1
    ls -l | awk '{print $1"%TD%"$NF"%TEND%"}'
fi

# --- KILL PROCESS ---
if [ "$VAR_A" = "process" ]; then
    kill -9 "$VAR_B" 2>/dev/null
    check=$(ps -p "$VAR_B" | grep -v "PID TTY")
    if [ -z "$check" ]; then
        log_msg "Process $VAR_B was killed"
        echo "ID1"
    else
        log_msg "Process $VAR_B could not be killed"
        echo "ID2"
    fi
fi

# --- PROCESS LIST ---
if [ "$VAR_A" = "psaux" ]; then
    ps aux --sort pid | grep -v -E "ps aux|awk|tekbase|perl -e" | awk '
    {
        printf($1"%TD%")
        printf($2"%TD%")
        printf($3"%TD%")
        printf($4"%TD%")
        for (i=11; i<=NF; i++) {
            printf("%s ", $i)
        }
        print("%TEND%")
    }'
fi

# --- INIT SERVICE CONTROL ---
if [ "$VAR_A" = "service" ]; then
    cd /etc/init.d || exit 1
    if [ -f "$VAR_B" ]; then
        ./"$VAR_B" "$VAR_C"
        echo "ID1"
    else
        log_msg "Service script $VAR_B not found"
        echo "ID2"
    fi
fi

# --- INTERFACE TRAFFIC ---
if [ "$VAR_A" = "traffic" ]; then
    traffic=$(vnstat -m 2>/dev/null | grep -i "$VAR_B" | awk '{print $9, $10}')
    traffictwo=$(vnstat -m 2>/dev/null | grep -i "$VAR_C" | awk '{print $9, $10}')
    echo "$traffic-$traffictwo"
fi

# --- REBOOT ---
if [ "$VAR_A" = "reboot" ]; then
    log_msg "System reboot triggered by TekBASE"
    reboot
fi

# --- SHUTDOWN ---
if [ "$VAR_A" = "shutdown" ]; then
    log_msg "System shutdown triggered by TekBASE"
    shutdown -h now
fi

exit 0