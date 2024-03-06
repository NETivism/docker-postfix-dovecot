#!/bin/sh
#docker pull rg.netivism.com.tw/netivism/docker-postfix-dovecot:develop
docker stop dovecot
docker rm dovecot
docker run \
    -d --name dovecot \
    -p 30993:993 \
    -p 30587:587 \
    -p 30025:25 \
    -p 32525:2525 \
    -p 30465:465 \
    -v /var/vmail:/home/vmail \
    -v /var/vmail/log:/var/log \
    -v /var/vmail/opendkim:/etc/opendkim \
    -v /var/vmail/opendkim.conf:/etc/opendkim.conf \
    -e "MAILNAME=test.netivism.com.tw" \
    -e "TZ=Asia/Taipei" \
    -e "DKIM_PREFIX=netimx" \
    rg.netivism.com.tw/netivism/docker-postfix-dovecot:develop
docker logs -f dovecot
