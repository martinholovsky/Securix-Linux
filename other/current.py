#!/usr/bin/env python

#: info: Script which select next Securix release in sequence
#: desc: Update process specify in variable "sxver" actual Securix version, this script
#:       will check what is next release in sequence and provide link for download
#:       This script is used only on Securix websites
#: author: Martin Cmelik (cm3l1k1) - securix.org, security-portal.cz
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
# -*- coding: utf-8 -*-

import os
import glob
import re
import sys
import cgi
import cgitb

cgitb.enable()
form = cgi.FieldStorage()

# print header for cgi output
print ("Content-Type: text/plain")
print

# get sxver from client
sxver = form.getvalue('sxver')
if sxver is None:
    print ("--- Error: No Securix version provided")
    sys.exit()

if not re.match("[0-9]*$", sxver):
    print ("--- Error: Invalid Securix version")
    sys.exit()

# get sxid from client
sxid = form.getvalue('sxid')
if sxid is None:
    sxid = str(12345)

if not re.match("[A-Za-z0-9]*$", sxid):
    sxid = str(12345)

# get client ip
client_ip = os.environ["REMOTE_ADDR"]
if not re.match("[0-9\.]*$", client_ip):
    client_ip = 0

# get sorted list of directories (releases) which contain 8 numbers in name
os.chdir('./../releases/')
# for SF only!
# os.chdir('./../htdocs/releases/')
releases = sorted(glob.glob('./'+('[0-9]'*8)))

for sequence in releases:
    sequence = re.sub('[./]', '', sequence)
    if sequence > sxver:
        if os.path.isdir(sequence):
            nextrelease = sequence
            break


# check if nextrelase is defined
try:    
    nextrelease
except NameError:
    if os.path.isdir(sxver):
        nextrelease = sxver
    else:
        print ("--- Error: unable to find next update sequence")
        sys.exit()

# send release to user
print (nextrelease)