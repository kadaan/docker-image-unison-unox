#!/usr/bin/env bash
set -e

if [ "$1" == 'supervisord' ]; then

    # Increase the maximum watches for inotify for very large repositories to be watched
    # Needs the privilegied docker option
    [ ! -z $MAX_INOTIFY_WATCHES ] && echo fs.inotify.max_user_watches=$MAX_INOTIFY_WATCHES | tee -a /etc/sysctl.conf && sysctl -p || true

    [ -z $UNISON_DIR ] && export UNISON_DIR="/data"

    [ ! -d $UNISON_DIR ] && mkdir -p $UNISON_DIR

    [ -z $UNISON_OWNER ] && export UNISON_OWNER="unison"

    [ -z $UNISON_GROUP ] && export UNISON_GROUP="unison"

    export UNISON_OWNER_HOMEDIR=/home/$UNISON_OWNER

    if [ ! -z $UNISON_OWNER_GID ]; then

        # If gid doesn't exist on the system
        if ! cut -d: -f3 /etc/group | grep -q $UNISON_OWNER_GID; then
            echo "no group has gid $UNISON_OWNER_GID"

            # If group doesn't exist on the system
            if ! cut -d: -f1 /etc/group | grep -q $UNISON_GROUP; then
                groupadd -g $UNISON_OWNER_GID $UNISON_GROUP
            else
                groupmod -g $UNISON_OWNER_GID $UNISON_GROUP
            fi
        fi
    else
        if ! id $UNISON_GROUP; then
            echo "adding group $UNISON_GROUP".
            groupadd $UNISON_GROUP
        else
            echo "group $UNISON_GROUP already exists".
        fi
        UNISON_OWNER_GID=$(awk -F: "/$UNISON_GROUP:/{print \$3}" /etc/group)
    fi

    if [ ! -z $UNISON_OWNER_UID ]; then

        # If uid doesn't exist on the system
        if ! cut -d: -f3 /etc/passwd | grep -q $UNISON_OWNER_UID; then
            echo "no user has uid $UNISON_OWNER_UID"

            # If user doesn't exist on the system
            if ! cut -d: -f1 /etc/passwd | grep -q $UNISON_OWNER; then
                useradd -u $UNISON_OWNER_UID -g $UNISON_OWNER_GID $UNISON_OWNER -m
            else
                usermod -u $UNISON_OWNER_UID -g $UNISON_OWNER_GID $UNISON_OWNER
            fi
        else
            echo "user with uid $UNISON_OWNER_UID already exist"
            existing_user_with_uid=$(awk -v val=$UNISON_OWNER_UID -F ":" '$3==val{print $1}' /etc/passwd)
            mkdir -p /home/$UNISON_OWNER
            usermod -g $UNISON_OWNER_GID --home /home/$UNISON_OWNER --login $UNISON_OWNER $existing_user_with_uid
            chown -R $UNISON_OWNER /home/$UNISON_OWNER
            chgrp -R $UNISON_GROUP /home/$UNISON_OWNER
        fi
    else
        if ! id $UNISON_OWNER; then
            echo "adding user $UNISON_OWNER".
            useradd -m $UNISON_OWNER -g $UNISON_OWNER_GID
        else
            echo "user $UNISON_OWNER already exists".
            usermod -g $UNISON_OWNER_GID $UNISON_OWNER
        fi
    fi

    chown -R $UNISON_OWNER $UNISON_DIR
    chgrp -R $UNISON_GROUP $UNISON_DIR

    # see https://wiki.alpinelinux.org/wiki/Setting_the_timezone
    if [ -n ${TZ} ] && [ -f /usr/share/zoneinfo/${TZ} ]; then
        ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
        echo ${TZ} > /etc/timezone
    fi

    # Check if a script is available in /docker-entrypoint.d and source it
    for f in /docker-entrypoint.d/*; do
        case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
    done
fi

exec "$@"
