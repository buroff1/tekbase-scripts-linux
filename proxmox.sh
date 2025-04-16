#!/bin/bash

# TekLabs TekBase - Proxmox VM Management Script (KVM/LXC)
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

VAR_A="$1"  # Action: install, delete, statuscheck, installrun, deleterun
VAR_B="$2"  # VM ID
VAR_C="$3"  # Type: kvm or lxc
VAR_D="$4"  # Image name (without extension)
VAR_E="$5"  # Install/Delete trigger
VAR_F="$6"  # Config file path (for create)
VAR_G="$7"  # Remote image URL
VAR_H="$8"  # Reserved
VAR_I="$9"  # Reserved

# Logging setup
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGC=$(date +"%Y_%m-%H_%M_%S")
LOGFILE="$LOGP/logs/$LOGF.txt"
mkdir -p "$LOGP/logs"
chmod 0777 "$LOGP/logs"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

# Folder & Extension Setup
case "$VAR_C" in
    kvm)
        pvefolder="/etc/pve/qemu-server"
        pveimagefolder="/var/lib/vz/template/iso"
        pveext="iso"
        ;;
    lxc)
        pvefolder="/etc/pve/lxc"
        pveimagefolder="/var/lib/vz/template/cache"
        pveext="tar.gz"
        ;;
    *)
        log_msg "❌ Unknown VM type: $VAR_C"
        exit 1
        ;;
esac

# Default to TekBase UI
[ -z "$VAR_A" ] && ./tekbase && exit 0

# --- Install VM ---
if [ "$VAR_A" = "install" ]; then
    screen_name="v${VAR_A}${VAR_B}-X"
    if ! pgrep -f "screen.*$screen_name" > /dev/null; then
        screen -A -m -d -S "$screen_name" "$0" installrun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G" "$VAR_H" "$VAR_I"
    fi

    sleep 2
    if ! pgrep -f "screen.*$screen_name" > /dev/null; then
        if [ "$VAR_C" = "kvm" ]; then
            qm status "$VAR_B" | grep -iq running && echo "ID3" || echo "ID2"
        else
            pct list | grep -i "$VAR_B" | grep -vq stopped && echo "ID3" || echo "ID2"
        fi
    else
        echo "ID1"
    fi
fi

# --- Run Install Process ---
if [ "$VAR_A" = "installrun" ]; then
    if [ "$VAR_E" = "delete" ]; then
        if [ "$VAR_C" = "kvm" ]; then
            qm stop "$VAR_B" 2>/dev/null
            sleep 5
            qm destroy "$VAR_B"
        else
            pct stop "$VAR_B" 2>/dev/null
            sleep 5
            pct destroy "$VAR_B"
        fi

        sleep 5
        if [ ! -f "$pvefolder/$VAR_B.conf" ]; then
            log_msg "🗑️ $VAR_C VM $VAR_B was deleted"
        else
            log_msg "⚠️ $VAR_C VM $VAR_B could not be deleted"
        fi
        exit 0
    fi

    cd "$pveimagefolder" || exit 1

    # Download image if missing
    if [ ! -f "$VAR_D.$pveext" ]; then
        mkdir -p "$LOGC" && cd "$LOGC"
        wget "$VAR_G/$VAR_D.$pveext"
        mv "$VAR_D.$pveext" "$pveimagefolder/"
        cd .. && rm -rf "$LOGC"
    else
        wget -q -O "$VAR_C-$VAR_D.md5" "$VAR_G/$VAR_D.$pveext.md5"
        if [ -f "$VAR_C-$VAR_D.md5" ]; then
            dowmd5=$(awk '{print $1}' "$VAR_C-$VAR_D.md5")
            chkmd5=$(md5sum "$VAR_D.$pveext" | awk '{print $1}')
            if [ "$dowmd5" != "$chkmd5" ]; then
                mkdir -p "$LOGC" && cd "$LOGC"
                wget "$VAR_G/$VAR_D.$pveext"
                mv "$VAR_D.$pveext" "$pveimagefolder/"
                cd .. && rm -rf "$LOGC"
            fi
            rm -f "$VAR_C-$VAR_D.md5"
        fi
    fi

    if [ ! -f "$VAR_D.$pveext" ]; then
        log_msg "❌ $pvetype image $VAR_D.$pveext could not be downloaded"
        exit 1
    else
        log_msg "✅ $pvetype image $VAR_D.$pveext downloaded"
    fi

    # Create the VM
    if [ "$VAR_C" = "kvm" ]; then
        qm create "$VAR_B" $VAR_F
    else
        pct create "$VAR_B" $VAR_F
    fi

    # Confirm creation
    if [ -f "$pvefolder/$VAR_B.conf" ]; then
        log_msg "✅ $pvetype VM $VAR_B created successfully"
    else
        log_msg "❌ $pvetype VM $VAR_B failed to create"
    fi
fi

# --- Delete VM via vserver.sh call ---
if [ "$VAR_A" = "delete" ]; then
    screen_name="v${VAR_A}${VAR_B}-X"
    if ! pgrep -f "screen.*$screen_name" > /dev/null; then
        screen -A -m -d -S "$screen_name" ./vserver deleterun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G" "$VAR_H" "$VAR_I"
    fi

    sleep 2
    if ! pgrep -f "screen.*$screen_name" > /dev/null; then
        [ ! -f "$pvefolder/$VAR_B.conf" ] && echo "ID2" || echo "ID3"
    else
        echo "ID1"
    fi
fi

# --- Status Check ---
if [ "$VAR_A" = "statuscheck" ]; then
    if ! pgrep -f "pbackup$VAR_B-X|prestore$VAR_B-X" > /dev/null; then
        echo "ID1"
    else
        echo "ID2"
    fi
fi

# --- Deleterun Stub (from vserver.sh) ---
if [ "$VAR_A" = "deleterun" ]; then
    log_msg "⚙️ Called deleterun for $VAR_B ($VAR_C) — implement logic if needed."
    exit 0
fi

exit 0