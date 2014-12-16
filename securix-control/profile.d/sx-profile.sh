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
