FROM debian:wheezy
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt-get update -y && \
  apt-get install -y -q pwgen postfix postfix-pcre dovecot-common dovecot-core dovecot-imapd opendkim opendkim-tools rsyslog supervisor

ADD dovecot/dovecot.conf /etc/dovecot/dovecot.conf
ADD opendkim/opendkim.conf /etc/opendkim.conf
ADD dovecot/dovecot /etc/init.d/dovecot
ADD postfix/master.cf /etc/postfix/master.cf
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD rsyslog/50-default.conf /etc/rsyslog.d/50-default.conf

# SMTPS
EXPOSE 465
# IMAP over SSL
EXPOSE 993
# Submission
EXPOSE 587

ADD init.sh /init.sh
RUN chmod +x /init.sh

VOLUME ["/home/vmail", "/var/log", "/etc/ssl", "/etc/postfix", "/etc/dovecot", "/etc/opendkim"]

ENTRYPOINT ["/init.sh"]

