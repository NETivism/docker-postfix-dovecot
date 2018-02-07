#!/bin/bash
if [ -z "$1" ]; then
  echo "Please specify mail account (website docker name)";
  exit 1;
else
  USER=$1
  cp -f /etc/dovecot/passwd /etc/dovecot/passwd.old
  grep -v "^$USER@$MAILNAME:" /etc/dovecot/passwd > /tmp/passwd
  cp -f /tmp/passwd /etc/dovecot/passwd
fi
