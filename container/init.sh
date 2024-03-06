#!/bin/bash

if [ -n "$MAILNAME" ]
then
  mailname="$MAILNAME"
elif [ "$FQDN" = "1" ]
then
  mailname=$(hostname -f)
fi
if [ -n "$DKIM_PREFIX" ]
then
  dkimp=$DKIM_PREFIX
else
  dkimp="mail"
fi

if [ -f /etc/dovecot/passwd ]; then
  rm -f /etc/dovecot/passwd
fi
ln -s /home/vmail/passwd /etc/dovecot/

# VMAIL
groupadd -g 5000 vmail > /dev/null
useradd -u 5000 -g 5000 -s /bin/bash vmail > /dev/null
usermod -G opendkim postfix

test -f /home/vmail/vhosts && cp -f /home/vmail/vhosts /etc/postfix/vhosts
test -f /etc/postfix/vhosts || touch /etc/postfix/vhosts
test -f /etc/postfix/vmaps || touch /etc/postfix/vmaps
test -f /etc/dovecot/users || touch /etc/dovecot/users
test -f /etc/postfix/transport && postmap /etc/postfix/transport
test -d /home/vmail/tmp || mkdir -p /home/vmail/tmp

test -d /etc/opendkim/keys || mkdir -p /etc/opendkim/keys
test -f /etc/opendkim/TrustedHosts || touch /etc/opendkim/TrustedHosts
test -f /etc/opendkim/KeyTable || touch /etc/opendkim/KeyTable
test -f /etc/opendkim/SigningTable || touch /etc/opendkim/SigningTable

if [ -f "/home/vmail/postfix-main.cf" ]; then
  cp -f /etc/postfix/main.cf /etc/postfix/main.cf.origin
  cp -f /home/vmail/postfix-main.cf /etc/postfix/main.cf
else
  postconf -e 'milter_protocol = 2'
  postconf -e 'milter_default_action = accept'
  postconf -e 'smtpd_milters = unix:/var/run/opendkim/opendkim.sock'
  postconf -e 'inet_protocols = ipv4'
  postconf -e 'non_smtpd_milters = $smtpd_milters'
  postconf -e 'virtual_mailbox_domains = /etc/postfix/vhosts'
  postconf -e 'virtual_mailbox_base = /home/vmail'
  postconf -e 'virtual_mailbox_maps = hash:/etc/postfix/vmaps'
  postconf -e 'transport_maps = hash:/etc/postfix/transport'
  postconf -e 'smtpd_tls_key_file = /etc/ssl/private/postfix.pem'
  postconf -e 'smtpd_tls_cert_file = /etc/ssl/certs/postfix.pem'
  postconf -e 'virtual_minimum_uid = 1000'
  postconf -e 'virtual_uid_maps = static:5000'
  postconf -e 'virtual_gid_maps = static:5000'
  postconf -e 'smtpd_helo_required = yes'
  postconf -e 'smtpd_sasl_auth_enable = yes'
  postconf -e 'smtpd_sasl_security_options = noanonymous'
  postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination'
  postconf -e 'smtpd_sasl_type = dovecot'
  postconf -e 'smtpd_sasl_path = private/auth'
  postconf -e 'smtpd_tls_auth_only = no'
  postconf -e 'smtpd_sasl_authenticated_header = yes'
  postconf -e 'smtp_tls_security_level = may'
  postconf -e 'smtpd_tls_security_level = may'
  postconf -e 'smtp_use_tls = yes'
  postconf -e 'local_recipient_maps ='
  postconf -e 'smtpd_use_tls = yes'
  postconf -e 'smtp_tls_note_starttls_offer = yes'
  postconf -e 'smtpd_tls_loglevel = 1'
  postconf -e 'smtpd_tls_received_header = yes'
  postconf -e 'smtpd_tls_session_cache_timeout = 3600s'
  postconf -e 'tls_random_source = dev:/dev/urandom'
  postconf -e 'smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3'
  postconf -e 'maximal_queue_lifetime = 1d'
  postconf -e 'bounce_queue_lifetime = 12h'
  postconf -e 'maximal_backoff_time = 12h'
  postconf -e 'minimal_backoff_time = 9h'
  postconf -e 'queue_run_delay = 9h'
  postconf -e 'qmgr_message_active_limit = 40000'
  postconf -e 'qmgr_message_recipient_limit = 40000'
  postconf -e 'fast_destination_concurrency_limit = 5'
  postconf -e 'fast_destination_rate_delay = 0'
  postconf -e 'fast_destination_recipient_limit = 2'
  postconf -e 'smtp_destination_concurrency_limit = 1'
  postconf -e 'smtp_destination_rate_delay = 3s'
  postconf -e 'smtp_destination_recipient_limit = 2'
  postconf -e 'turtle_destination_concurrency_limit = 1'
  postconf -e 'turtle_destination_rate_delay = 60s'
  postconf -e 'turtle_destination_recipient_limit = 2'
  postconf -e 'compatibility_level = 3'
fi

echo -e '' > /home/vmail/tmp/vmail_dkim
if [ -z "$MAILADDR" ]; then
  mailaddr=`cat /home/vmail/mailaddr`
else
  mailaddr=$MAILADDR
fi
if [ -n "$mailaddr" ]; then
  IFS=';' read -ra ADDR <<< "$mailaddr"
  for mail in "${ADDR[@]}"; do
    echo $mail;
    if [[ -z "$mail" ]]; then
      continue
    fi
    user=$(echo "$mail" | cut -f1 -d "@")
    domain=$(echo "$mail" | cut -s -f2 -d "@")

    if [[ -z $domain ]]
    then
      continue
    fi

    if [[ -z $mailname ]]
    then
      mailname="$domain"
    fi

    dkim="/etc/opendkim/keys/$domain"

    if [[ -f "/etc/opendkim/globalkey.private" ]]
    then
      chown opendkim:opendkim /etc/opendkim/globalkey.private
      chmod 600 /etc/opendkim/globalkey.private
      grep -qF "$domain" /etc/opendkim/TrustedHosts || echo -e "127.0.0.1\nlocalhost\n192.168.0.1/24\n*.$domain" >> /etc/opendkim/TrustedHosts
      grep -qF "*@$domain $dkimp._domainkey.$domain" /etc/opendkim/SigningTable || echo -e "*@$domain $dkimp._domainkey.$domain\n$(cat /etc/opendkim/SigningTable)" > /etc/opendkim/SigningTable
      grep -qF "$dkimp._domainkey.$domain $domain:$dkimp:/etc/opendkim/globalkey.private" /etc/opendkim/KeyTable || echo "$dkimp._domainkey.$domain $domain:$dkimp:/etc/opendkim/globalkey.private" >> /etc/opendkim/KeyTable
    elif [[ ! -d $dkim ]]
    then
      # echo "Creating OpenDKIM folder $dkim"
      mkdir -p $dkim
      cd $dkim && opendkim-genkey -s $dkimp -d $domain
      chown -R opendkim:opendkim /etc/opendkim/keys/
      echo -e "127.0.0.1\nlocalhost\n192.168.0.1/24\n*.$domain" >> /etc/opendkim/TrustedHosts
      echo "*@$domain $dkimp._domainkey.$domain" >> /etc/opendkim/SigningTable
      echo "$dkimp._domainkey.$domain $domain:$dkimp:$dkim/$dkimp.private" >> /etc/opendkim/KeyTable
      cat "$dkim/$dkimp.txt" > /home/vmail/tmp/vmail_dkim
    fi

    # maildirmake.dovecot does only chown on user directory, we'll create domain directory instead
    if [[ ! -d "/home/vmail/$domain" ]]
    then
      mkdir /home/vmail/$domain
      chown 5000:5000 /home/vmail/$domain
      chmod 700 /home/vmail/$domain
    fi

    if [[ ! -d "/home/vmail/$domain/$user" ]]
    then
      if [[ -z $(grep $user@$domain /etc/dovecot/users) ]]
      then
        #echo "Adding user $user@$domain to /etc/dovecot/users"
        echo "$user@$domain::5000:5000::/home/vmail/$domain/$user/:/bin/false::" >> /etc/dovecot/users

        passwd=$(pwgen)
        passhash=$(doveadm pw -p $passwd -u $user)
        echo "{\"email\":[{\"username\":\"${user}@${domain}\", \"password\":\"${passwd}\"}]}" > /home/vmail/tmp/vmail_json
        echo "{\"email\":[{\"username\":\"${user}@${domain}\", \"password\":\"${passwd}\"}]}" > /home/vmail/tmp/${user}
        if [[ ! -f /etc/dovecot/passwd ]]
        then
          touch /etc/dovecot/passwd
        fi
        chown root:dovecot /etc/dovecot/passwd
        chown root:dovecot /home/vmail/passwd
        echo "$user@$domain:$passhash" >> /etc/dovecot/passwd
      fi

      # Create the needed Maildir directories
      # echo "Creating user directory /home/vmail/$domain/$user"

      /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user 5000:5000
      # Also make folders for Drafts, Sent, Junk and Trash
      /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Drafts 5000:5000
      /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Sent 5000:5000
      /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Junk 5000:5000
      /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Trash 5000:5000

      # To add user to Postfix virtual map file and relode Postfix
      #echo "Adding user to /etc/postfix/vmaps"
      echo "$mail  $domain/$user/" >> /etc/postfix/vmaps
      postmap /etc/postfix/vmaps
      if [[ ! -f /home/vmail/vhosts ]]
      then
        grep -e "$domain" /etc/postfix/vhosts || echo "$domain" >> /etc/postfix/vhosts
      fi
    else
      grep -e "$user@$domain" /etc/dovecot/users ||  echo "$user@$domain::5000:5000::/home/vmail/$domain/$user/:/bin/false::" >> /etc/dovecot/users
      grep -e $mail /etc/postfix/vmaps || echo "$mail  $domain/$user/" >> /etc/postfix/vmaps
      postmap /etc/postfix/vmaps
      if [[ ! -f /home/vmail/vhosts ]]
      then
        grep -e "$domain" /etc/postfix/vhosts || echo "$domain" >> /etc/postfix/vhosts
      fi
      echo "Skipping $user@$domain (already exists)"
    fi
  done
fi

dkimaddr=`cat /home/vmail/dkimaddr`
if [ -n "$dkimaddr" ]; then
  while read -r dkimdomain
  do
    if [[ -z "$dkimdomain" ]]; then
      continue
    fi
    if [[ -f "/etc/opendkim/globalkey.private" ]]
    then
      grep -qF "*@$dkimdomain $dkimp._domainkey.$dkimdomain" /etc/opendkim/SigningTable || echo -e "*@$dkimdomain $dkimp._domainkey.$dkimdomain\n$(cat /etc/opendkim/SigningTable)" > /etc/opendkim/SigningTable
      grep -qF "$dkimp._domainkey.$dkimdomain $dkimdomain:$dkimp:/etc/opendkim/globalkey.private" /etc/opendkim/KeyTable || echo "$dkimp._domainkey.$dkimdomain $dkimdomain:$dkimp:/etc/opendkim/globalkey.private" >> /etc/opendkim/KeyTable
    fi
  done < /home/vmail/dkimaddr
fi

chmod 640 /home/vmail/tmp/*
if [ -f /home/vmail/passwd ]; then
  chown root:dovecot /etc/dovecot/passwd
  chown root:dovecot /home/vmail/passwd
fi

postconf -e "myhostname = $mailname"
subj="/C=US/ST=Denial/L=Springfield/O=Dis/CN=$mailname"

if [[ ! -a '/etc/ssl/certs/dovecot.pem' ]]
then
  openssl req -new -x509 -days 3650 -nodes -out /etc/ssl/certs/dovecot.pem -keyout /etc/ssl/private/dovecot.pem -subj $subj 2>/dev/null
fi

if [[ ! -a '/etc/ssl/certs/postfix.pem' ]]
then
  openssl req -new -x509 -days 3650 -nodes -out /etc/ssl/certs/postfix.pem -keyout /etc/ssl/private/postfix.pem -subj $subj 2>/dev/null
fi


/etc/init.d/postfix stop
/etc/init.d/opendkim stop
ps aux | grep "postfix\/sbin\/master" | awk '{ print $2 }' | xargs kill
ps aux | grep "bin\/opendkim" | awk '{ print $2 }' | xargs kill
ps aux | grep "bin\/dovecot" | awk '{ print $2 }' | xargs kill
chown -R opendkim:opendkim /etc/opendkim/keys
rm -f /var/run/dovecot/master.pid

sleep 5

/etc/init.d/postfix start
/etc/init.d/opendkim start 
/usr/sbin/dovecot -c /etc/dovecot/dovecot.conf -F
