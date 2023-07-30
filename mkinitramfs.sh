#!/bin/bash

BUILD_PATH=$(pwd)
INITRAMFS_PATH=$BUILD_PATH/initramfs
INIT_SCRIPT=$BUILD_PATH/init
MODULES=$BUILD_PATH/modules.tar.xz
CPIO_ARCHIVE=$BUILD_PATH/initramfs.cpio.xz
#ALPINE vars as ALP
ALP_ARCHIVE=alpine-minirootfs-3.18.2-x86_64.tar.gz
ALP_URL=https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/$ALP_ARCHIVE
ALP_UNUSED_APK="ca-certificates alpine-keys apk-tools"
ALP_USEFUL_APK="bash util-linux"
ALP_EDGETE_APK="kexec-tools"
PATH="/bin:/sbin"

CHROOT="chroot $INITRAMFS_PATH"

# Exit on errors
set -e

source functions.sh

infop "Make clean image"
# make a clean image
umount -Rl $INITRAMFS_PATH/* || /bin/true
rm -rf $INITRAMFS_PATH
mkdir $INITRAMFS_PATH

# Create basic root
basic_root () {
  cd $INITRAMFS_PATH
  
  mkdir --parents ./{usr,bin,dev,etc,lib,lib64,mnt/root,proc,root,sbin,sys,tmp}
  cp $INIT_SCRIPT .
  
  # Make usr looks like root
  cd $INITRAMFS_PATH/usr
  mkdir --parents ./{local,state,share,src}
  for dir in bin lib lib64 sbin
  do
    ln -s ../$dir $dir
  done
  cd ..
  
  # extract modules to /lib/modules
  mkdir ./lib/modules
  tar xpf $MODULES -C lib/modules
}

downtract_alpine () {
  cd $BUILD_PATH

  infop "Downloading alpine minimal rootfs"
  if [[ ! -d $ALP_ARCHIVE ]] ; then
    if ! curl -LO $ALP_URL ; then
      error "Failed to download using curl, check you own curl, check network connection."
      exit 1
    fi
  else
    warning "Alpine rootfs already downloaded"
  fi

  if ! tar -xhf $ALP_ARCHIVE -C $INITRAMFS_PATH; then
    error "Failed to extract kernel"
    exit 1
  fi
}


alp_manage_apk () {
  cd $INITRAMFS_PATH
  
  infop "Set up internet access"
  cp /etc/resolv.conf ./etc/resolv.conf
  
  infop "Add apks"
  $CHROOT apk update
  $CHROOT apk add $ALP_USEFUL_APK
  $CHROOT apk add $ALP_EDGETE_APK --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/
  
  infop "Cleaning unused apk"
  $CHROOT apk del $ALP_UNUSED_APK
}



# extract firmware blob needed
extract_blobs () {
  cd $INITRAMFS_PATH
  
  cp -r /lib/firmware/amdgpu ./lib/firmware
}

# add all scripts in scripts.d into /lib/scripts
install_scripts () {
  cd $INITRAMFS_PATH  
  
  mkdir ./lib/scripts
  cp $BUILD_PATH/scripts.d/* ./lib/scripts/
}

# compile cpio archive
compile_cpio () {
  cd $INITRAMFS_PATH

  rm -f $CPIO_ARCHIVE
  find .  | cpio -ov --format=newc | xz --check=crc32 --lzma2=dict=512KiB -ze -9 -T$(nproc) > $CPIO_ARCHIVE

}

basic_root
downtract_alpine
alp_manage_apk
extract_blobs
install_scripts
compile_cpio
