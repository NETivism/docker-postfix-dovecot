#!/bin/bash

if [ -n "$MAILNAME" ]
then
  mailname="$MAILNAME"
elif [ "$FQDN" = "1" ]
then
  mailname=$(hostname -f)
fi

(
  service dovecot stop
  service postfix stop
  service opendkim stop
)

# VMAIL
groupadd -g 5000 vmail > /dev/null
useradd -u 5000 -g 5000 -s /bin/bash vmail > /dev/null
usermod -G opendkim postfix

postconf -e 'milter_protocol = 2'
postconf -e 'milter_default_action = accept'
postconf -e 'smtpd_milters = inet:127.0.0.1:12301'
postconf -e 'non_smtpd_milters = $smtpd_milters'
postconf -e 'virtual_mailbox_domains = /etc/postfix/vhosts'
postconf -e 'virtual_mailbox_base = /home/vmail'
postconf -e 'virtual_mailbox_maps = hash:/etc/postfix/vmaps'
postconf -e 'smtpd_tls_key_file = /etc/ssl/private/postfix.pem'
postconf -e 'smtpd_tls_cert_file = /etc/ssl/certs/postfix.pem'
postconf -e 'virtual_minimum_uid = 1000'
postconf -e 'virtual_uid_maps = static:5000'
postconf -e 'virtual_gid_maps = static:5000'
postconf -e 'smtpd_helo_required = yes'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_sasl_security_options = noanonymous'
postconf -e 'smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination'
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

test -f /etc/postfix/vhosts || touch /etc/postfix/vhosts
test -f /etc/postfix/vmaps || touch /etc/postfix/vmaps
test -f /etc/dovecot/users || touch /etc/dovecot/users

test -d /etc/opendkim/keys || mkdir -p /etc/opendkim/keys
test -f /etc/opendkim/TrustedHosts || touch /etc/opendkim/TrustedHosts
test -f /etc/opendkim/KeyTable || touch /etc/opendkim/KeyTable
test -f /etc/opendkim/SigningTable || touch /etc/opendkim/SigningTable

echo -e 'SOCKET="inet:12301@localhost"\n' > /etc/default/opendkim

while [ $# -gt 0 ]
do
    case "$1" in
      (--email)
        shift
        if [[ -z "$1" ]]
        then
          continue
        fi

        user=$(echo "$1" | cut -f1 -d "@")
        domain=$(echo "$1" | cut -s -f2 -d "@")

        if [[ -z $domain ]]
        then
          continue
        fi

        if [[ -z $mailname ]]
        then
          mailname="$domain"
        fi

        dkim="/etc/opendkim/keys/$domain"

        if [[ ! -d $dkim ]]
        then
          echo "Creating OpenDKIM folder $dkim"
          mkdir -p $dkim
          cd $dkim && opendkim-genkey -s mail -d $domain
          chown -R opendkim:opendkim /etc/opendkim/keys/
          echo -e "127.0.0.1\nlocalhost\n192.168.0.1/24\n*.$domain" >> /etc/opendkim/TrustedHosts
          echo "*@$domain mail._domainkey.$domain" >> /etc/opendkim/SigningTable
          echo "mail._domainkey.$domain $domain:mail:$dkim/mail.private" >> /etc/opendkim/KeyTable
          cat "$dkim/mail.txt"
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
            echo "Adding user $user@$domain to /etc/dovecot/users"
            echo "$user@$domain::5000:5000::/home/vmail/$domain/$user/:/bin/false::" >> /etc/dovecot/users

            passwd=$(pwgen)
            passhash=$(doveadm pw -p $passwd -u $user)
            echo "Adding password for $user@$domain to /etc/dovecot/passwd: $passwd"
            if [[ ! -f /etc/dovecot/passwd ]]
            then
              touch /etc/dovecot/passwd
              chown root:dovecot /etc/dovecot/passwd
              chmod 640 /etc/dovecot/passwd
            fi
            echo "$user@$domain:$passhash" >> /etc/dovecot/passwd
          fi

          # Create the needed Maildir directories
          echo "Creating user directory /home/vmail/$domain/$user"

          /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user 5000:5000
          # Also make folders for Drafts, Sent, Junk and Trash
          /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Drafts 5000:5000
          /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Sent 5000:5000
          /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Junk 5000:5000
          /usr/bin/maildirmake.dovecot /home/vmail/$domain/$user/.Trash 5000:5000

          # To add user to Postfix virtual map file and relode Postfix
          echo "Adding user to /etc/postfix/vmaps"
          echo "$1  $domain/$user/" >> /etc/postfix/vmaps
          postmap /etc/postfix/vmaps
          grep -e "$domain" /etc/postfix/vhosts || echo "$domain" >> /etc/postfix/vhosts
        else
          echo "$user@$domain already exists, skipping"
        fi
        ;;
    esac
  shift
done

postconf -e "myhostname = $mailname"
subj="/C=US/ST=Denial/L=Springfield/O=Dis/CN=$mailname"

if [[ ! -a '/etc/ssl/certs/dovecot.pem' ]]
then
  openssl req -new -x509 -days 3650 -nodes -out /etc/ssl/certs/dovecot.pem -keyout /etc/ssl/private/dovecot.pem -subj $subj
fi

if [[ ! -a '/etc/ssl/certs/postfix.pem' ]]
then
  openssl req -new -x509 -days 3650 -nodes -out /etc/ssl/certs/postfix.pem -keyout /etc/ssl/private/postfix.pem -subj $subj
fi

supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
