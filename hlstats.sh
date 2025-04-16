#!/bin/bash

# TekLabs TekBase - HLStats Control Script (Screen + Docker)
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

VAR_A="$1"
VAR_B="$2"  # User OR docker container name with prefix
VAR_C="$3"  # Port / Screen name
VAR_D="$4"  # Port
VAR_E="$5"  # Admin password (or other)

# Unified logging
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

is_docker() {
    [[ "$VAR_B" == docker-* ]]
}

get_container_name() {
    echo "${VAR_B#docker-}"
}

# Load credentials and paths
mysqlpwd=$(grep -i password hlstats.ini | awk '{print $2}')
mysqlusr=$(grep -i login hlstats.ini | awk '{print $2}')
wwwpath=$(grep -i www hlstats.ini | awk '{print $2}')

[ -z "$VAR_A" ] && ./tekbase && exit 0

case "$VAR_A" in
    1) # INSTALL
        if is_docker; then
            container_name=$(get_container_name)
            docker run -d --name "$container_name" \
                -p "$VAR_D:$VAR_D" \
                -v "/home/skripte/hlstats:/hlstats" \
                teklab/hlstats
            log_msg "Docker HLStats container $container_name created and running"
            echo "ID1"
            exit 0
        fi

        [ -d "/home/$VAR_B" ] && rm -rf "/home/$VAR_B"
        mkdir "/home/$VAR_B"
        cp -r /home/skripte/hlstats/* "/home/$VAR_B"

        cd "/home/$VAR_B/sql" || exit 1
        SQL="CREATE DATABASE IF NOT EXISTS $VAR_B;
             GRANT ALL PRIVILEGES ON $VAR_B.* TO '$VAR_B'@'localhost' IDENTIFIED BY '$VAR_C';
             FLUSH PRIVILEGES;"
        mysql --user="$mysqlusr" --password="$mysqlpwd" -e "$SQL"
        mysql --user="$VAR_B" --password="$VAR_C" "$VAR_B" < install.sql
        mysql --user="$VAR_B" --password="$VAR_C" "$VAR_B" -e \
            "UPDATE hlstats_Users SET password='$VAR_E' WHERE username='admin' OR acclevel='100'"

        cd ../scripts || exit 1
        sed -e "/DBUsername/Ic\DBUsername \"$VAR_B\"" hlstats.conf > conf1
        sed -e "/DBPassword/Ic\DBPassword \"$VAR_C\"" conf1 > conf2
        sed -e "/DBName/Ic\DBName \"$VAR_B\"" conf2 > conf3
        sed -e "/Port/Ic\Port $VAR_D" conf3 > hlstats.conf
        rm -f conf1 conf2 conf3

        echo "$VAR_C" > ../passwd.ini
        cd ../web || exit 1
        rm -rf updater
        sed -e "/define(\"DB_NAME/Ic\define(\"DB_NAME\", \"$VAR_B\");" config.php > temp1
        sed -e "/define(\"DB_USER/Ic\define(\"DB_USER\", \"$VAR_B\");" temp1 > temp2
        sed -e "/define(\"DB_PASS/Ic\define(\"DB_PASS\", \"$VAR_C\");" temp2 > config.php
        rm -f temp1 temp2

        cp -r web "$wwwpath/$VAR_B"
        useradd -g users -p "$(perl -e 'print crypt("'"$VAR_C"'","Sa")')" -s /bin/bash -m "$VAR_B" -d "/var/www/$VAR_B"
        chown -R "$VAR_B:users" "/var/www/$VAR_B"

        cd "/home/$VAR_B/scripts" || exit 1
        ./run_hlstats start 1 "$VAR_D" &
        log_msg "Native HLStats installed and started for user $VAR_B on port $VAR_D"
        echo "ID1"
        ;;

    2) # RESTART
        if is_docker; then
            docker restart "$(get_container_name)"
            echo "ID1"
        else
            cd "/home/$VAR_B/scripts" || exit 1
            ./run_hlstats stop "$VAR_C" &
            rm -rf logs
            ./run_hlstats start 1 "$VAR_C" &
            log_msg "HLStats restarted for user $VAR_B"
            echo "ID1"
        fi
        ;;

    3) # STOP
        if is_docker; then
            docker stop "$(get_container_name)"
            log_msg "HLStats docker container $(get_container_name) stopped"
        else
            cd "/home/$VAR_B/scripts" || exit 1
            ./run_hlstats stop "$VAR_C" &
            log_msg "HLStats stopped for user $VAR_B"
        fi
        echo "ID1"
        ;;

    4) # CHANGE FTP PASSWORD
        usermod -p "$(perl -e 'print crypt("'"$VAR_C"'","Sa")')" "$VAR_B"
        log_msg "FTP password updated for $VAR_B"
        echo "ID1"
        ;;

    5) # CHANGE HLSTATS ADMIN PASSWORD
        passwd=$(cat "/home/$VAR_B/passwd.ini")
        mysql --user="$VAR_B" --password="$passwd" "$VAR_B" -e \
            "UPDATE hlstats_Users SET password='$VAR_C' WHERE username='admin' OR acclevel='100'"
        log_msg "HLStats admin password changed for $VAR_B"
        echo "ID1"
        ;;

    6) # DELETE HLSTATS
        if is_docker; then
            docker stop "$(get_container_name)"
            docker rm "$(get_container_name)"
            log_msg "HLStats docker container $(get_container_name) deleted"
        else
            cd "/home/$VAR_B/scripts" || exit 1
            ./run_hlstats stop "$VAR_C" &
            mysql --user="$mysqlusr" --password="$mysqlpwd" -e "DROP USER '$VAR_B'@'localhost';"
            mysql --user="$mysqlusr" --password="$mysqlpwd" -e "DROP DATABASE $VAR_B;"
            rm -rf "$wwwpath/$VAR_B" "/home/$VAR_B"
            log_msg "HLStats native installation for $VAR_B deleted"
        fi
        echo "ID1"
        ;;

    7) # RUN HLSTATS AWARDS
        for LINE in $(find /home -maxdepth 1 -type d -printf "%f\n"); do
            if echo "$LINE" | grep -iq "^hls_"; then
                cd "/home/$LINE/scripts" && ./hlstats-awards.pl
            fi
        done
        log_msg "HLStats awards run on all matching folders"
        ;;
esac

exit 0