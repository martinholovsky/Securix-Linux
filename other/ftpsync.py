#!/usr/bin/env python

#: info: Mirroring specific files and folder structure from FTP server
#: desc: This script is used on Securix websites to mirror Gentoo files.
#:       Main two reasons: download speed, high-grade communication encryption
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
import time
import sys
import ftplib
import glob
import cgi
import cgitb
import fileinput
from ftplib import FTP

cgitb.enable()

#
# VARIABLES
#

scriptdir = os.getcwd()
mtimefile = (scriptdir+"/mtime.log")
ftp = FTP("ftp.fi.muni.cz")
ftp.login("anonymous","info@securix.org")


#
# FUNCTIONS
#

# connect to FTP, mirror files and directory structure
# download only changed/new files, touch existing
def downloadFiles(path,destination,filematch):
    try:
        # wherever u r, be in script dir
        os.chdir(scriptdir)
        # sync paths on ftp and local
        ftp.cwd(path)
        if not os.path.isdir(destination):
            os.makedirs(destination)
            print ("--- Created dir: "+destination)
        os.chdir(destination)
    except OSError:
        # folder already exist
        pass
    except ftplib.error_perm:
        # invalid entry (ensure input form: "/dir/folder/something/")
        print ("--- Error: could not change to "+path)
        sys.exit("ending session")

    # get file list
    filelist = ftp.nlst(filematch)
    for ftpfile in filelist:
        # get remote file size
        ftp.sendcmd("TYPE i")
        remote_size = ftp.size(ftpfile)
        # get remote mtime
        remote_mtime = (ftpfile+" : "+ftp.sendcmd('MDTM '+ftpfile))
        # check if file already exist
        if os.path.isfile(ftpfile):    
            # get local file size
            local_size = os.path.getsize(ftpfile)
            # get last known mtime
            local_mtime = findMtime(ftpfile+" :")
            # compare size
            if local_size != remote_size:
                lf = open(os.path.join(ftpfile),'wb')
                ftp.retrbinary("RETR "+ftpfile, lf.write, 8*1024)
                print ("--- Changed file (size): "+ftpfile)
                replaceMtime(ftpfile,local_mtime,remote_mtime)
            else:
                if (local_mtime) != (remote_mtime+"\n"):
                    lf = open(os.path.join(ftpfile),'wb')
                    ftp.retrbinary("RETR "+ftpfile, lf.write, 8*1024)
                    print ("--- Changed file (mtime): "+ftpfile+" "+str(local_mtime)+" "+str(remote_mtime))
                    replaceMtime(ftpfile,local_mtime,remote_mtime)
                else:
                    # touch file, so it will not be deleted
                    os.utime(ftpfile, None)
                    print ("--- Same file: "+ftpfile)
        else:
            # if it is a new file, download it
            lf = open(os.path.join(ftpfile),'wb')
            ftp.retrbinary("RETR "+ftpfile, lf.write, 8*1024)
            appendMtime(remote_mtime)
            print ("--- New file: "+ftpfile)

# remove lines with # from file
def removeComment(file):
    lf = open(file, 'r')
    for line in lf:
        if not line.startswith('#'):
            return str(line)
    lf.close()

# match mtime
def findMtime(search):
    lf = open(mtimefile, 'r')
    for line in lf:
        if search in line:
            return str(line)
    lf.close()

# append new mtime record
def appendMtime(remote_mtime):
    with open(mtimefile, 'a') as lf:
        lf.write(remote_mtime+"\n")
        lf.close

# replace mtime
def replaceMtime(ftpfile,local_mtime,remote_mtime):
    lf = fileinput.FileInput(mtimefile,inplace=1)
    for line in lf:
        if (ftpfile+" :") in line:
            newline = line.replace((local_mtime),(remote_mtime+"\n"))
            sys.stdout.write(newline)
        else:
            sys.stdout.write(line)
    if local_mtime is None:
        appendMtime(remote_mtime)
        print ("--- Added lost mtime: "+remote_mtime)
    lf.close()

# delete mtime
def deleteMtime(oldfile):
    lf = fileinput.FileInput(mtimefile,inplace=1)
    for line in lf:
        if (oldfile+" :") in line:
            pass
        else:
            sys.stdout.write(line)
    lf.close()

# delete recursively files older than 60 days or empty folders
def deleteOldFiles(path):
    if len(os.listdir(path)) == 0:
        print ("--- Deleting empty folder: "+path)
        os.rmdir(path)
        return
    now = time.time()
    for oldfile in os.listdir(path):
        # delete files older than 60 days
        if os.stat(path+oldfile).st_mtime < (now - 60*86400):
            if os.path.isfile(path+oldfile):
                os.remove(path+oldfile)
                deleteMtime(oldfile)
                print ("--- Deleted file: "+path+oldfile)
            # recursively go through path
            elif os.path.isdir(path+oldfile):
                deleteOldFiles(path+"/"+oldfile+"/")
            pass

#
# MAIN
#

# output for CGI
print ("Content-Type: text/plain;charset=utf-8")
print

#
# Basic check
#
form = cgi.FieldStorage()
token = form.getvalue('token')
if (token) != "insert your own token here":
    print ("You're not allowed to execute this script!")
    exit()

#
# DOWNLOAD FILES
#

# sync Portage files
source="/pub/linux/gentoo/releases/snapshots/current/"
dest="./releases/snapshots/current/"
filematch="portage-latest.tar.bz*"
downloadFiles(source,dest,filematch)

# sync amd64 Stage3 LATEST file
source="/pub/linux/gentoo/releases/amd64/autobuilds/"
dest="./releases/amd64/autobuilds/"
filematch="latest-stage3-amd64-hardened.txt"
downloadFiles(source,dest,filematch)

LATEST_STAGE3 = os.path.dirname(removeComment(os.path.join(filematch)))

# sync amd64 Stage3 files
source=("/pub/linux/gentoo/releases/amd64/autobuilds/" + LATEST_STAGE3)
dest=("./releases/amd64/autobuilds/" + LATEST_STAGE3)
filematch="stage3-amd64-hardened-*"
downloadFiles(source,dest,filematch)

# sync x86 Stage3 LATEST file
source="/pub/linux/gentoo/releases/x86/autobuilds/"
dest="./releases/x86/autobuilds/"
filematch="latest-stage3-i686-hardened.txt"
downloadFiles(source,dest,filematch)

LATEST_STAGE3 = os.path.dirname(removeComment(os.path.join(filematch)))

# sync x86 Stage3 files
source=("/pub/linux/gentoo/releases/x86/autobuilds/" + LATEST_STAGE3)
dest=("./releases/x86/autobuilds/" + LATEST_STAGE3)
filematch="stage3-i686-hardened-*"
downloadFiles(source,dest,filematch)

# make cleanup on server
deleteOldFiles(scriptdir+"/releases/")

# touch htaccess so it will not be deleted
os.utime(scriptdir+"/releases/.htaccess", None)
