#!/bin/bash

#: info: Securix GNU/Linux motd loader
#: file: /etc/profile.d/sx-motd.sh
#: author: Martin Cmelik (cm3l1k1) - securix.org, security-portal.cz
#: version: 20141201
#

# Check if standard input is a tty device (interactive shell).
if [ -t 0 -a "$TERM" != "dumb" ]; then
    . /usr/sbin/securix-motd
else
    return
fi
