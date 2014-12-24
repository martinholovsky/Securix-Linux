#!/bin/bash

#: info: Securix GNU/Linux system variables/profile setup
#: file: /etc/profile.d/sx-profile.sh
#: author: Martin Cmelik (cm3l1k1) - securix.org, security-portal.cz
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


# log each user command
declare -r PROMPT_COMMAND='{ logger -p local5.info "${HOSTNAME} [HIST] : ${SSH_CLIENT} : ${PWD} : $(history 1)"; }'

# set basic bash variables for command history, declare them as readonly
declare -r HISTFILE="${HOME}/.bash_history"
declare -ir HISTSIZE=10000
declare -ir HISTFILESIZE=100000
declare -r HISTIGNORE=""
declare -r HISTCONTROL=""
#declare -r HISTTIMEFORMAT="%F %T "

shopt -s histverify
shopt -s histappend

# umask
umask 027

# if youre not root, TMOUT will be readonly
if [ $EUID -ne 0 ]; then
    declare -ir TMOUT="900"
else
    TMOUT="900"
fi

# create HISTFILE if not exist
if [ ! -r "$HISTFILE" ]; then
    touch "$HISTFILE"
fi

# make log about login to interactive shell
logger -p local5.info "${HOSTNAME} [LOGIN] ${USER} logged in on term: ${TERM} ssh: ${SSH_CLIENT}"
