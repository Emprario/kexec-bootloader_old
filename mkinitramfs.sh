#!/bin/bash

BUILD_PATH=$(pwd)
INITRAMFS_PATH=$BUILD_PATH/initramfs
INIT_SCRIPT=$BUILD_PATH/init
MODULES=$BUILD_PATH/modules.tar.xz
CPIO_ARCHIVE=$INITRAMFS_PATH/initramfs.cpio

# make a clean image
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
    ln -s ../$dir
  done
  
  # extract modules to /lib/modules
  mkdir ./lib/modules
  cd usr; ln -s ../lib; cd .. # au cas où
  tar xpf $MODULES -C lib/modules
}


# extract firmware blob needed
extract_blobs () {
  cd $INITRAMFS_PATH

  mkdir ./lib/firmware
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

  rm $CPIO_ARCHIVE
  find . | cpio -ov --format=newc > $CPIO_ARCHIVE

}

basic_root
extract_blobs
install_scripts
compile_cpio
