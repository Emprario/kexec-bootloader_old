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
mknod -m 622 dev/console c 5 1
mknod -m 622 dev/tty0 c 4 1
mknod -m 622 dev/ttyS0 c 4 64
cp $INIT_SCRIPT .

# add some binaries with busybox
curl https://www.busybox.net/downloads/binaries/1.21.1/busybox-x86_64 -Lo ./bin/busybox
chmod +x ./bin/busybox
cd bin
ln -s busybox cat
ln -s busybox cd
ln -s busybox chvt
ln -s busybox clear
ln -s busybox echo
ln -s busybox ln
ln -s busybox ls
ln -s busybox mkdir
ln -s busybox mount
ln -s busybox modprobe
ln -s busybox insmod 
ln -s busybox rm
ln -s busybox rmdir
ln -s busybox sh
ln -s busybox touch
ln -s busybox tty
ln -s busybox vi
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

# compile cpio archive
rm ../$CPIO_ARCHIVE
find . | cpio -ov --format=newc >../$CPIO_ARCHIVE
