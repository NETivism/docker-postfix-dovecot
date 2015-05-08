
```bash
docker run \
    -it --name dovecot
    -p 25:25 \
    -p 993:993 \
    -p 587:587 \
    -v /home/vmail:/home/vmail \
    -e MAILNAME="static.jimmyhub.net" \
    -v /etc/postfix \
    -v /etc/dovecot \
    -v /etc/ssl \
    -v /etc/opendkim \
    -v /var/log/container:/var/log \
    NETivism/docker-postfix-dovecot \
    --email test@static.jimmyhub.net \
    --email test2@static.jimmyhub.net
```
