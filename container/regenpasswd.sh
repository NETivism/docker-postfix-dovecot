#!/bin/bash
if [ -z "$1" ]; then
  echo "Please specify user account";
  exit 1;
else
  ACCOUNT=$1
  USER=$(echo "$ACCOUNT" | cut -f1 -d "@")
  PASSWD=$(pwgen)
  PASSHASH=$(doveadm pw -p $PASSWD -u $USER)
  cp -f /etc/dovecot/passwd /etc/dovecot/passwd.old
  grep -v "^$ACCOUNT:" /etc/dovecot/passwd > /tmp/passwd
  cp -f /tmp/passwd /etc/dovecot/passwd
  echo "$ACCOUNT:$PASSHASH" >> /etc/dovecot/passwd
  echo $PASSWD
fi
