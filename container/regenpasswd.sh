#!/bin/bash
if [ -z "$1" ]; then
  echo "Please specify mail account (website docker name)";
  exit 1;
else
  USER=$1
  PASSWD=$(pwgen)
  PASSHASH=$(doveadm pw -p $PASSWD -u $USER)
  cp -f /etc/dovecot/passwd /etc/dovecot/passwd.old
  grep -v "^$USER@$MAILNAME:" /etc/dovecot/passwd > /tmp/passwd
  cp -f /tmp/passwd /etc/dovecot/passwd
  echo "$USER@$MAILNAME:$PASSHASH" >> /etc/dovecot/passwd
  echo $PASSWD
fi
