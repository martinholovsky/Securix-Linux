#!/bin/bash

#: info: Securix GNU/Linux global aliases
#: file: /etc/profile.d/sx-aliases.sh
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

if [ $EUID -ne 0 ]; then
  alias reboot='sudo /sbin/reboot'
  alias shutdown='sudo /sbin/shutdown'
  alias securix='/usr/sbin/securix'
fi

if [ -x /usr/bin/colordiff ]; then
  alias diff='colordiff'
fi

#
# Securix aliases
#

alias ..='cd ..'
alias ...='cd ../..'
# show all connections
alias connections='netstat -natupl'
alias etc-update='dispatch-conf'
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'
# show firewall rules
alias firewall='/sbin/iptables -L -n -v --line-numbers'
alias ll='ls -alh'
alias logtail='find /var/log/ -type f | xargs file | grep ASCII | cut -d: -f1 | xargs tail -f'
alias mountt='mount | column -t'
# print file without comments
alias nocomment='grep -Ev '\''^(#|$)'\'''
alias p='ping '
# show top 10 process eating memory
alias psmem='ps auxf | sort -nr -k 4 | head -10'
# show top 10 process eating CPU
alias pscpu='ps auxf | sort -nr -k 3 | head -10'
# grep process name
alias psx='ps auxw | grep'
# password generator
alias pwgen="pwgen -yBs1 ${1:-20} ${2:-10}"
alias rm='rm --preserve-root'
alias s='ssh '
# summary of current directories size
alias size='du -sh *'
# SSH on default Securix port
alias ssx='ssh -p 55522'
alias t='telnet'
alias tr='traceroute -I'
alias ttr='sudo tcptraceroute $1 $2'
alias vi='vim'
# which find also aliases
alias which='alias | /usr/bin/which --tty-only --read-alias --show-dot --show-tilde'
alias wipe='scrub'
