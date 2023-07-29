#!/bin/bash

KERNEL_VERSION=6.3.4
KERNEL_SOURCE_URL=https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION::1}.x/linux-$KERNEL_VERSION.tar.xz
KERNEL_SOURCE_NAME=linux-$KERNEL_VERSION
BRD=$(pwd) # BUILD_ROOT_DIRECTORY
KSF=$BRD/linux-$KERNEL_VERSION # KERNEL_SOURCE_FOLDER
MODULES_FOLDER=$KSF/modules
KERNEL_CONFIG=$BRD/kernel.conf
INITRAMFS_NAME=initramfs.cpio

# Exit on errors
set -e

source functions.sh

#Checks if source files already exist
#If not then tries to download tarball with curl
#if curl fails then tries with wget
#if download is successful then extracts tarball
get_kernel_source() {
  cd $BRD

  if [[ ! -d $KSF ]]; then
    infop "Downloading kernel source"
    echo -e "\n"
    if ! curl $KERNEL_SOURCE_URL -o $KERNEL_SOURCE_NAME.tar.xz; then
      error "Failed to download using curl, check you own curl, check network connection."
      exit 1
    fi
    if ! tar -xf $KERNEL_SOURCE_NAME.tar.xz; then
      error "Failed to extract kernel"
      exit 1
    fi

  else
    warning "Kernel already Download!"
  fi
}

#Checks if kernel config file exists
#If not copies the one from $BUILD_ROOT_DIRECTORY
#Runs make olddefconfig to ensure no missing new options are left out of file
#Creates empty initramfs file so kernel will build
setup_kernel_config() {
  cd $KSF
  
  if [[ ! -f ".config" ]]; then
    warning "No existing kernel config, creating config file"
    echo
    cp $KERNEL_CONFIG $KSF/.config
  else
    infop "Kernel config already exists"
  fi

  infop "Running make olddefconfig"
  make olddefconfig
  touch $KSF/$INITRAMFS_NAME # Prevent kernel building errors
}

#Builds clean kernel if "clean" argument is passed
build_kernel() {
  cd $KSF
  
  if [[ $1 == "clean" ]]; then
    infop "Clean Kernel source"
    make clean
  fi
  
  infop "Building Kernel"
  if ! make -j"$(nproc)"; then
    error "Kernel build failed."
    exit 1
  else
    infop "Kernel build completed"
  fi
  #Version of kernel
  KERNEL_STRING=$(file -bL arch/x86/boot/bzImage | grep -o 'version [^ ]*' | cut -d ' ' -f 2)
}

#Installs kernel modules to $MODULES_FOLDER
install_modules() {
  cd $KSF

  #if [  if [[ $(id -u) -eq 0 ]]; then
  #  error "This Function should be run as root"
  #  exit 1
  #fi

  # Create empty module folder
  sudo rm -rf $MODULES_FOLDER
  mkdir $MODULES_FOLDER

  sudo make -j"$(nproc)" modules_install INSTALL_MOD_PATH=$MODULES_FOLDER INSTALL_MOD_STRIP=1

  cd $MODULES_FOLDER/lib/modules
  # Remove broken symlinks
  sudo rm -rf */build
  sudo rm -rf */source

  # Create an archive for the modules
  tar -cvI "xz -9 -T0" -f $BRD/modules.tar.xz *
  infop "Modules archive created."
}

# Launches kernel config graphical editor
# return 1 if something changes 0 else
edit_kernel_config() {
  cd $KSF

  cp .config .config-temp
  make menuconfig
  if [[ $(diff .config .config-temp) ]];then
    rm .config-temp
    DIFF=1
  else
    rm .config-temp
    DIFF=0
  fi
}

create_initramfs() {
  cd $BRD
  
  #if [[ $(id -u) -eq 0 ]]; then
  #  error "This Function shouldn't be run as root"
  #  exit 1
  #fi

  infop "Building initramfs"
  # Generate initramfs from the built modules
  sudo bash mkinitramfs.sh
  cp $INITRAMFS_NAME $KSF
}

#Gets required input from user to run the kernel build.
user_input() {
  cd $BRD

  ask "Would you like to make edits to the kernel config? [y/N]: "
  read -n 1 -r -s response
  echo $response
  echo -e "\n"
  if [[ $response =~ ^[Yy]$ ]]; then
    edit_kernel_config
  fi

  ask "Do you want to perform a clean build?\nThis will generate a new build from the ground up, \nrather than using the previous build. [y/N]: "
  read -n 1 -r -s response
  echo $response
  echo -e "\n"
  if [[ $response =~ ^[Yy]$ ]]; then
    build_kernel clean
  else
    if [[ $DIFF -eq 1 ]];then
      build_kernel
      install_modules
    fi
  fi

}

save_config () {
  cd $KSF
  
  infop "save kenrel configuration"
  cp .config $BRD
}


sudo echo "Grant sudo access !"

get_kernel_source

setup_kernel_config

# Check if running in a terminal and not in a docker container
if [[ -t 0 ]] && [[ ! -f /.dockerenv ]]; then
  user_input
else
  build_kernel
fi

create_initramfs

infop "Building kernel with initramfs"
build_kernel

save_config

# Copy kernel to root
infop "Copying kernel to root."
cp $KSF/arch/x86/boot/bzImage $BRD/bzImage
infop "Build complete!"
