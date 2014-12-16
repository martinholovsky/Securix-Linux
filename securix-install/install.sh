#!/bin/bash

#: title: Securix GNU/Linux installer
#: file: install.sh
#: desc: Securix installation/build script
#: latest version: 'wget https://securix.org/install.sh'
#: howto: boot from gentoo minimal cd, download and execute this script
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

# define arch and variables
case "$HOSTTYPE" in
    x86_64)
        ARCH="amd64"
        SUBARCH="amd64"
        KERNELPATH="x86_64"
        CHOSTS="x86_64-pc-linux-gnu"
        modprobe aes_x86_64
        ;;
#    i386|i486|i586|i686)
#        ARCH="x86"
#        SUBARCH="i686"
#        KERNELPATH="i386"
#        CHOSTS="i686-pc-linux-gnu"
#        ;;
    *)
    	echo "ERROR: valid architecture not found - ${HOSTTYPE}"
    	exit 1
    	;;
esac

##############################################################################
#
# VARIABLES
#
##############################################################################

SX_STAGE3BASEURL="https://mirror.securix.org/releases/${ARCH}/autobuilds/"
SX_STAGE3LATESTTXT="latest-stage3-${SUBARCH}-hardened.txt"
SX_PORTAGEFILE="https://mirror.securix.org/releases/snapshots/current/portage-latest.tar.bz2"
# gentoo servers usually do not use https and if so, it is just self-signed certificate
STAGE3BASEURL="http://distfiles.gentoo.org/releases/${ARCH}/autobuilds/"
STAGE3LATESTTXT="latest-stage3-${SUBARCH}-hardened.txt"
PORTAGEFILE="http://distfiles.gentoo.org/releases/snapshots/current/portage-latest.tar.bz2"
SECURIXFILES="https://update.securix.org"
SECURIXFILESDR="http://securix.sourceforge.net"
GMIRROR="http://ftp.fi.muni.cz/pub/linux/gentoo/"
CPUS=$(grep -c '^processor' /proc/cpuinfo)
MOPTS=$((CPUS + 1))
GENKERNEL="--install --symlink --save-config --makeopts=-j${MOPTS} --kernname=securix --kernel-config=/hardened-kernel.config"
GRUBOPTS="vga=791 quiet"
SECURIXID=$(ifconfig -a | sha1sum | awk '{ print $1 }')
LOGFILE="/root/securix-install.log"
LOCKFILE="/root/securix.lock"
CHROOTOK="/mnt/gentoo/chroot.ok"
USER_PASSWORD="pass${RANDOM}"
txtred='\e[0;31m'
txtblue='\e[1;34m'
txtgreen='\e[0;32m'
txtwhite='\e[0;37m'
txtdefault='\e[00m'
txtyellow='\e[0;33m'
# partitioning
PBOOTS="+256M"
DISKMIN=18000000000
DISKOPTIM=38000000000
BOOTOPTS="noauto,relatime,nodiratime"
ROOTOPTS="defaults,relatime,nodiratime"
USROPTS="defaults,relatime,nodiratime,nodev"
HOMEOPTS="defaults,relatime,nodiratime,nodev,nosuid"
OPTOPTS="defaults"
VAROPTS="defaults,relatime,nodiratime,nodev,nosuid,noexec"
PORTAGEOPTS="defaults,relatime,nodiratime,nodev,nosuid"
TMPOPTS="defaults,relatime,nodiratime,nodev,nosuid,noexec"


##############################################################################
#
# FUNCTIONS
#
##############################################################################

f_yesno() {
    #example: f_yesno "Are you sure?" variable
    local answer
    echo -ne "${txtblue}» Q: ${1} (yes/NO): ${txtdefault}"
    read answer
    case "$answer" in
        y|Y|yes|YES|Yes) yesno="yes" ;;
        *) yesno="no" ;;
    esac
    if [ ! -z "$2" ]; then
        eval $2="$yesno"
    fi
}

f_getvar() {
    #example: f_getvar "Your name?" variable "default value"
    local answer
    echo -ne "${txtblue}» Q: ${1} ${txtdefault}"
    read answer
    #set default when null
    if [ -z "$answer" ]; then
        local defaultvar=${3:?Error answer and default value is null}
        eval $2="$3"
    else
        eval $2="$answer"
    fi
}

f_getpass() {
    #example: f_getpass "Service password:" variable "default value"
    local answer
    echo -ne "${txtblue}» ${1} ${txtdefault}"
    read -s -p "" answer
    f_msg newline
    #set default when null
    if [ -z "$answer" ]; then
        local defaultvar=${3:?Error answer and default value is null}
        eval $2="$3"
    else
        eval $2="$answer"
    fi
}

f_msg() {
    #example: f_msg info "This is info message"
    case "$1" in
        error) echo -e "${txtred}${2} ${txtdefault}" ;;
        warn) echo -e "${txtyellow}${2} ${txtdefault}" ;;
        info) echo -e "${txtgreen}${2} ${txtdefault}" ;;
        newline) echo "" ;;
        *) echo "${1} ${2}" ;;
    esac
}

f_download() {
    #usage: f_download $link $backup-link
    #example: f_download https://x.y.z/file.tgz https://mirror.x.y.z/file.tgz
    if [ -z $1 ]; then
        echo "--- Error: No URL provided"
    fi
    # propagate error code in pipelines
    set -o pipefail
    local downlink="$1"
    local backuplink="$2"
    local downfile=${downlink##*/}
    local backupfile=${backuplink##*/}
    local wgeterror="no"
    # remove parameters from link
    downfile=${downfile%%\?*}
    backupfile=${backupfile%%\?*}
    # remove previous files if any
    rm -f ${downfile} ${backupfile}
    echo "Downloading: ${downlink}"
    echo -n "Status:     "
    # wget version in gentoo minimal CD do not support PFS :( and https-only
    wget --timeout=30 --no-cache --progress=dot -O "${downfile}" "${downlink}" 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    if [ $? -ne 0 ]; then
        wgeterror="yes"
    fi
    echo " DONE"
    if [ -f $downfile -a "$wgeterror" = "no" ]; then
        downloaded="yes"
        return 0
    else
        wgeterror="no"
        if [ ! -z $backuplink ]; then
            echo "Downloading from mirror: ${backuplink}"
            echo -n "Status:     "
            # https-only not used as Gentoo mirrors usually dont have SSL
            wget --timeout=30 --no-cache --progress=dot -O "${backupfile}" "${backuplink}" 2>&1 | grep --line-buffered "%" | \
                sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
            if [ $? -ne 0 ]; then
                wgeterror="yes"
            fi
            echo " DONE"
            if [ -f $backupfile -a "$wgeterror" = "no" ]; then
                downloaded="yes"
                return 0
            else
                downloaded="no"
                return 1
            fi
        else
            downloaded="no"
            return 1
        fi
    fi
}

f_dmesg() {
    #example: f_dmesg ttyS USERSERIAL
    #if string exist 2nd parameter have value "yes"
    dmesg | grep ${1} > /dev/null
    if [ $? -eq 0 ]; then
        export $2="yes"
    else
        export $2="no"
    fi
}

f_grep() {
    #example: f_grep " ept " /proc/cpuinfo EPTFLAG
    #if string exist 3rd parameter have value "yes"
    grep "${1}" "${2}" > /dev/null
    if [ $? -eq 0 ]; then
        export $3="yes"
    else
        export $3="no"
    fi
}

f_validip() {
    #example: f_validip 1.2.3.4
    #validate IP address format
    ip="$1"
    local IFS='.'
    # set IP as positional parameter for each oktet
    set -- $ip
    # check that IP contain only numbers and dots
    if [[ "$ip" =~ "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" ]]; then
        
        # check each position parameter
        if [[ ${1} -le 255 && ${2} -le 255 && ${3} -le 255 && ${4} -le 255 ]]; then
            VALIDIP="yes"
        else
            VALIDIP="no"
        fi
    else
        VALIDIP="no"
    fi
}

# End script in case of error
# trap also this exit signals: 1/HUP, 2/INT, 3/QUIT, 15/TERM, ERR
trap exit_on_error 1 2 3 15 ERR

exit_on_error() {
    local exit_status=${1:-$?}
    echo -e "${txtred}»»» Exiting $0 with status: $exit_status ${txtdefault}"
    if [ "$DISKSYNC" != "ok" ]; then
      echo -e "${txtred}»»» If you have problem with partitioning, please reboot server${txtdefault}"
    fi
    rm -f $LOCKFILE
    exit $exit_status
}

##############################################################################
#
# MAIN
#
##############################################################################

# banner
clear
echo -e "
   _________                                         __
  /   _____/   ____    ______   __  __  _________   |__| ___  ___
  \_____  \   / __ \  /  ____| |  ||  | \_  ___  \  |  | \  \/  /
  ______|  \ |  ___/  \  \___  |  ||  |  |  |_/  /  |  |  > || <
 /_________/  \_____\  \_____| |_____/   |__| |__\  |__| /__/\__\\
\n
::: Securix GNU/Linux installer
::: www.securix.org
::: www.security-portal.cz
"
sleep 1
echo "» Starting..."
echo ""
sleep 1

# check permissions
if [ $EUID -ne 0 ]; then
    f_msg error "This script must be run as root."
    exit 1
fi

# lockfile
if [ -f $LOCKFILE ]; then
    f_msg error "It seems that there is already running Securix installer... exiting"
    f_msg info "If youre sure what youre doing, you can execute: rm -f ${LOCKFILE}"
    exit 1
else
    touch $LOCKFILE
fi

# check networking
wget --timeout=30 --delete-after -q http://www.google.com
if [ $? -ne 0 ]; then
    f_msg error "ERROR: Unable to contact google.com!"
    f_msg info  "Yes, Google can be down, but Occam's Razor would suggest \
that you have problem with your Internet connectivity."
    f_msg info " --- Please setup http_proxy or fix network issue"
    exit_on_error
fi

# verifying securix installer
f_msg warn "Verifying signature of installation script..."
f_download ${SECURIXFILES}/install/install.sh.sign ${SECURIXFILESDR}/install/install.sh.sign
f_download ${SECURIXFILES}/certificates/securix-codesign.pub ${SECURIXFILESDR}/certificates/securix-codesign.pub
openssl dgst -sha512 -verify securix-codesign.pub -signature install.sh.sign ${BASH_SOURCE}
f_msg newline

f_msg info "-:-:[ Please setup system details ]:-:-"
f_msg newline

# setup hostname
f_getvar "Hostname [default: securix]: " SECURIX_HOSTNAME "securix"

# setup root password
until [ "$passmatch" = "ok" ]; do
f_getpass "ROOT password/phrase [default: s3cur1x]: " ROOT_PASSWORD "s3cur1x"
f_getpass "ROOT password/phrase one more time [default: s3cur1x]: " ROOT_PASSWORD2 "s3cur1x"
if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD2" ]; then
    passmatch="ok"
else
    f_msg warn "Password mismatch! Try it one more time..."
    f_msg newline
fi
done

# setup root mail address
f_getvar "MAIL address for system notifications [default: root, but should be some mail group]: " ROOT_MAIL "root"
f_msg info "Now please specify outgoing mail server and username/password if needed"
f_msg info "Example format: smtp.gmail.com:587 mymail@gmail.com mypassword"
f_getvar "MAIL server/gateway [default: mail (domain.com)]: " MAIL_HOST "mail"

# check serial
f_dmesg ttyS USERSERIAL
if [ "$USERSERIAL" = "yes" ]; then
    f_msg info "-- Serial console found. I will provide you serial terminal access"
    SYSTEMPACKAGE="${SYSTEMPACKAGE} minicom setserial"
fi

# check dmraid
# if RAID is not recognized in /dev/mapper is "control" only
DMRAIDCOUNT=$(ls /dev/mapper | wc -l)
if [ "$DMRAIDCOUNT" -gt 1 ]; then
    f_msg info "-- RAID device found. I will install basic tools and include support in initramfs"
    SYSTEMPACKAGE="${SYSTEMPACKAGE} dmraid"
    GENKERNEL="${GENKERNEL} --dmraid"
    GENKERNELUSE="${GENKERNELUSE} dmraid"
fi

# check virtual environment
f_dmesg "-i virtual" VIRTUAL
if [ "$VIRTUAL" = "yes" ]; then
    f_msg info "-- It seems that installer is running under virtual machine (VirtualBox, VMware, ...)"
    f_yesno "Securix have pre-defined kernel setup for VM's. Do you want to use it?" VIRTUAL
    if [ "$VIRTUAL" = "yes" ]; then
        f_getvar "Which VM host are you using? 1) VirtualBox 2) KVM/QEMU 3) Xen 4) VMware 5) None of them : " VIRTUALHOST
        case "$VIRTUALHOST" in
            1) VIRTUALHOST="VIRTUALBOX" ;;
            2) VIRTUALHOST="KVM" ;;
            3) VIRTUALHOST="XEN" ;;
            4) VIRTUALHOST="VMWARE" ;;
            *)
                f_msg warn "-- Only provided VM's are supported"
                f_msg info "-- You will be asked to setup kernel configuration manually during installation"
                VIRTUAL="no"
                unset VIRTUALHOST
                ;;
        esac
        if [ ! -z $VIRTUALHOST ]; then
            echo "--- Selected: ${VIRTUALHOST}"
        fi
    fi
else
    f_msg info "-- In few minutes you will be asked to manually setup kernel configuration"
    f_msg info "-- It is almost same as Securix pre-defined setup for VM's, but you need to check at least CPU, HDD, Network"
fi

# setup networking
interfaces=$(ifconfig -a | grep -c eth)
interfaces_found=$(ifconfig -a | grep -E '^*: ' | cut -d: -f1 | grep -vE '^lo')
if [ $interfaces -ne 1 ]; then
    f_yesno "Multiple ethernets found. Do you want setup bonding?" BONDING
fi

if [ -z "$BONDING" -o "$BONDING" = "no" ]; then
    BONDING="no"
    f_yesno "Do you want setup networking manually? [NO is DHCP]" NETMANUAL

    if [ "$NETMANUAL" = "no" ]; then
        
        # dhcp
        if [ $interfaces -eq 1 ]; then
            f_msg info "-- Interfaces found in system: ${interfaces_found}"
            f_getvar "Specify interface [default: ${interfaces_found}]: " NETETH "${interfaces_found}"
            USEDHCP="yes"
        else
            f_msg info "-- Interfaces found in system: ${interfaces_found}"
            f_getvar "Specify interface [default: eth0]: " NETETH "eth0"
            USEDHCP="yes"
        fi
    else
        
        # manual
        f_msg info "Current ifconfig:"
        ifconfig | grep -B 1 inet | grep -vE '127.0.0.1|Loopback'
        f_msg info "Routing:"
        route -n | grep -vE 'Kernel|127.0.0.1'
        f_msg newline
        f_getvar "Specify interface [default: eth0]: " NETETH "eth0"
        f_getvar "Specify IP address [192.168.1.100]: " NETIP "192.168.1.100"
        f_getvar "Specify netmask [255.255.255.0]: " NETMASK "255.255.255.0"
        f_getvar "Specify default gateway [192.168.1.1]: " NETGATEWAY "192.168.1.1"
        f_getvar "Specify primary DNS server [8.8.8.8]: " NETDNS "8.8.8.8"
        f_getvar "Specify secondary DNS server [8.8.4.4]: " NETDNS2 "8.8.4.4"
        f_getvar "Specify domain name [securix.local]: " NETDOMAIN "securix.local"
        f_getvar "Specify primary NTP server [0.gentoo.pool.ntp.org]" NETNTP "0.gentoo.pool.ntp.org"
        f_getvar "Specify secondary NTP server [1.gentoo.pool.ntp.org]" NETNTP2 "1.gentoo.pool.ntp.org"
    fi
fi

# bonding
if [ "$BONDING" = "yes" ]; then
    SYSTEMPACKAGE="${SYSTEMPACKAGE} net-misc/ifenslave"
    f_yesno "Do you want use defaults (DHCP on bond0, slaves eth0+eth1, mode active-backup)?" USEDHCP
    if [ "$USEDHCP" = "no" ]; then
        f_msg info "Current ifconfig:"
        ifconfig | grep -B 1 inet | grep -vE '127.0.0.1|Loopback'
        f_msg info "Routing:"
        route -n | grep -vE 'Kernel|127.0.0.1'
        f_msg newline
        NETETH="bond0"
        f_msg info "Please select bonding mode number: 0-balance-rr, 1-active-backup, 2-balance-xor, 3-broadcast, 4-802.3ad, 5-balance-tlb, 6-balance-alb"
        f_msg info "Recommended: 1-Active/Backup (+fault tolerance) OR 0-Round Robin (+load balancing, +fault tolerance, -need setup etherchannel on switch)"
        f_getvar "Specify bonding mode [default: 1]: " BONDINGMODE "1"
        f_getvar "Specify bonding slave interfaces [eth0 eth1]: " BONDINGSLAVE "eth0 eth1"
        f_getvar "Specify IP address [192.168.1.100]: " NETIP "192.168.1.100"
        f_getvar "Specify netmask [255.255.255.0]: " NETMASK "255.255.255.0"
        f_getvar "Specify default gateway [192.168.1.1]: " NETGATEWAY "192.168.1.1"
        f_getvar "Specify DNS server [8.8.8.8]: " NETDNS "8.8.8.8"
        f_getvar "Specify secondary DNS server [8.8.4.4]: " NETDNS2 "8.8.4.4"
        f_getvar "Specify domain name [securix.local]: " NETDOMAIN "securix.local"
        f_getvar "Specify primary NTP server [0.gentoo.pool.ntp.org]" NETNTP "0.gentoo.pool.ntp.org"
        f_getvar "Specify secondary NTP server [1.gentoo.pool.ntp.org]" NETNTP2 "1.gentoo.pool.ntp.org"
    fi
fi

# setup disk encryption
f_msg warn "-- Do you want setup full disk encryption (LUKS)?"
f_msg warn "-- If so, you need physical or console access every time when server will be rebooted."
f_yesno "Are you OK with that?" USELUKS

# create partitions
f_msg info "-- We must setup partitions. All data on destination device will be deleted!!"
f_getvar "Please specify device which should be used for Securix installation [default: /dev/sda]: " device "/dev/sda"

echo "--- Selected device: ${device}"

if [ ! -b "${device}" ]; then
    f_msg error "Error: ${device} is not block device"
    exit_on_error
fi

f_msg info "### Is it this one?"
echo "---"
fdisk -l $device | grep -E "Disk|${device}"
echo "---"

f_yesno "WARNING: ALL DATA WILL BE LOST! Are you OK with that?" DELETEDISK
if [ "$DELETEDISK" = "no" ]; then
    echo "Exiting before disk format..."
    exit_on_error
fi

f_msg info "###-### Step: Sizing swap ---"
MEMSIZE=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ $MEMSIZE -ne $MEMSIZE 2>/dev/null ]; then
    echo "MEMSIZE is not integer, value: ${MEMSIZE}"
    exit_on_error
fi

SWAPCOUNT=$((MEMSIZE * 2))
if [ $SWAPCOUNT -lt 4200000 ]; then
    PSWAPS="+2G"
    SWAPSIZE=2048000000
elif [ $SWAPCOUNT -ge 4200000 ] && [ $SWAPCOUNT -le 8200000 ]; then
        PSWAPS="+4G"
        SWAPSIZE=4096000000
    elif [ $SWAPCOUNT -gt 8200000 ]; then
            PSWAPS="+8G"
            SWAPSIZE=8192000000
fi

f_msg info "###-### Step: Sizing logical volumes ---"
DISKSIZE=$(fdisk -l $device | grep "Disk ${device}" | awk '{print $5}')
if [ $DISKSIZE -ne $DISKSIZE 2>/dev/null ]; then
    echo "DISKSIZE is not integer, value: ${DISKSIZE}"
    exit_on_error
fi

DISKSIZE=$((DISKSIZE - SWAPSIZE))

if [ $DISKSIZE -lt $DISKMIN ]; then
    VOLUMES="NOVOLUMES"
    ROOTTYPE="83"
    USELVM="no"
elif [ $DISKSIZE -ge $DISKMIN ] && [ $DISKSIZE -le $DISKOPTIM ]; then
        VOLUMES="MINVOLUMES"
        ROOTTYPE="8e"
        USELVM="yes"
    elif [ $DISKSIZE -gt $DISKOPTIM ]; then
            VOLUMES="OPTIMVOLUMES"
            ROOTTYPE="8e"
            USELVM="yes"
fi

f_msg info "###-### Step: Deleting partitions ---"
# fix bug when kernel uses old table
cat > fdisk.in << !EOF
o
w
!EOF

bash -c "fdisk $device < fdisk.in" >> $LOGFILE 2>&1

# setup config for fdisk
cat > fdisk.in << !EOF
n
p
1

$PBOOTS
n
p
2

$PSWAPS
t
2
82
n
p
3

t
3
$ROOTTYPE

w
q
!EOF

f_msg info "###-### Step: Creating partitions ---"
bash -c "fdisk $device < fdisk.in" >> $LOGFILE 2>&1
# wait for successful disk sync
sleep 3
DISKSYNC="ok"

f_msg info "###-### Step: Creating boot and swap filesystems ---"
mkfs.ext2 -q ${device}1
mkswap ${device}2 > /dev/null
swapon ${device}2

if [ "$USELUKS" = "yes" ]; then
    f_msg warn "--- Encrypting disk, please save your passphrase on secure place!"
    f_msg warn "--- Use KeePass or something else, because when you forget passphrase NOBODY will be able to recover data!"
    f_msg warn "--- Type YES if youre OK with that"
    cryptsetup -c aes-xts-plain -y -s 512 -h whirlpool luksFormat ${device}3
    f_msg warn "--- Type selected passphrase again to open encrypted partition"
    cryptsetup luksOpen ${device}3 root
    ROOTPV="/dev/mapper/root"
    MAPPER="/dev/mapper/vg-"
    GENKERNEL="${GENKERNEL} --luks"
    GENKERNELUSE="${GENKERNELUSE} cryptsetup"
    SYSTEMPACKAGE="${SYSTEMPACKAGE} cryptsetup"
else
    ROOTPV="${device}3"
    MAPPER="/dev/vg/"
fi

case $VOLUMES in
    NOVOLUMES)
        f_msg info "###-### Step: Creating root filesystem ---"
        mkfs.ext4 -q ${ROOTPV}
        ROOTVG="${ROOTPV}"
        f_msg info "###-### Step: Mounting partitions ---"
        mount ${ROOTVG} /mnt/gentoo
        mkdir /mnt/gentoo/boot
        mount ${device}1 /mnt/gentoo/boot
        ;;
    MINVOLUMES)
        f_msg info "###-### Step: Creating logical volumes ---"
        pvcreate -ff -y ${ROOTPV}
        vgcreate vg ${ROOTPV}
        lvcreate --size 1G --name root vg
        lvcreate --size 5G --name usr vg
        lvcreate --size 2G --name home vg
        lvcreate --size 5G --name var vg
        lvcreate --size 1G --name opt vg
        lvcreate --size 1G --name tmp vg
        vgchange -ay
        ROOTVG="${MAPPER}root"
        ;;
    OPTIMVOLUMES)
        f_msg info "###-### Step: Creating logical volumes ---"
        pvcreate -ff -y ${ROOTPV}
        vgcreate vg ${ROOTPV}
        lvcreate --size 3G --name root vg
        lvcreate --size 10G --name usr vg
        lvcreate --size 5G --name home vg
        lvcreate --size 10G --name var vg
        lvcreate --size 5G --name opt vg
        lvcreate --size 2G --name tmp vg
        vgchange -ay
        ROOTVG="${MAPPER}root"
        ;;
    *)
        f_msg error "Problem when setup volumes, value: ${VOLUMES}"
        exit_on_error
        ;;
esac

if [ "$USELVM" = "yes" ]; then
    GENKERNEL="${GENKERNEL} --lvm"
    SYSTEMPACKAGE="${SYSTEMPACKAGE} lvm2"
    f_msg info "###-### Step: Creating filesystems on logical volumes ---"
    for volumes in root usr home var opt tmp; do
        echo "  Creating ext4 on ${MAPPER}${volumes}"
        mkfs.ext4 -q ${MAPPER}${volumes}
    done
    f_msg info "###-### Step: Mounting logical volumes ---"
    mount ${ROOTVG} /mnt/gentoo
    mkdir /mnt/gentoo/boot
    mount ${device}1 /mnt/gentoo/boot
    for mountpoint in usr home opt var tmp; do
        mkdir /mnt/gentoo/${mountpoint}
        mount ${MAPPER}${mountpoint} /mnt/gentoo/${mountpoint}
    done
fi

# changing context
cd /mnt/gentoo

# download stage3 and portage
f_msg info "###-### Step: Downloading hardened stage ---"
f_download ${SX_STAGE3BASEURL}${STAGE3LATESTTXT} ${STAGE3BASEURL}${STAGE3LATESTTXT}

# find path to latest stage3
STAGE3LATESTFILE=$(grep -v '#' ${STAGE3LATESTTXT})
# and download it
f_download ${SX_STAGE3BASEURL}${STAGE3LATESTFILE} ${STAGE3BASEURL}${STAGE3LATESTFILE}
statusd=$?
f_download ${SX_STAGE3BASEURL}${STAGE3LATESTFILE}.DIGESTS ${STAGE3BASEURL}${STAGE3LATESTFILE}.DIGESTS
f_download ${SX_STAGE3BASEURL}${STAGE3LATESTFILE}.DIGESTS.asc ${STAGE3BASEURL}${STAGE3LATESTFILE}.DIGESTS.asc

# initiate GPG environment
f_download ${SECURIXFILES}/certificates/gentoo-gpg.pub ${SECURIXFILESDR}/certificates/gentoo-gpg.pub
f_download ${SECURIXFILES}/certificates/gentoo-gpg.pub ${SECURIXFILESDR}/certificates/gentoo-gpg-autobuild.pub
mkdir /etc/portage/gnupg
chown 600 /etc/portage/gnupg
GNUPGHOME="/etc/portage/gnupg" gpg --import gentoo-gpg.pub
GNUPGHOME="/etc/portage/gnupg" gpg --fingerprint 0x96D8BF6D
GNUPGHOME="/etc/portage/gnupg" gpg -u 0x96D8BF6D --verify ${STAGE3LATESTFILE}.DIGESTS.asc
if [ $? -ne 0 ]; then
    f_msg error "Gentoo GPG signature of stage3 file do not match !!"
    exit_on_error
fi

# check SHA512
STAGE3SUM=$(sha512sum ${STAGE3LATESTFILE##*/})
grep ${STAGE3SUM} ${STAGE3LATESTFILE##*/}.DIGESTS >/dev/null
statusc=$?
if [ $statusd -ne 0 -o $statusc -ne 0 ]; then
    f_msg error "ERROR: There was problem with download or checksum of stage3 file. Exit codes: "
    f_msg warn "download: ${statusd} checksum: ${statusc}"
    exit_on_error
else
    echo "-- SHA512 checksum: OK"
fi

f_msg info "###-### Step: Extracting stage ---"
tar xjpf stage3-*.tar.bz2 --checkpoint=.1000
echo " DONE"
rm -f stage3-*.tar.bz2 ${STAGE3LATESTTXT} *.DIGESTS *.CONTENTS

f_msg info "###-### Step: Downloading Portage ---"
f_download ${SX_PORTAGEFILE} ${PORTAGEFILE}
statusd=$?
f_download ${SX_PORTAGEFILE}.md5sum ${PORTAGEFILE}.md5sum
f_download ${SX_PORTAGEFILE}.gpgsig ${PORTAGEFILE}.gpgsig
GNUPGHOME="/etc/portage/gnupg" gpg -u 0x2D182910 --verify ${SX_PORTAGEFILE##*/}.gpgsig
if [ $? -ne 0 ]; then
    f_msg error "Gentoo GPG signature of Portage file do not match !!"
    exit_on_error
fi


# check MD5
md5sum --status -c ${SX_PORTAGEFILE##*/}.md5sum
statusc=$?
if [ $statusd -ne 0 -o $statusc -ne 0 ]; then
    f_msg error "ERROR: There was problem with download or checksum of Portage. Exit codes: "
    f_msg warn "download: ${statusd} checksum: ${statusc}"
    exit_on_error
else
    echo "-- MD5 checksum: OK"
fi

f_msg info "###-### Step: Extracting Portage ---"
tar xmjf ${SX_PORTAGEFILE##*/} -C /mnt/gentoo/usr --checkpoint=.1000
echo " DONE"
rm -f ${SX_PORTAGEFILE##*/} *.md5sum

f_msg info "###-### Step: Downloading Securix system configuration ---"
f_download ${SECURIXFILES}/install/conf.tar.gz ${SECURIXFILESDR}/install/conf.tar.gz

f_msg info "###-### Step: Downloading CHROOT script ---"
f_download ${SECURIXFILES}/install/chroot.sh ${SECURIXFILESDR}/install/chroot.sh

f_msg info "###-### Step: Downloading hardened kernel config ---"
if [ "$VIRTUAL" != "yes" ]; then
    GENKERNEL="${GENKERNEL} --menuconfig"
fi

SX_KERNEL="kernel/hardened-${ARCH}.config"
f_download ${SECURIXFILES}/install/${SX_KERNEL} ${SECURIXFILESDR}/install/${SX_KERNEL}
mv ${SX_KERNEL##*/} hardened-kernel.config

f_msg info "###-### Step: Downloading SHA512 list ---"
f_download ${SECURIXFILES}/install/sha512.hash ${SECURIXFILESDR}/install/sha512.hash
f_download ${SECURIXFILES}/install/sha512.hash.sign ${SECURIXFILESDR}/install/sha512.hash.sign

f_msg info "###-### Step: Computing checksum ---"
grep -E 'chroot.sh|conf.tar.gz' sha512.hash > checksum
shasum -a 512 -c checksum >/dev/null
if [ $? -eq 0 ]; then
    f_msg info "--- SHA512 checksum: OK"
    rm -f checksum
else
    f_msg error "--- Problem when computing checksum of Securix files!!"
    grep -E 'chroot.sh|conf.tar.gz' sha512.list && shasum -a 512 chroot.sh conf.tar.gz
    exit_on_error
fi

f_msg info "###-### Step: Verifying Securix files signature ---"
f_download ${SECURIXFILES}/certificates/securix-codesign.pub ${SECURIXFILESDR}/certificates/securix-codesign.pub
openssl dgst -sha512 -verify securix-codesign.pub -signature sha512.hash.sign sha512.hash

f_msg info "###-### Step: Configuring base system ---"
# /etc/make.conf
cat > /mnt/gentoo/etc/make.conf << !EOF

#: title: Securix GNU/Linux make.conf
#: file: /etc/make.conf
#: author: Martin Cmelik (cm3l1k1) - securix.org, security-portal.cz
#
# Please consult /usr/share/portage/config/make.conf.example for a more
# detailed example.

ACCEPT_KEYWORDS="$ARCH"
CFLAGS="-march=native -O2 -fforce-addr -pipe"
CXXFLAGS="\${CFLAGS}"
CHOST="$CHOSTS"
MAKEOPTS="-j${MOPTS}"
USE="-X -kde -gnome -qt4 -gtk -suid -jit hardened pic pax_kernel chroot secure-delete ncurses symlink bash-completion ldap gnutls ssl crypt tcpd pam xml perl python snmp unicode jpeg png vim-syntax mmx readline"
FEATURES="sandbox sfperms strict buildpkg userfetch parallel-fetch"
LINGUAS="en"
CONFIG_PROTECT="/etc"
GENTOO_MIRRORS="${GMIRROR}"
PORTAGE_NICENESS=10
# this option will unmask packages automatically, use with caution
#EMERGE_DEFAULT_OPTS="--autounmask-write"
#PORTAGE_RSYNC_EXTRA_OPTS="--quiet"

!EOF

# set http_proxy if used
if [ ! -z "$http_proxy" ]; then
    echo "# user proxy setup is done by /etc/profile.d/sx-proxy.sh" >> /mnt/gentoo/etc/make.conf
    echo "http_proxy=\"${http_proxy}\"" >> /mnt/gentoo/etc/make.conf
    echo "https_proxy=\"${http_proxy}\"" >> /mnt/gentoo/etc/make.conf
    echo "ftp_proxy=\"${http_proxy}\"" >> /mnt/gentoo/etc/make.conf
    echo "RSYNC_PROXY=\"${http_proxy}\"" >> /mnt/gentoo/etc/make.conf
fi

# DNS
if [ ! -z "$NETDNS" ]; then
    echo "domain ${NETDOMAIN}" > /etc/resolv.conf
    echo "nameserver ${NETDNS}" >> /etc/resolv.conf
    echo "nameserver ${NETDNS2}" >> /etc/resolv.conf
    cp -L /etc/resolv.conf /mnt/gentoo/etc/
else
    cp -L /etc/resolv.conf /mnt/gentoo/etc/
fi

# hostname
cat > /mnt/gentoo/etc/conf.d/hostname << !EOF
hostname="${SECURIX_HOSTNAME}"
!EOF

cat >> /mnt/gentoo/etc/hosts << !EOF
${NETIP} ${SECURIX_HOSTNAME}
!EOF

# /etc/securix-release
cat > /mnt/gentoo/etc/securix-release << !EOF
Securix GNU/Linux - secured linux by default
www.securix.org
SECURIXVERSION=""
!EOF

# /etc/fstab
if [ "$USELVM" = "no" ]; then
    cat > /mnt/gentoo/etc/fstab << !EOF
${device}1		/boot		ext2		${BOOTOPTS}	1 2
${ROOTPV}		/		ext4		${ROOTOPTS}	0 1
${device}2		none		swap		sw		0 0
/dev/cdrom		/mnt/cdrom	auto		noauto,ro	0 0

proc                    /proc           proc            defaults        0 0
!EOF
else
    cat > /mnt/gentoo/etc/fstab << !EOF
${device}1		/boot		 ext2		${BOOTOPTS}	1 2
${MAPPER}root 	        /		 ext4		${ROOTOPTS}	0 1
${device}2		none		 swap		sw		0 0
/dev/cdrom		/mnt/cdrom	 auto		noauto,ro	0 0
# Logical volumes
${MAPPER}usr            /usr             ext4           ${USROPTS}      0 2
${MAPPER}home           /home            ext4           ${HOMEOPTS}     0 2
${MAPPER}var            /var             ext4           ${VAROPTS}      0 2
${MAPPER}opt            /opt             ext4           ${OPTOPTS}      0 2
${MAPPER}tmp            /tmp             ext4           ${TMPOPTS}      0 2

tmpfs                   /var/tmp/portage tmpfs          ${PORTAGEOPTS}  0 0

proc                    /proc            proc           defaults        0 0
!EOF
fi

# Network - /etc/conf.d/net
if [ "$BONDING" = "no" ]; then

    if [ "$USEDHCP" = "yes" ]; then
        cat > /mnt/gentoo/etc/conf.d/net << EOF
config_${NETETH}="dhcp"
EOF
    else
        cat > /mnt/gentoo/etc/conf.d/net << EOF
config_${NETETH}="${NETIP} netmask ${NETMASK}"
routes_${NETETH}="default via ${NETGATEWAY}"
EOF
    fi
fi
if [ "$BONDING" = "yes" ]; then

    if [ "$USEDHCP" = "yes" ]; then
        cat >> /mnt/gentoo/etc/conf.d/net << !EOF
config_eth0="null"
config_eth1="null"
slaves_bond0="eth0 eth1"
mode_bond0="1"
miimon_bond0="100"
config_bond0="dhcp"
!EOF
    else
        for slave in $BONDINGSLAVE; do
            echo "config_${slave}=\"null\"" >> /mnt/gentoo/etc/conf.d/net
        done
        cat >> /mnt/gentoo/etc/conf.d/net << !EOF
slaves_${NETETH}="${BONDINGSLAVE}"
mode_${NETETH}="${BONDINGMODE}"
miimon_${NETETH}="100"
config_${NETETH}="${NETIP} netmask ${NETMASK}"
routes_${NETETH}="default gw ${NETGATEWAY}"
!EOF
    fi
fi

# define NETIP for fail2ban
if [ -z "$NETIP" ]; then
    NETIP=$(ifconfig -a | grep inet | grep -v "127.0.0.1" | awk '{ print $2 }')
    f_validip "${NETIP}"
    if [ "$VALIDIP" != "yes" ]; then
        unset NETIP
    fi  
fi
    
# mounting proc and dev
mount -t proc none /mnt/gentoo/proc
mount --rbind /dev /mnt/gentoo/dev

# chroot variables
cat > /mnt/gentoo/chroot.var << !EOF
ROOT_PASSWORD="${ROOT_PASSWORD}"
ROOT_MAIL="${ROOT_MAIL}"
MAIL_HOST="${MAIL_HOST}"
USER_PASSWORD="${USER_PASSWORD}"
NETETH="${NETETH}"
NETIP="${NETIP}"
device="${device}"
KERNELPATH="${KERNELPATH}"
http_proxy="${http_proxy}"
ARCH="${ARCH}"
ROOTPV="${ROOTPV}"
USELVM="${USELVM}"
USELUKS="${USELUKS}"
GENKERNEL="${GENKERNEL}"
MAPPER="${MAPPER}"
SYSTEMPACKAGE="${SYSTEMPACKAGE}"
MOPTS="${MOPTS}"
USESERIAL="${USESERIAL}"
GRUBOPTS="${GRUBOPTS}"
BONDING="${BONDING}"
NETNTP="${NETNTP}"
NETNTP2="${NETNTP2}"
SECURIXID="${SECURIXID}"
SECURIX_HOSTNAME="${SECURIX_HOSTNAME}"
VIRTUAL="${VIRTUAL}"
VIRTUALHOST="${VIRTUALHOST}"
!EOF

# execute chroot script
f_msg info "###-### Step: Entering CHROOT environment ---"
screen chroot /mnt/gentoo/ /bin/bash chroot.sh
f_msg info "###-### Step: Exiting CHROOT environment ---"

# check chroot status
if [ ! -f $CHROOTOK ]; then
    f_msg error "CHROOT script didnt end successfully..."
    exit_on_error
else
    rm -f $CHROOTOK
    rm -f chroot.sh
    rm -f $LOCKFILE
    rm -f sha512.hash
    rm -f sha512.hash.sign
    rm -f securix-codesign.pub
    rm -f gentoo-gpg.pub
fi

# umounting filesystems
f_msg info "###-### Step: Umounting filesystems ---"
cd

if [ "$USELVM" = "yes" ]; then
    for partitions in usr home opt var tmp; do
        umount ${MAPPER}${partitions}
    done
    umount -l /mnt/gentoo{/boot,/proc,}
    vgchange -a n
else
    umount -l /mnt/gentoo{/boot,/proc,}
fi

if [ "$USELUKS" = "yes" ]; then
    cryptsetup luksClose root
fi

f_msg newline
f_msg info "#########################################################"
f_msg info "###-### Securix GNU/Linux installation COMPLETED! ###-###"
f_msg info "#########################################################"
f_msg newline
if [ "$VOLUMES" = "OPTIMVOLUMES" ]; then
    f_msg warn "Installer did not use entire disk space. Please resize required partition by \"securix config lvm\""
    f_msg newline
fi
f_msg warn "Don't forget that SSH will listen on port 55522. Use \"ssh securix@${SECURIX_HOSTNAME} -p 55522\" (root CANT login via SSH)."
f_msg warn "Installer created user \"securix\" with password \"${USER_PASSWORD}\" who can SSH to server and make \"su -\" to switch under root."
f_msg newline
f_msg info "You can REBOOT to your new system. Visit www.securix.org for next steps."

exit
exit_on_error

