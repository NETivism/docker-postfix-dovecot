#!/bin/sh
docker pull jimyhuang/docker-postfix-dovecot
docker stop dovecot
docker rm dovecot
docker run \
    -dit --name dovecot \
    -p 993:993 \
    -p 587:587 \
    -p 25:25 \
    -p 465:465 \
    -e MAILNAME="static.jimmyhub.net" \
    -e MAILADDR="testa@static.jimmyhub.net;testb@static.jimmyhub.net" \
    -v /etc/postfix \
    -v /etc/ssl \
    -v /var/vmail/opendkim:/etc/opendkim \
    -v /etc/dovecot \
    -v /var/vmail:/home/vmail \
    -v /var/vmail/log:/var/log \
    jimyhuang/docker-postfix-dovecot \
    /init.sh
docker logs -f dovecot
