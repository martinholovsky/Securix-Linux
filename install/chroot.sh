#!/bin/bash

#: title: Securix GNU/Linux install script - chroot part
#: file: chroot.sh
#: author: Martin Cmelik (cm3l1k1) - securix.org, security-portal.cz
#: version: 20141123
#
#
# This file is part of Securix GNU/Linux installer.
#
# Securix GNU/Linux is free software: you can redistribute it and/or modify
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

##############################################################################
#
# VARIABLES
#
##############################################################################

CHROOTOK="/chroot.ok"
CHROOTVAR="/chroot.var"
SECURIXVERSION=$(date +%F)
txtred='\e[0;31m'
txtblue='\e[1;34m'
txtgreen='\e[0;32m'
txtwhite='\e[0;37m'
txtdefault='\e[00m'
txtyellow='\e[0;33m'

# Load installer variables
. $CHROOTVAR

##############################################################################
#
# FUNCTIONS
#
##############################################################################

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

f_grep() {
    #example: f_grep " ept " /proc/cpuinfo EPTFLAG
    #if string exist 3rd parameter have value "yes"
    grep ${1} ${2} > /dev/null
    if [ $? -eq 0 ]; then
        export $3="yes"
    else
        export $3="no"
    fi
}

trap exit_on_error 1 2 3 15 ERR

exit_on_error() {
    local exit_status=${1:-$?}
    echo -e "${txtred}»»» Exiting $0 with status: $exit_status ${txtdefault}"
    echo -e "${txtblue} YOU ARE NOW IN DEBUG MODE. Fix issue and type \"exit\" to continue ${txtdefault}"
    echo -e "${txtblue}If problem occur during emerge, try \"emerge --resume\"${txtdefault}"
    /bin/bash # for debug only
    source /chroot.var # as $CHROOTVAR will be unknown
    #exit $exit_status
}

##############################################################################
#
# MAIN
#
##############################################################################

f_msg info "###-### Step: Running CHROOT script ---"

# environment & profile
env-update && source /etc/profile

# locale and UTF-8 terminal
f_msg info "###-### Step: Locale setup ---"
cat > /etc/locale.gen << !EOF
en_US ISO-8859-1
en_US.UTF-8 UTF-8
!EOF
cat > /etc/env.d/02locale << !EOF
LANG="en_US.UTF-8"
!EOF
sed -i 's/unicode=\"NO\"/unicode=\"YES\"/g' /etc/rc.conf
locale-gen

# timezone, GMT everywhere
f_msg info "###-### Step: Timezone setup ---"
cp /usr/share/zoneinfo/GMT /etc/localtime
sed -i 's/clock=\"UTC\"/clock=\"local\"/g' /etc/conf.d/hwclock

# set hostname
f_msg info "###-### Step: Hostname setup ---"
hostname ${SECURIX_HOSTNAME}

# setup networking
f_msg info "###-### Step: Network setup ---"
cd /etc/init.d
ln -s net.lo net.${NETETH}
rc-update add net.${NETETH} default

# setup root pasword
f_msg info "###-### Step: Root password ---"
passwd << EOF 2>/dev/null
$ROOT_PASSWORD
$ROOT_PASSWORD
EOF

# select hardened profile
f_msg info "###-### Step: Hardened profile ---"
PROFILE=$(eselect profile list | grep -vE "selinux|no-multilib|uclibc|x32|musl" | grep hardened | cut -d"[" -f2 | cut -d"]" -f1)
eselect profile set $PROFILE
if [ $? -ne 0 ]; then
    f_msg error "ERROR: There seems to be problem when setup hardened profile"
    exit_on_error
fi
env-update && source /etc/profile

# accept keywords
if [ ! -d /etc/portage/ ]; then
    mkdir /etc/portage/
fi
cat > /etc/portage/package.accept_keywords << !EOF
app-admin/paxtest
app-forensics/unhide
!EOF

# package mask
#cat > /etc/portage/package.mask << !EOF
#>=sys-kernel/hardened-sources-3
#!EOF

# package use
cat > /etc/portage/package.use << !EOF
sys-fs/cryptsetup gcrypt
sys-fs/lvm2 -thin
sys-process/lsof rpc
sys-kernel/genkernel-next ${GENKERNELUSE}
!EOF

# kernel setup
f_msg info "###-### Step: Emerging Hardened sources ---"
emerge --quiet udev hardened-sources genkernel-next ${SYSTEMPACKAGE}
eselect news read --quiet

f_msg info "###-### Step: Compiling hardened kernel ---"
KERNEL=$(ls /usr/src/ | grep hardened)
# replacing tux with Securix mascot
cd / && tar xzf conf.tar.gz --no-anchored logo_linux_clut224.ppm
chown root.root /usr/share/securix/logo_linux_clut224.ppm
cp /usr/share/securix/logo_linux_clut224.ppm /usr/src/linux/drivers/video/logo/

# adding grsec option when running under VM
if [ ! -z $VIRTUALHOST -a $VIRTUAL = "yes" ]; then
    f_msg info "-- adding grsec options for VM ${VIRTUALHOST}"
    echo "CONFIG_GRKERNSEC_CONFIG_VIRT_${VIRTUALHOST}=y" >> hardened-kernel.config
    echo "CONFIG_GRKERNSEC_CONFIG_VIRT_GUEST=y" >> hardened-kernel.config
    f_grep " ept " /proc/cpuinfo EPTFLAG
    if [ "$EPTFLAG" = "yes" ]; then
        f_msg info "-- adding EPT (Extended Page Table) because your CPU supports it"
        echo "CONFIG_GRKERNSEC_CONFIG_VIRT_EPT=y" >> hardened-kernel.config
    else
        echo "CONFIG_GRKERNSEC_CONFIG_VIRT_SOFT=y" >> hardened-kernel.config
    fi
else
    echo "CONFIG_GRKERNSEC_CONFIG_VIRT_NONE=y" >> hardened-kernel.config
fi

# generate kernel
genkernel $GENKERNEL all
mv hardened-kernel.config /etc/kernels/hardened-kernel.config

# emerge system applications
f_msg info "###-### Step: Emerging system applications ---"
emerge --quiet portage openssh syslog-ng vixie-cron dhcpcd logrotate openntpd \
sys-boot/grub:0 iptables pam mailx smartmontools ssmtp fail2ban

rc-update add sshd default
rc-update add syslog-ng default
rc-update add vixie-cron default
rc-update add ntpd default
rc-update add iptables boot
rc-update add fail2ban default

if [ "$USELVM" = "yes" ]; then
    rc-update add lvm boot
    rc-update add lvm-monitoring default
fi

# rebuild toolchain
f_msg info "###-### Step: Rebuilding Toolchain ---"

emerge --quiet --oneshot gcc
# select newer GCC
GCCCONFIG=$(gcc-config -l | grep -vE '\*|hardened|vanilla' | cut -d"[" -f2 | cut -d"]" -f1)
if [ ! -z "$GCCCONFIG" ]; then
    gcc-config ${GCCCONFIG}
fi
# select newer Python
PYTHONCONFIG=$(eselect python list | grep 'python3.2' | cut -d"[" -f2 | cut -d"]" -f1)
if [ ! -z "$PYTHONCONFIG" ]; then
    eselect python set ${PYTHONCONFIG}
    python-updater
fi
emerge --quiet --oneshot binutils virtual/libc bash

# install other useful software
f_msg info "###-### Step: Emerging useful software ---"
emerge --quiet openrc openssl gradm paxtest paxctl pax-utils gentoolkit sudo \
htop tcpdump lsof rkhunter tcptraceroute strace app-misc/mc dmidecode zip ftp \
ethtool net-tools iproute2 mirrorselect net-misc/telnet-bsd app-misc/screen \
whois bind-tools app-crypt/gnupg iftop netcat colordiff unhide scrub pwgen \
pyinotify traceroute wget

revdep-rebuild --quiet

# setup serial
if [ "$USESERIAL" = "yes" ]; then
    f_msg info "###-### Step: Setting Serial ---"
    SERIALDEV=$(setserial -g /dev/ttyS[0123] | grep -v unknown | cut -d',' -f1 | head -n 1)
    SERIALTTY=${SERIALDEV##*/}
    if [ ! -z $SERIALDEV ]; then
        f_msg info "-- setting ${SERIALDEV} 9600bps vt100"
        echo "# SERIAL CONSOLE" >> /etc/inittab
        echo "s0:12345:respawn:/sbin/agetty -L -f /etc/issueserial 9600 ${SERIALTTY} vt100" >> /etc/inittab
        echo "${SERIALTTY}" >> /etc/securetty
        #GRUBOPTS="console=${SERIALTTY},9600 ${GRUBOPTS}"
    else
        f_msg warn "Problem with serial found. Serial device detected: ${SERIALDEV}, tty: ${SERIALTTY}"
    fi
fi

# Check SMART capability
f_msg info "###-### Step: Checking for S.M.A.R.T. capability ---"
DISKTYPE=$(smartctl --scan | grep ${device} | cut -d' ' -f3)
SMARTSTATUS=$(smartctl -i -d ${DISKTYPE} ${device})
if [[ "$SMARTSTATUS" =~ "SMART support is: Available" ]]; then
    f_msg info "--- Device ${device} support S.M.A.R.T."
    smartctl -s on -d ${DISKTYPE} ${device}
    sed -i 's/^DEVICESCAN/#DEVICESCAN/g' /etc/smartd.conf
    # monitor disk and run short self-test every day at 2AM, long test on Sunday at 4AM
    echo "${device} -d ${DISKTYPE} -a -I 194 -W 4,45,60 -R 5 -s (S/../.././02|L/../../7/04) -m root" >> /etc/smartd.conf
    SMARTSUPPORT="yes"
    rc-update add smartd default
    f_msg info "--- S.M.A.R.T. enabled and monitoring has been setup"
else
    f_msg info "--- Device ${device} doesnt support S.M.A.R.T."
    SMARTSUPPORT="no"
fi

# setup grub
f_msg info "###-### Step: Setting Grub ---"

KERNELIMG=$(ls /boot | grep kernel | grep securix)
INITRAMIMG=$(ls /boot | grep initramfs | grep securix)

cat > /boot/grub/grub.conf << !EOF
# info: Securix GNU/Linux grub.conf
# file: /boot/grub/grub.conf
# default password is securix_boot
# generate own hash by grub-md5-crypt or "securix config grub"

default 0
fallback 1
timeout 15
splashimage=(hd0,0)/grub/securix-splash.xpm.gz
password --md5 \$1\$Ul0TR0\$fK/7jE2gCbkBAnzBQWWYf/

title Securix GNU/Linux ${SECURIXVERSION}
root (hd0,0)
!EOF

if [ "$USELVM" = "yes" -a "$USELUKS" = "yes" ]; then
cat >> /boot/grub/grub.conf << !EOF
kernel (hd0,0)/${KERNELIMG} root=/dev/ram0 init=/linuxrc ramdisk=8192 crypt_root=${device}3 real_root=${MAPPER}root dolvm ${GRUBOPTS}
initrd (hd0,0)/${INITRAMIMG}
!EOF
fi

if [ "$USELVM" = "yes" -a "$USELUKS" = "no" ]; then
cat >> /boot/grub/grub.conf << !EOF
kernel (hd0,0)/${KERNELIMG} root=${MAPPER}root dolvm ${GRUBOPTS}
initrd (hd0,0)/${INITRAMIMG}
!EOF
fi

if [ "$USELVM" = "no" -a "$USELUKS" = "yes" ]; then
cat >> /boot/grub/grub.conf << !EOF
kernel (hd0,0)/${KERNELIMG} root=/dev/ram0 init=/linuxrc ramdisk=8192 crypt_root=${device}3 real_root=${ROOTPV} ${GRUBOPTS}
initrd (hd0,0)/${INITRAMIMG}
!EOF
fi

if [ "$USELVM" = "no" -a "$USELUKS" = "no" ]; then
cat >> /boot/grub/grub.conf << !EOF
kernel (hd0,0)/${KERNELIMG} root=${device}3 ${GRUBOPTS}
!EOF
fi

grep -v rootfs /proc/mounts > /etc/mtab
grub-install --no-floppy $device


# Securix system configuration
f_msg info "###-### Step: Securix system configuration & hardening ---"
groupadd -g 111 admin
groupadd -g 222 operator
groupadd -g 333 service
groupadd -g 444 sshusers
groupadd -g 555 no-motd
mkdir /etc/securix
mkdir /tmp/securix-conf
mkdir /var/securix
tar xzf /conf.tar.gz -C /tmp/securix-conf/
cp -rf /tmp/securix-conf/* /
rm -f /conf.tar.gz

# set chmod for securix scripts
chmod 0755 /usr/sbin/securix*
chmod -R 0600 /etc/securix
chmod -R 0665 /var/securix

# make securix cron symlink
for sx in hourly daily weekly monthly; do
    ln -s /usr/sbin/securix-cron /etc/cron.${sx}/sx-cron
done

# set SECURIXID
sed -i "/SECURIXID=/ c SECURIXID=\"${SECURIXID}\"" /usr/sbin/securix-functions

# setup GPG check of Gentoo Portage tarball sign
mkdir -p /etc/portage/gnupg
chmod 0700 /etc/portage/gnupg

# import Gentoo GPG key
f_msg info "###-### Step: Importing Gentoo GPG key ---"
#GNUPGHOME="/etc/portage/gnupg" gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 0x96D8BF6D
GNUPGHOME="/etc/portage/gnupg" gpg --import /usr/share/securix/gentoo-gpg.pub
GNUPGHOME="/etc/portage/gnupg" gpg --fingerprint 0x96D8BF6D
echo "PORTAGE_GPG_DIR=\"/etc/portage/gnupg\"" >> /etc/portage/make.conf
sed -i 's/USE\=\"/USE\=\"webrsync-gpg /g' /etc/portage/make.conf

# import Securix GPG key
#f_msg info "###-### Step: Importing Securix GPG key ---"
#GNUPGHOME="/etc/portage/gnupg" gpg --import /usr/share/securix/securix-gpg.pub
#GNUPGHOME="/etc/portage/gnupg" gpg --fingerprint 0x468388F3

# checksec.sh
chmod u+x /usr/local/bin/checksec.sh

# iptables
chmod u+x /etc/conf.d/iptables.rules

# disable "Three Finger Salute"
sed -i 's/ca\:12345/\#ca\:12345/g' /etc/inittab

# Genkernel
sed -i "/SYMLINK=/ c SYMLINK=\"yes\"" /etc/genkernel.conf
sed -i "/BOOTLOADER=/ c BOOTLOADER=\"grub\"" /etc/genkernel.conf
sed -i "/KNAME=/ c KNAME=\"securix\"" /etc/genkernel.conf
sed -i "/SAVE_CONFIG=/ c SAVE_CONFIG=\"yes\"" /etc/genkernel.conf
sed -i "/MOUNTBOOT=/ c MOUNTBOOT=\"yes\"" /etc/genkernel.conf
sed -i "/MAKEOPTS=/ c MAKEOPTS=\"-j${MOPTS}\"" /etc/genkernel.conf
sed -i "/LUKS=/ c LUKS=\"${USELUKS}\"" /etc/genkernel.conf
sed -i "/LVM=/ c LVM=\"${USELVM}\"" /etc/genkernel.conf

# Fail2Ban
if [ ! -z "$NETIP" ]; then
    sed -i "/ignoreip =/ c ignoreip = 127.0.0.1/8 \"${NETIP}\"" /etc/fail2ban/jail.local
fi

cp /etc/genkernel.conf /etc/genkernel.conf.bak

# NTP servers
if [ ! -z $NETNTP ]; then
    grep -vE '^server' /etc/ntpd.conf > /etc/ntpd.conf.mv
    mv /etc/ntpd.conf.mv /etc/ntpd.conf
    echo "server ${NETNTP}" >> /etc/ntpd.conf
    echo "server ${NETNTP2}" >> /etc/ntpd.conf
fi

# Set the time immediately at startup
sed -i "/NTPD_OPTS=/ c NTPD_OPTS=\"-s\"" /etc/conf.d/ntpd

# root mail forward
MAILHUB=$(echo $MAIL_HOST | cut -d' ' -f1)
MAILUSER=$(echo $MAIL_HOST | cut -d' ' -f2)
MAILPASS=$(echo $MAIL_HOST | cut -d' ' -f3)

if [ "$ROOT_MAIL" != "root" ]; then
    echo "root: ${ROOT_MAIL}" >> /etc/ssmtp/revaliases
fi
if [ "$MAILHUB" != "mail" ]; then
    sed -i "/^mailhub=/ c mailhub=${MAIL_HOST}" /etc/ssmtp/ssmtp.conf
    echo "AuthUser=${MAILUSER}" >> /etc/ssmtp/ssmtp.conf
    echo "AuthPass=${MAILPASS}" >> /etc/ssmtp/ssmtp.conf
fi

echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf

# UMASK
sed -i 's/umask 022/umask 027/g' /etc/profile
sed -i 's/umask 022/umask 027/g' /etc/bash/bashrc

# profile proxy setup
if [ ! -z "$http_proxy" ]; then
    echo "http_proxy=\"${http_proxy}\"" >> /etc/profile.d/sx-proxy.sh
    echo "https_proxy=\"${http_proxy}\"" >> /etc/profile.d/sx-proxy.sh
    echo "ftp_proxy=\"${http_proxy}\"" >> /etc/profile.d/sx-proxy.sh
    echo "RSYNC_PROXY=\"${http_proxy}\"" >> /etc/profile.d/sx-proxy.sh
fi

# cron
echo "root" >> /etc/cron.allow

# create user securix
f_msg info "###-### Step: Creating securix user ---"
useradd securix -m -G wheel,admin,sshusers
passwd securix << EOF 2>/dev/null
$USER_PASSWORD
$USER_PASSWORD
EOF
chage -d 0 securix

# add portage to trusted group - Grsec
usermod -a -G wheel portage

# update rkhunter data file
f_msg info "###-### Step: Creating rkhunter data file ---"
# create tmp dir
if [ ! -d "/var/lib/rkhunter/tmp" ]; then
    mkdir "/var/lib/rkhunter/tmp"
fi
rkhunter --propupd

# run once iptables script to generate rules-save
#/etc/conf.d/iptables.rules 2>&1 >/dev/null

# check if portage dir exist, because we will mount tempfs
if [ ! -d /var/tmp/portage ]; then
    mkdir /var/tmp/portage
    chown portage.portage /var/tmp/portage
    echo "--- /var/tmp/portage created"
fi

# --- ALL DONE ---
f_msg info "###-### Step: CHROOT script completed ---"

touch $CHROOTOK
rm -f $CHROOTVAR

exit
exit_on_error
