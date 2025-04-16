#!/bin/bash

# TekLabs TekBase - Modernized Game Server Management
# Maintainer: Christian Frankenstein
# Supports: Screen + Docker, Symlinks for base images
# Requirements: Centralized logging, modular commands

VAR_A="$1"   # Action
VAR_B="$2"   # User
VAR_C="$3"   # Server ID
VAR_D="$4"   # Game name (e.g. css)
VAR_E="$5"   # Start command or docker image name
VAR_F="$6"   # Optional: map or command
VAR_G="$7"   # Optional: CPU core (taskset)

# Directories
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"
RESTART_PATH="$LOGP/restart"
STARTSCRIPT_PATH="$LOGP/startscripte"
BASE_IMAGE_DIR="/home/server/$VAR_D"
CUSTOMER_DIR="/home/$VAR_B/server/${VAR_D}_$VAR_C"

mkdir -p "$LOGP/logs" "$RESTART_PATH" "$STARTSCRIPT_PATH"
chmod -R 0777 "$LOGP/logs" "$RESTART_PATH" "$STARTSCRIPT_PATH"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

# Check for Docker mode
is_docker() {
    [[ "$VAR_E" == docker-* ]]
}

docker_image_name() {
    echo "${VAR_E#docker-}"
}

########################
# START SERVER
########################
if [ "$VAR_A" = "start" ]; then
    restart_file="$RESTART_PATH/$VAR_B-server-$VAR_C"
    rm -f "$restart_file"

    # Create restart script
    cat <<EOF > "$restart_file"
#!/bin/bash
check=\$(ps aux | grep -v grep | grep -i screen | grep -i "server$VAR_C-X")
if [ -z "\$check" ]; then
    cd "$LOGP"
    sudo -u "$VAR_B" ./games.sh start "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G"
fi
exit 0
EOF
    chmod 0755 "$restart_file"

    # Setup game directory if not exists
    if [ ! -d "$CUSTOMER_DIR" ]; then
        mkdir -p "$CUSTOMER_DIR"
        chmod 755 "$CUSTOMER_DIR"

        # Symlink base image
        if [ -d "$BASE_IMAGE_DIR" ]; then
            ln -s "$BASE_IMAGE_DIR"/* "$CUSTOMER_DIR/"
        else
            log_msg "Base image missing: $BASE_IMAGE_DIR"
            echo "ID2"
            exit 1
        fi
    fi

    cd "$CUSTOMER_DIR" || exit 1
    screen -wipe

    if is_docker; then
        dockername="gsrv_${VAR_B}_${VAR_C}_${VAR_D}"
        docker run -d --rm --name "$dockername" \
            -v "$CUSTOMER_DIR":/data \
            -p "$((27000 + VAR_C))":27015/udp \
            "$(docker_image_name)"
        sleep 2
        if docker ps | grep -q "$dockername"; then
            log_msg "Docker-based game server '$dockername' started"
            echo "ID1"
        else
            log_msg "Docker failed to start game server '$dockername'"
            echo "ID2"
        fi
    else
        screenname="server$VAR_C-X"
        if [ "$VAR_G" != "" ]; then
            screen -A -m -d -L -S "$screenname" taskset -c "$VAR_G" $VAR_E
        else
            screen -A -m -d -L -S "$screenname" $VAR_E
        fi
        sleep 2
        if pgrep -f "screen.*$screenname" > /dev/null; then
            log_msg "Game server $CUSTOMER_DIR started ($VAR_E)"
            echo "ID1"
        else
            log_msg "Failed to start server $CUSTOMER_DIR ($VAR_E)"
            echo "ID2"
        fi
    fi
fi

########################
# STOP SERVER
########################
if [ "$VAR_A" = "stop" ]; then
    rm -f "$RESTART_PATH/$VAR_B-server-$VAR_C"

    if is_docker; then
        dockername="gsrv_${VAR_B}_${VAR_C}_${VAR_D}"
        docker stop "$dockername"
        sleep 1
        if ! docker ps | grep -q "$dockername"; then
            log_msg "Docker server '$dockername' stopped"
            echo "ID1"
        else
            log_msg "Docker server '$dockername' failed to stop"
            echo "ID2"
        fi
    else
        pkill -f "screen.*server$VAR_C-X"
        screen -wipe
        if ! pgrep -f "screen.*server$VAR_C-X" > /dev/null; then
            log_msg "Game server $CUSTOMER_DIR stopped"
            echo "ID1"
        else
            log_msg "Failed to stop $CUSTOMER_DIR"
            echo "ID2"
        fi
    fi
fi

########################
# SERVER STATUS
########################
if [ "$VAR_A" = "status" ]; then
    if is_docker; then
        dockername="gsrv_${VAR_B}_${VAR_C}_${VAR_D}"
        if docker ps | grep -q "$dockername"; then
            echo "ID2"
        else
            echo "ID1"
        fi
    else
        if pgrep -f "screen.*server$VAR_C-X" > /dev/null; then
            echo "ID2"
        else
            echo "ID1"
        fi
    fi
fi
########################
# CREATE BACKUP
########################
if [ "$VAR_A" = "create" ]; then
    BACKUP_FILE="/home/$VAR_B/server/$VAR_D.tar"

    # Avoid active server during backup
    if pgrep -f "screen.*server$VAR_C-X" > /dev/null || docker ps | grep -q "gsrv_${VAR_B}_${VAR_C}_${VAR_D}"; then
        log_msg "Backup failed: server $VAR_D is running"
        echo "ID2"
    else
        cd "/home/$VAR_B/server"
        tar -cf "$VAR_D.tar" "$VAR_D"
        if [ -f "$BACKUP_FILE" ]; then
            log_msg "Backup created for $VAR_D"
            echo "ID1"
        else
            log_msg "Backup failed for $VAR_D"
            echo "ID2"
        fi
    fi
fi

########################
# EXTRACT BACKUP
########################
if [ "$VAR_A" = "extract" ]; then
    BACKUP_FILE="/home/$VAR_B/server/$VAR_D.tar"
    if [ ! -f "$BACKUP_FILE" ]; then
        log_msg "Extract failed: no backup found for $VAR_D"
        echo "ID2"
    else
        cd "/home/$VAR_B/server"
        rm -rf "$VAR_D"
        tar -xf "$VAR_D.tar"
        if [ -d "$VAR_D" ]; then
            log_msg "Backup extracted for $VAR_D"
            echo "ID1"
        else
            log_msg "Failed to extract backup for $VAR_D"
            echo "ID2"
        fi
    fi
fi

########################
# UPDATE SERVER
########################
if [ "$VAR_A" = "update" ]; then
    if pgrep -f "screen.*b$VAR_B$VAR_D-X" > /dev/null || docker ps | grep -q "gsrv_${VAR_B}_${VAR_C}_${VAR_D}"; then
        log_msg "Update blocked: server $VAR_D is running"
        echo "ID2"
    else
        screen -A -m -d -S "b$VAR_B$VAR_D-X" ./games.sh updaterun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E"
        sleep 2
        if pgrep -f "screen.*b$VAR_B$VAR_D-X" > /dev/null; then
            echo "ID1"
        else
            echo "ID2"
        fi
    fi
fi

if [ "$VAR_A" = "updaterun" ]; then
    cd "/home/$VAR_B/server/$VAR_D" || exit 1
    IFS=$'\n'
    for cmd in $(echo "$VAR_E" | tr ';' '\n'); do
        if [ -n "$cmd" ]; then
            eval "$cmd"
        fi
    done
    unset IFS
    log_msg "Update completed for $VAR_D"
    echo "ID1"
fi
########################
# MAPLIST
########################
if [ "$VAR_A" = "maplist" ]; then
    cd "/home/$VAR_B/server/$VAR_D/$VAR_E" || exit 1
    if [ "$VAR_G" = "yes" ]; then
        find . -name "*.$VAR_F" -printf "%f\n" | while read -r map; do
            echo "$map%TEND%"
        done
    else
        find . -name "*.$VAR_F" | while read -r map; do
            echo "$map%TEND%"
        done
    fi
fi

########################
# INSTALL ADDON / MOD
########################
if [ "$VAR_A" = "install" ]; then
    screen -A -m -d -S "ma$VAR_B$VAR_E-X" ./games.sh installrun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G"
    sleep 2
    if pgrep -f "screen.*ma$VAR_B$VAR_E-X" > /dev/null; then
        echo "ID1"
    else
        echo "ID2"
    fi
fi

if [ "$VAR_A" = "installrun" ]; then
    cd "/home/$VAR_B/server/$VAR_D" || exit 1
    wget "$VAR_G/$VAR_F/$VAR_E.tar" -O "$VAR_E.tar"
    if [ -f "$VAR_E.tar" ]; then
        tar -xf "$VAR_E.tar" && rm -f "$VAR_E.tar"
        [ -f "$VAR_E-install.sh" ] && chmod +x "$VAR_E-install.sh" && ./"$VAR_E-install.sh" && rm -f "$VAR_E-install.sh"
        log_msg "Addon/Mod $VAR_E installed"
    else
        log_msg "Addon/Mod $VAR_E.tar failed to download"
    fi
fi

########################
# REMOVE ADDON / MOD
########################
if [ "$VAR_A" = "remove" ]; then
    screen -A -m -d -S "rm$VAR_B$VAR_E-X" ./games.sh removerun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G"
    sleep 2
    if pgrep -f "screen.*rm$VAR_B$VAR_E-X" > /dev/null; then
        echo "ID1"
    else
        echo "ID2"
    fi
fi

if [ "$VAR_A" = "removerun" ]; then
    cd "/home/$VAR_B/server/$VAR_D" || exit 1
    wget "$VAR_G/$VAR_F/$VAR_E.lst" -O "$VAR_E.lst"
    if [ -f "$VAR_E.lst" ]; then
        while read -r FILE; do
            rm -rf "$FILE"
        done < "$VAR_E.lst"
        rm -f "$VAR_E.lst"
        log_msg "Addon/Mod $VAR_E file list removed"
    else
        log_msg "File list $VAR_E.lst not found"
    fi

    wget "$VAR_G/$VAR_F/$VAR_E-uninstall.sh" -O "$VAR_E-uninstall.sh"
    if [ -f "$VAR_E-uninstall.sh" ]; then
        chmod +x "$VAR_E-uninstall.sh"
        ./"$VAR_E-uninstall.sh"
        rm -f "$VAR_E-uninstall.sh"
        log_msg "Addon/Mod $VAR_E uninstalled via script"
    else
        log_msg "Uninstall script $VAR_E-uninstall.sh not found"
    fi
fi

########################
# SCREEN COMMAND SEND
########################
if [ "$VAR_A" = "screensend" ]; then
    if [ -n "$VAR_F" ]; then
        screen -S "server$VAR_C-X" -p 0 -X stuff "$VAR_F"
        screen -S "server$VAR_C-X" -p 0 -X stuff $'\n'
    fi
    cat "/home/$VAR_B/server/$VAR_D/$VAR_E"
fi

########################
# TOTAL PROTECT RESTORE
########################
if [ "$VAR_A" = "totalprotect" ]; then
    if ! netstat -tulpn 2>/dev/null | awk '{print $4}' | grep -q "$VAR_E"; then
        CACHE_PATH="$LOGP/cache/${VAR_B}${VAR_D}"
        if [ -d "$CACHE_PATH" ]; then
            filecount=$(find "$CACHE_PATH" | wc -l)
            if [ "$filecount" -gt 1 ]; then
                cp -r "$CACHE_PATH"/* "/home/$VAR_B/server/$VAR_D"
                echo "ID1"
            else
                echo "ID2"
            fi
        else
            echo "ID2"
        fi
    else
        echo "ID2"
    fi
fi
########################
# SCREEN FILE CONTENT
########################
if [ "$VAR_A" = "screen" ]; then
    cat "/home/$VAR_B/server/$VAR_D/$VAR_E"
fi

########################
# CHECK BACKUP EXISTENCE
########################
if [ "$VAR_A" = "check" ]; then
    if ! pgrep -f "screen.*b$VAR_B$VAR_D-X" > /dev/null; then
        if [ -f "/home/$VAR_B/server/$VAR_D.tar" ]; then
            echo "ID1"
        else
            echo "ID2"
        fi
    else
        echo "ID2"
    fi
fi

########################
# SERVER STATUS CHECK
########################
if [ "$VAR_A" = "status" ]; then
    if pgrep -f "screen.*$VAR_E$VAR_B$VAR_D-X" > /dev/null; then
        echo "ID2"
    else
        echo "ID1"
    fi
fi

exit 0