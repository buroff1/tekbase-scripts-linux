#!/bin/bash

# TekLabs TekBase - Modernized OpenVZ Management Script
# Maintainer: Christian Frankenstein
# Updated: 2025-04-16
# Features:
# - Centralized logging
# - Safe vzctl/vzdump operations
# - Structured command routines
# - Screen-based process handling
# - OpenVZ only (no Docker/symlink)

# Parameters
VAR_A="$1"  # Action
VAR_B="$2"  # VE ID (CTID)
VAR_C="$3"  # Template / Filename / Maxfiles / New rootpw
VAR_D="$4"  # (Optional) Unused / Template
VAR_E="$5"
VAR_F="$6"
VAR_G="$7"
VAR_H="$8"
VAR_I="$9"

# Paths and Logging Setup
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"
LOGC=$(date +"%Y_%m-%H_%M_%S")

mkdir -p "$LOGP/logs" "$LOGP/restart" "$LOGP/cache"
chmod -R 0777 "$LOGP/logs" "$LOGP/restart" "$LOGP/cache"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

# Default vzconf path (if settings.ini is missing)
if [ -f "$LOGP/settings.ini" ]; then
    vzconf=$(grep -i vzconf "$LOGP/settings.ini" | awk '{print $2}')
    [ -z "$vzconf" ] && vzconf="vz/conf"
else
    vzconf="vz/conf"
fi
# ----------------------------
# INSTALL
# ----------------------------
if [ "$VAR_A" = "install" ]; then
    screenname="vinstall$VAR_B-X"
    startchk=$(pgrep -f "screen.*$screenname")
    if [ -z "$startchk" ]; then
        screen -A -m -d -S "$screenname" "$0" installrun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G" "$VAR_H" "$VAR_I"
        sleep 1
        check=$(pgrep -f "screen.*$screenname")
        if [ -z "$check" ]; then
            runcheck=$(vzctl status "$VAR_B" | grep -i running)
            [ -n "$runcheck" ] && echo "ID3" || echo "ID2"
        else
            echo "ID1"
        fi
    else
        echo "ID1"
    fi
fi

# ----------------------------
# INSTALLRUN
# ----------------------------
if [ "$VAR_A" = "installrun" ]; then
    TEMPLATE="$VAR_C"
    IMAGE_URL="$VAR_G"
    CACHE_DIR="/vz/template/cache"
    IMAGE="$CACHE_DIR/$TEMPLATE.tar.gz"

    if [ "$VAR_E" = "delete" ]; then
        vzctl stop "$VAR_B"
        umount -l "/var/lib/vz/root/$VAR_B" 2>/dev/null
        sleep 5
        vzctl destroy "$VAR_B"
        sleep 10
        if [ ! -f "/etc/$vzconf/$VAR_B.conf" ]; then
            log_msg "VServer $VAR_B was deleted"
        else
            log_msg "VServer $VAR_B could not be deleted"
        fi
        cd "/etc/$vzconf"
        rm -f "$VAR_B.conf.destroyed"
        exit 0
    fi

    mkdir -p "$CACHE_DIR"
    cd "$CACHE_DIR"

    # Download if missing
    if [ ! -f "$TEMPLATE.tar.gz" ]; then
        mkdir "$LOGC" && cd "$LOGC"
        wget "$IMAGE_URL/$TEMPLATE.tar.gz" -O "$TEMPLATE.tar.gz"
        mv "$TEMPLATE.tar.gz" "$CACHE_DIR/"
        cd .. && rm -rf "$LOGC"
    else
        wget -q -O "$VAR_B$TEMPLATE.md5" "$IMAGE_URL/$TEMPLATE.tar.gz.md5"
        [ -f "$VAR_B$TEMPLATE.md5" ] && remote_md5=$(cut -d ' ' -f1 "$VAR_B$TEMPLATE.md5") && rm -f "$VAR_B$TEMPLATE.md5"
        local_md5=$(md5sum "$TEMPLATE.tar.gz" | cut -d ' ' -f1)
        if [ "$remote_md5" != "$local_md5" ]; then
            mkdir "$LOGC" && cd "$LOGC"
            wget "$IMAGE_URL/$TEMPLATE.tar.gz" -O "$TEMPLATE.tar.gz"
            mv "$TEMPLATE.tar.gz" "$CACHE_DIR/"
            cd .. && rm -rf "$LOGC"
        fi
    fi

    [ -f "$TEMPLATE.tar.gz" ] && log_msg "Image $TEMPLATE.tar.gz downloaded" || log_msg "Image $TEMPLATE.tar.gz could not be downloaded"

    # Create the container
    vzctl create "$VAR_B" --ostemplate "$TEMPLATE"
    if [ -f "/etc/$vzconf/$VAR_B.conf" ]; then
        log_msg "VServer $VAR_B was created"
        "$0" changerun "$VAR_B" "$VAR_C" "$VAR_D" "install"
    else
        log_msg "VServer $VAR_B could not be created"
    fi
fi
# ----------------------------
# START VSERVER
# ----------------------------
if [ "$VAR_A" = "start" ]; then
    screenname="vstart$VAR_B-X"
    startchk=$(pgrep -f "screen.*$screenname")
    if [ -z "$startchk" ]; then
        screen -A -m -d -S "$screenname" "$0" startrun "$VAR_B"
        sleep 1
        check=$(pgrep -f "screen.*$screenname")
        if [ -z "$check" ]; then
            runcheck=$(vzctl status "$VAR_B" | grep -i running)
            [ -n "$runcheck" ] && echo "ID3" || echo "ID2"
        else
            echo "ID1"
        fi
    else
        echo "ID1"
    fi
fi

if [ "$VAR_A" = "startrun" ]; then
    vzctl stop "$VAR_B" 2>/dev/null
    umount -l "/var/lib/vz/root/$VAR_B" 2>/dev/null
    sleep 2
    vzctl start "$VAR_B"
    runcheck=$(vzctl status "$VAR_B" | grep -i running)
    [ -n "$runcheck" ] && log_msg "VServer $VAR_B started" || log_msg "VServer $VAR_B could not be started"
fi

# ----------------------------
# STOP VSERVER
# ----------------------------
if [ "$VAR_A" = "stop" ]; then
    screenname="vstop$VAR_B-X"
    startchk=$(pgrep -f "screen.*$screenname")
    if [ -z "$startchk" ]; then
        screen -A -m -d -S "$screenname" "$0" stoprun "$VAR_B"
        sleep 1
        check=$(pgrep -f "screen.*$screenname")
        if [ -z "$check" ]; then
            runcheck=$(vzctl status "$VAR_B" | grep -i running)
            [ -z "$runcheck" ] && echo "ID3" || echo "ID2"
        else
            echo "ID1"
        fi
    else
        echo "ID1"
    fi
fi

if [ "$VAR_A" = "stoprun" ]; then
    vzctl stop "$VAR_B"
    umount -l "/var/lib/vz/root/$VAR_B" 2>/dev/null
    sleep 2
    check=$(vzctl status "$VAR_B" | grep -i running)
    [ -z "$check" ] && log_msg "VServer $VAR_B stopped" || log_msg "VServer $VAR_B could not be stopped"
fi

# ----------------------------
# DELETE VSERVER
# ----------------------------
if [ "$VAR_A" = "delete" ]; then
    screenname="vdelete$VAR_B-X"
    startchk=$(pgrep -f "screen.*$screenname")
    if [ -z "$startchk" ]; then
        screen -A -m -d -S "$screenname" "$0" deleterun "$VAR_B"
        sleep 1
        check=$(pgrep -f "screen.*$screenname")
        if [ -z "$check" ]; then
            [ -f "/etc/$vzconf/$VAR_B.conf" ] && echo "ID3" || echo "ID2"
        else
            echo "ID1"
        fi
    else
        echo "ID1"
    fi
fi

if [ "$VAR_A" = "deleterun" ]; then
    vzctl stop "$VAR_B" 2>/dev/null
    umount -l "/var/lib/vz/root/$VAR_B" 2>/dev/null
    sleep 5
    vzctl destroy "$VAR_B"
    sleep 5
    if [ ! -f "/etc/$vzconf/$VAR_B.conf" ]; then
        log_msg "VServer $VAR_B deleted"
    else
        log_msg "VServer $VAR_B could not be deleted"
    fi
    [ -d "/usr/vz/$VAR_B" ] && rm -rf "/usr/vz/$VAR_B"
fi
# ----------------------------
# BACKUP VSERVER
# ----------------------------
if [ "$VAR_A" = "backup" ]; then
    screenname="vbackup$VAR_B-X"
    startchk=$(pgrep -f "screen.*$screenname")
    if [ -z "$startchk" ]; then
        screen -A -m -d -S "$screenname" "$0" backuprun "$VAR_B" "$VAR_C"
        sleep 1
        check=$(pgrep -f "screen.*$screenname")
        if [ -z "$check" ]; then
            runcheck=$(vzctl status "$VAR_B" | grep -i running)
            [ -n "$runcheck" ] && echo "ID3" || echo "ID2"
        else
            echo "ID1"
        fi
    else
        echo "ID1"
    fi
fi

if [ "$VAR_A" = "backuprun" ]; then
    [ -z "$(vzctl status "$VAR_B" | grep -i running)" ] && vzctl start "$VAR_B"
    mkdir -p /usr/vz/"$VAR_B"
    vzdump --compress gzip --maxfiles "$VAR_C" --bwlimit 30720 --dumpdir /usr/vz/"$VAR_B" "$VAR_B"
    cd /usr/vz/"$VAR_B"
    checkfile=$(find vzdump*)
    if [ -n "$checkfile" ]; then
        log_msg "VServer $VAR_B backup was created"
    else
        log_msg "VServer $VAR_B backup could not be created"
    fi
fi

# ----------------------------
# RESTORE VSERVER
# ----------------------------
if [ "$VAR_A" = "restore" ]; then
    screenname="vrestore$VAR_B-X"
    startchk=$(pgrep -f "screen.*$screenname")
    if [ -z "$startchk" ]; then
        screen -A -m -d -S "$screenname" "$0" restorerun "$VAR_B" "$VAR_C"
        sleep 1
        check=$(pgrep -f "screen.*$screenname")
        if [ -z "$check" ]; then
            [ -f /usr/vz/"$VAR_B"/"$VAR_C" ] && echo "ID2" || echo "ID3"
        else
            echo "ID1"
        fi
    else
        echo "ID1"
    fi
fi

if [ "$VAR_A" = "restorerun" ]; then
    BACKUP_PATH="/usr/vz/$VAR_B/$VAR_C"
    if [ ! -f "$BACKUP_PATH" ]; then
        log_msg "VServer $VAR_B backup $VAR_C could not be found"
    else
        vzctl stop "$VAR_B" 2>/dev/null
        umount -l "/var/lib/vz/root/$VAR_B" 2>/dev/null
        sleep 5
        vzctl destroy "$VAR_B"
        sleep 10
        vzrestore "$BACKUP_PATH" "$VAR_B"
        vzctl start "$VAR_B"
        runcheck=$(vzctl status "$VAR_B" | grep -i running)
        [ -n "$runcheck" ] && log_msg "VServer $VAR_B restored from $VAR_C" || log_msg "Restore of $VAR_B from $VAR_C failed"
    fi
fi

# ----------------------------
# SERVICE CONTROL
# ----------------------------
if [ "$VAR_A" = "service" ]; then
    if vzctl status "$VAR_B" | grep -iq running; then
        if vzctl exec "$VAR_B" [ -x /etc/init.d/"$VAR_C" ]; then
            vzctl exec "$VAR_B" /etc/init.d/"$VAR_C" "$VAR_D"
            echo "ID1"
        fi
    fi
fi

# ----------------------------
# CONFIG CHANGE (Tun/Tap, IP, Settings)
# ----------------------------
if [ "$VAR_A" = "changerun" ]; then
    if [ -f /etc/"$vzconf"/"$VAR_B".conf ]; then
        if [ "$VAR_F" = "1" ]; then
            vzctl set "$VAR_B" --devnodes net/tun:rw --save
            vzctl set "$VAR_B" --devices c:10:200:rw --save
            vzctl set "$VAR_B" --capability net_admin:on --save
            vzctl exec "$VAR_B" mkdir -p /dev/net
            vzctl exec "$VAR_B" mknod /dev/net/tun c 10 200
            vzctl exec "$VAR_B" chmod 600 /dev/net/tun
            log_msg "VServer $VAR_B Tun & Tap activated"
        else
            log_msg "VServer $VAR_B Tun & Tap not activated"
        fi

        [ -f "$LOGP/cache/vsettings_${VAR_B}.lst" ] && while read -r LINE; do
            [ -n "$LINE" ] && vzctl set "$VAR_B" $LINE --save
        done < "$LOGP/cache/vsettings_${VAR_B}.lst" && rm -f "$LOGP/cache/vsettings_${VAR_B}.lst"

        log_msg "VServer $VAR_B settings applied"
    else
        log_msg "VServer $VAR_B config not found"
    fi
fi
# ----------------------------
# IP ADDITION
# ----------------------------
if [ "$VAR_A" = "ipadd" ]; then
    if [ -f /etc/"$vzconf"/"$VAR_B".conf ]; then
        if [ -f "$LOGP/cache/vipadd_${VAR_B}.lst" ]; then
            while read -r LINE; do
                [ -n "$LINE" ] && vzctl set "$VAR_B" --ipadd "$LINE" --save
            done < "$LOGP/cache/vipadd_${VAR_B}.lst"
            rm "$LOGP/cache/vipadd_${VAR_B}.lst"
        fi
        log_msg "VServer $VAR_B IPs added"
    else
        log_msg "IP add failed: config not found for $VAR_B"
    fi
fi

# ----------------------------
# IP REMOVAL
# ----------------------------
if [ "$VAR_A" = "ipdel" ]; then
    if [ -f /etc/"$vzconf"/"$VAR_B".conf ]; then
        if [ -f "$LOGP/cache/vipdel_${VAR_B}.lst" ]; then
            while read -r LINE; do
                [ -n "$LINE" ] && vzctl set "$VAR_B" --ipdel "$LINE" --save
            done < "$LOGP/cache/vipdel_${VAR_B}.lst"
            rm "$LOGP/cache/vipdel_${VAR_B}.lst"
        fi
        log_msg "VServer $VAR_B IPs removed"
    else
        log_msg "IP removal failed: config not found for $VAR_B"
    fi
fi

# ----------------------------
# STORE SETTINGS FOR LATER
# ----------------------------
if [ "$VAR_A" = "settings" ]; then
    echo "$VAR_C" > "$LOGP/cache/vsettings_${VAR_B}.lst"
    [ -n "$VAR_D" ] && echo "$VAR_D" > "$LOGP/cache/vipadd_${VAR_B}.lst"
    [ -n "$VAR_E" ] && echo "$VAR_E" > "$LOGP/cache/vipdel_${VAR_B}.lst"
fi

# ----------------------------
# CHANGE ROOT PASSWORD
# ----------------------------
if [ "$VAR_A" = "rootpw" ]; then
    if ! vzctl status "$VAR_B" | grep -iq running; then
        vzctl start "$VAR_B"
    fi
    vzctl set "$VAR_B" --userpasswd root:"$VAR_C"
    echo "ID1"
fi

# ----------------------------
# VSERVER ONLINE STATUS
# ----------------------------
if [ "$VAR_A" = "online" ]; then
    vzctl status "$VAR_B" | grep -iq running && echo "ID1" || echo "ID2"
fi

# ----------------------------
# LIST SERVICES
# ----------------------------
if [ "$VAR_A" = "list" ]; then
    if vzctl status "$VAR_B" | grep -iq running; then
        vzctl exec "$VAR_B" ls -l /etc/init.d | awk '{print $1"%TD%"$NF"%TEND%"}'
    fi
fi

# ----------------------------
# LIST PROCESSES
# ----------------------------
if [ "$VAR_A" = "psaux" ]; then
    if vzctl status "$VAR_B" | grep -iq running; then
        vzctl exec "$VAR_B" ps aux --sort pid | grep -vE "ps aux|awk|tekbase|perl" | awk '{
            printf($1"%TD%"$2"%TD%"$3"%TD%"$4"%TD%")
            for(i=11;i<=NF;i++) printf("%s ", $i)
            print "%TEND%"
        }'
    fi
fi

# ----------------------------
# KILL SPECIFIC PROCESS
# ----------------------------
if [ "$VAR_A" = "process" ]; then
    vzctl exec "$VAR_B" kill -9 "$VAR_C"
    check=$(vzctl exec "$VAR_B" ps -p "$VAR_C" | grep -v "PID TTY")
    if [ -z "$check" ]; then
        log_msg "VServer $VAR_B process $VAR_C was killed"
        echo "ID1"
    else
        log_msg "VServer $VAR_B process $VAR_C could not be killed"
        echo "ID2"
    fi
fi
# ----------------------------
# CLEAN EXIT
# ----------------------------
exit 0