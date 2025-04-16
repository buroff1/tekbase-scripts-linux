#!/bin/bash

# TekLabs TekBase - Web and MySQL Control Script
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

VAR_A="$1"
VAR_B="$2"
VAR_C="$3"
VAR_D="$4"
VAR_E="$5"

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

# -----------------------
# Create MySQL Database
# -----------------------
if [ "$VAR_A" = "dbcreate" ]; then
    if [ -f /etc/mysql/settings.ini ]; then
        mysqlpwd=$(grep -i password /etc/mysql/settings.ini | awk '{print $2}')
        mysqlusr=$(grep -i login /etc/mysql/settings.ini | awk '{print $2}')

        SQL="CREATE DATABASE IF NOT EXISTS $VAR_C;
             CREATE USER '$VAR_D'@'%' IDENTIFIED BY '$VAR_E';
             GRANT ALL PRIVILEGES ON $VAR_C.* TO '$VAR_D'@'%';
             FLUSH PRIVILEGES;"

        mysql --user="$mysqlusr" --password="$mysqlpwd" -e "$SQL"
        echo "ID1"
    else
        echo "ID2"
    fi
fi

# -----------------------
# Delete MySQL Database
# -----------------------
if [ "$VAR_A" = "dbdelete" ]; then
    if [ -f /etc/mysql/settings.ini ]; then
        mysqlpwd=$(grep -i password /etc/mysql/settings.ini | awk '{print $2}')
        mysqlusr=$(grep -i login /etc/mysql/settings.ini | awk '{print $2}')

        SQL="DROP DATABASE IF EXISTS $VAR_C;
             DROP USER IF EXISTS '$VAR_D'@'%';
             FLUSH PRIVILEGES;"

        mysql --user="$mysqlusr" --password="$mysqlpwd" -e "$SQL"
        echo "ID1"
    else
        echo "ID2"
    fi
fi

# -----------------------
# Rename MySQL Database
# -----------------------
if [ "$VAR_A" = "dbrename" ]; then
    if [ -f /etc/mysql/settings.ini ]; then
        mysqlpwd=$(grep -i password /etc/mysql/settings.ini | awk '{print $2}')
        mysqlusr=$(grep -i login /etc/mysql/settings.ini | awk '{print $2}')

        mysqldump --user="$mysqlusr" --password="$mysqlpwd" "$VAR_C" > "$VAR_C.sql"
        mysql --user="$mysqlusr" --password="$mysqlpwd" -e "CREATE DATABASE IF NOT EXISTS $VAR_D"
        mysql --user="$mysqlusr" --password="$mysqlpwd" "$VAR_D" < "$VAR_C.sql"

        SQL="GRANT ALL PRIVILEGES ON $VAR_D.* TO '$VAR_E'@'%';
             REVOKE ALL PRIVILEGES ON $VAR_C.* FROM '$VAR_E'@'%';
             DROP DATABASE $VAR_C;
             FLUSH PRIVILEGES;"

        mysql --user="$mysqlusr" --password="$mysqlpwd" -e "$SQL"
        rm -f "$VAR_C.sql"
        echo "ID1"
    else
        echo "ID2"
    fi
fi

# -----------------------
# Change MySQL Password
# -----------------------
if [ "$VAR_A" = "dbpasswd" ]; then
    if [ -f /etc/mysql/settings.ini ]; then
        mysqlpwd=$(grep -i password /etc/mysql/settings.ini | awk '{print $2}')
        mysqlusr=$(grep -i login /etc/mysql/settings.ini | awk '{print $2}')

        SQL="ALTER USER '$VAR_C'@'%' IDENTIFIED BY '$VAR_D';
             FLUSH PRIVILEGES;"

        mysql --user="$mysqlusr" --password="$mysqlpwd" -e "$SQL"
        echo "ID1"
    else
        echo "ID2"
    fi
fi

# -----------------------
# Apache VHost Management
# -----------------------
if [ "$VAR_A" = "activate" ]; then
    if [ -f "$LOGP/includes/sites/$VAR_B.conf" ]; then
        cp "$LOGP/includes/sites/$VAR_B.conf" /etc/apache2/sites-enabled/
        echo "ID1"
    else
        echo "ID2"
    fi
fi

if [ "$VAR_A" = "deactivate" ]; then
    if [ -f "/etc/apache2/sites-enabled/$VAR_B.conf" ]; then
        rm "/etc/apache2/sites-enabled/$VAR_B.conf"
        echo "ID1"
    else
        echo "ID2"
    fi
fi

if [ "$VAR_A" = "delete" ]; then
    removed="no"
    [ -f "$LOGP/includes/sites/$VAR_B.conf" ] && rm "$LOGP/includes/sites/$VAR_B.conf" && removed="yes"
    [ -f "/etc/apache2/sites-enabled/$VAR_B.conf" ] && rm "/etc/apache2/sites-enabled/$VAR_B.conf" && removed="yes"

    [ "$removed" = "yes" ] && echo "ID1" || echo "ID2"
fi

if [ "$VAR_A" = "apache" ]; then
    systemctl reload apache2 2>/dev/null || /etc/init.d/apache2 reload
    echo "ID1"
fi

exit 0
