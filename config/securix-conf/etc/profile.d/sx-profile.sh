#!/bin/bash

#: info: Securix GNU/Linux system variables/profile setup
#: file: /etc/profile.d/sx-profile.sh
#: author: Martin Cmelik (cm3l1k1) - securix.org, security-portal.cz
#: version: 20141123
#

# log user commands
export PROMPT_COMMAND='{ logger -p local5.info "${HOSTNAME} [HIST] : ${SSH_CLIENT} : ${PWD} : $(history 1)"; }'

# set basic bash variables for command history
HISTFILE="${HOME}/.bash_history"
HISTSIZE=10000
HISTFILESIZE=100000
HISTIGNORE=""
HISTCONTROL=""
#HISTTIMEFORMAT="%F %T "

shopt -s histverify
shopt -s histappend

# set timeout
TMOUT=900

# umask 
umask 027

# avoid changing values
readonly HOME
readonly HISTFILE
readonly HISTSIZE
readonly HISTFILESIZE
readonly HISTIGNORE
readonly HISTCONTROL
readonly PROMPT_COMMAND
#readonly HISTTIMEFORMAT
if [ $EUID -ne 0 ]; then
    readonly TMOUT
fi

# create HISTFILE if not exist
if [ ! -r "$HISTFILE" ]; then
    touch "$HISTFILE"
fi

# make log about login to interactive shell
logger -p local5.info "${HOSTNAME} [LOGIN] ${USER} logged in on term: ${TERM} ssh: ${SSH_CLIENT}"
