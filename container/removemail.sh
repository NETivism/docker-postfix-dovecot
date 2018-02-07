#!/bin/bash
if [ -z "$1" ]; then
  echo "Please specify user account";
  exit 1;
else
  ACCOUNT=$1
  cp -f /etc/dovecot/passwd /etc/dovecot/passwd.old
  grep -v "^$ACCOUNT" /etc/dovecot/passwd > /tmp/passwd
  cp -f /tmp/passwd /etc/dovecot/passwd
fi
