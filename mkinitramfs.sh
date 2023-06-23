INITRAMFS_PATH=$1
INIT_SCRIPT=$2

# make a clean image
rm -rf $INITRAMFS_PATH
mkdir $INITRAMFS_PATH

# Create basic root
cd $INITRAMFS_PATH
mkdir --parents ./{bin,dev,etc,lib,lib64,mnt/root,proc,root,sbin,sys}
mknod -m 622 dev/console c 5 1
mknod -m 622 dev/tty0 c 4 1
cp $INIT_SCRIPT .

# add some binaries with busybox
curl https://www.busybox.net/downloads/binaries/1.21.1/busybox-x86_64 -Lo ./bin/busybox
chmod +x ./bin/busybox
cd bin
ln -s busybox cat
ln -s busybox cd
ln -s busybox echo
ln -s busybox ln
ln -s busybox ls
ln -s busybox mkdir
ln -s busybox mount
ln -s busybox rm
ln -s busybox rmdir
ln -s busybox sh
ln -s busybox touch
ln -s busybox vi
cd ..

# compile cpio archive
find . | cpio -ov --format=newc >../initramfz
