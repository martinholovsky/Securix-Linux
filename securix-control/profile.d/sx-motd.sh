#!/bin/bash

#: info: Securix GNU/Linux motd loader
#: file: /etc/profile.d/sx-motd.sh
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


# Check if standard input is a tty device (interactive shell)
if [ -t 0 -a "$TERM" != "dumb" ]; then
    INTERACTIVE="yes"
    . /usr/sbin/securix-motd
else
    return
fi
