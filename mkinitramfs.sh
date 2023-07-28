#!/bin/bash

BUILD_PATH=$(pwd)
INITRAMFS_PATH=$BUILD_PATH/initramfs
INIT_SCRIPT=$BUILD_PATH/init
MODULES=$BUILD_PATH/modules.tar.xz
CPIO_ARCHIVE=initramfs.cpio
MOD_D=$BUILD_PATH/mod.cfg
LINUX_FIRMWARE=https://cdn.kernel.org/pub/linux/kernel/firmware/linux-firmware-20230625.tar.xz

# make a clean image
rm -rf $INITRAMFS_PATH
mkdir $INITRAMFS_PATH

# Create basic root
cd $INITRAMFS_PATH
mkdir --parents ./{usr,bin,dev,etc,lib,lib64,mnt/root,proc,root,sbin,sys,tmp}
cp $INIT_SCRIPT .

# add some binaries with busybox
curl https://www.busybox.net/downloads/binaries/1.21.1/busybox-x86_64 -Lo ./bin/busybox
chmod +x ./bin/busybox
cd bin
for cmd in "[" "[[" acpid add-shell addgroup adduser adjtimex arp arping ash awk base64 basename beep blkid blockdev bootchartd brctl bunzip2 bzcat bzip2 cal cat catv chat chattr chgrp chmod chown chpasswd chpst chroot chrt chvt cksum clear cmp comm conspy cp cpio crond crontab cryptpw cttyhack cut date dc dd deallocvt delgroup deluser depmod devmem df dhcprelay diff dirname dmesg dnsd dnsdomainname dos2unix du dumpkmap dumpleases echo ed egrep eject env envdir envuidgid ether-wake expand expr fakeidentd false fbset fbsplash fdflush fdformat fdisk fgconsole fgrep find findfs flock fold free freeramdisk fsck fsck.minix fsync ftpd ftpget ftpput fuser getopt getty grep groups gunzip gzip halt hd hdparm head hexdump hostid hostname httpd hush hwclock id ifconfig ifdown ifenslave ifplugd ifup inetd init insmod install ionice iostat ip ipaddr ipcalc ipcrm ipcs iplink iproute iprule iptunnel kbd_mode kill killall killall5 klogd last less linux32 linux64 linuxrc ln loadfont loadkmap logger login logname logread losetup lpd lpq lpr ls lsattr lsmod lsof lspci lsusb lzcat lzma lzop lzopcat makedevs makemime man md5sum mdev mesg microcom mkdir mkdosfs mke2fs mkfifo mkfs.ext2 mkfs.minix mkfs.vfat mknod mkpasswd mkswap mktemp modinfo modprobe more mount mountpoint mpstat mt mv nameif nanddump nandwrite nbd-client nc netstat nice nmeter nohup nslookup ntpd od openvt passwd patch pgrep pidof ping ping6 pipe_progress pivot_root pkill pmap popmaildir poweroff powertop printenv printf ps pscan pstree pwd pwdx raidautorun rdate rdev readahead readlink readprofile realpath reboot reformime remove-shell renice reset resize rev rm rmdir rmmod route rpm rpm2cpio rtcwake run-parts runlevel runsv runsvdir rx script scriptreplay sed sendmail seq setarch setconsole setfont setkeycodes setlogcons setserial setsid setuidgid sh sha1sum sha256sum sha3sum sha512sum showkey slattach sleep smemcap softlimit sort split start-stop-daemon stat strings stty su sulogin sum sv svlogd swapoff swapon switch_root sync sysctl syslogd tac tail tar tcpsvd tee telnet telnetd test tftp tftpd time timeout top touch tr traceroute traceroute6 true tty ttysize tunctl udhcpc udhcpd udpsvd umount uname unexpand uniq unix2dos unlzma unlzop unxz unzip uptime users usleep uudecode uuencode vconfig vi vlock volname wall watch watchdog wc wget which who whoami whois xargs xz xzcat yes zcat zcip
do
    ln busybox $cmd
done
cd ..

# extract modules to /lib/modules
mkdir ./lib/modules
cd usr; ln -s ../lib; cd .. # au cas où
tar xpf $MODULES -C lib/modules

# extract firmware blob needed
mkdir ./lib/firmware
cp -r /lib/firmware/amdgpu ./lib/firmware


#rm -rf /tmp/linux-firmware*
#curl $LINUX_FIRMWARE -Lo /tmp/linux-firmware.tar.xz
#tar xpf /tmp/linux-firmware.tar.xz -C /tmp
#mkdir ./lib/firmware
#cp -r /tmp/linux-firmware-*/* ./lib/firmware 

# add mod.cfg to the initramfs
#cp  $MOD_D ./etc/mod.cfg 

# add all scripts in scripts.d into /lib/scripts
mkdir ./lib/scripts
cp $BUILD_PATH/scripts.d/* ./lib/scripts/


# compile cpio archive
rm ../$CPIO_ARCHIVE
find . | cpio -ov --format=newc >../$CPIO_ARCHIVE
