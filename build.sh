#!/bin/bash

KERNEL_VERSION=6.1
KERNEL_SOURCE_URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.3.4.tar.xz
KERNEL_SOURCE_NAME=linux-$KERNEL_VERSION
BUILD_ROOT_DIRECTORY=$(pwd)
KERNEL_SOURCE_FOLDER=$BUILD_ROOT_DIRECTORY/chromeos-$KERNEL_VERSION
KERNEL_PATCHES=$BUILD_ROOT_DIRECTORY/patches
MODULES_FOLDER=$KERNEL_SOURCE_FOLDER/modules
HEADERS_FOLDER=$KERNEL_SOURCE_FOLDER/headers
KERNEL_CONFIG=$BUILD_ROOT_DIRECTORY/kernel.conf
DRACUT_CONFIG=$BUILD_ROOT_DIRECTORY/dracut.conf
DRACUT_CONFIG_DIR=$BUILD_ROOT_DIRECTORY/dracut.conf.d
INITRAMFS_NAME=initramfs.cpio.zst

# Exit on errors
set -e

#outputs given message and color choice
#First parameter is message to output
#Second parameter is color choice
write_output() {
  case ${2,,} in
  green) # user question
    printf "\e[32m$1\e[0m"
    ;;
  yellow) # non-critical error / warning
    printf "\e[33m$1\e[0m"
    ;;
  red) # critical error -> script will exit
    printf "\e[31m$1\e[0m"
    ;;
  blue) # status update
    printf "\e[34m$1\e[0m"
    ;;
  magenta)
    printf "\e[35m$1\e[0m"
    ;;
  white)
    printf "\e[37m$1\e[0m"
    ;;
  *)
    printf "$1"
    ;;
  esac
}

#Checks if source files already exist
#If not then tries to download tarball with curl
#if curl fails then tries with wget
#if download is successful then extracts tarball
get_kernel_source() {
  if [[ ! -d $KERNEL_SOURCE_FOLDER ]]; then
    write_output "Downloading kernel source" "blue"
    echo -e "\n"
    if ! curl $KERNEL_SOURCE_URL -o $KERNEL_SOURCE_NAME.tar.xz; then
      write_output "Failed to download kernel using curl, trying wget" "yellow"
      echo -e "\n"
      if ! wget $KERNEL_SOURCE_URL; then
        write_output "Failed to download using wget, check network connection." "red"
        echo
        exit 1
      fi
    fi
    if ! tar -xf $KERNEL_SOURCE_FOLDER.tar.xz; then
      write_output "Failed to extract kernel" "red"
      echo
      exit 1
    fi

  else
    write_output "Kernel already cloned!" "yellow"
    echo -e "\n"
  fi

}

#Applies kernel patches stored in $KERNEL_PATCHES
#creates an empty .patches_applied file if patches have already been applied
apply_kernel_patches() {
  cd $KERNEL_SOURCE_FOLDER
  if [[ ! -f "$BUILD_ROOT_DIRECTORY/.patches_applied" ]]; then
    write_output "Applying kernel patches." "blue"
    echo
    echo -e "\e[33m"
    for file in $(ls $KERNEL_PATCHES); do

      if ! patch -p1 <$KERNEL_PATCHES/$file; then
        write_output "Failed to apply patch $file." "red"
        echo
        exit 1
      fi
    done
    echo -e "\e[0m"
    touch $BUILD_ROOT_DIRECTORY/.patches_applied
  else
    write_output "Kernel patches already applied!" "yellow"
    echo
  fi
}

#Checks if kernel config file exists
#If not copies the one from $BUILD_ROOT_DIRECTORY
#Runs make olddefconfig to ensure no missing new options are left out of file
#Creates empty initramfs file so kernel will build
setup_kernel_config() {
  if [[ ! -f ".config" ]]; then
    write_output "No existing kernel config, creating config file" "yellow"
    echo
    cp $KERNEL_CONFIG $KERNEL_SOURCE_FOLDER/.config
  else
    write_output "Kernel config already exists" "blue"
    echo -e "\n"
  fi

  write_output "Running make olddefconfig" "blue"
  echo -e "\n"
  make olddefconfig
  touch $KERNEL_SOURCE_FOLDER/$INITRAMFS_NAME
}

#Builds clean kernel if 1, builds from previous build if 0
build_kernel() {
  cd $KERNEL_SOURCE_FOLDER
  if [[ $1 -eq 0 ]]; then
    write_output "Building using existing build" "blue"
    echo
    if ! make -j"$(nproc)"; then
      write_output "Kernel build failed." "red"
      echo
      exit 1
    else
      write_output "Kernel build completed" "blue"
      echo -e "\n"
    fi
  else
    write_output "Building clean kernel" "blue"
    echo
    make clean
    if ! make -j"$(nproc)"; then
      write_output "Kernel build failed." "red"
      echo
      exit 1
    else
      write_output "Kernel build completed" "blue"
      echo -e "\n"
    fi
  fi
  #Version of kernel
  KVER=$(file -bL arch/x86/boot/bzImage | grep -o 'version [^ ]*' | cut -d ' ' -f 2)
}

#Installs kernel modules to $MODULES_FOLDER
install_modules() {
  # Create empty headers folder
  sudo rm -rf $MODULES_FOLDER
  mkdir $MODULES_FOLDER

  make -j"$(nproc)" modules_install INSTALL_MOD_PATH=$MODULES_FOLDER INSTALL_MOD_STRIP=1

  cd $MODULES_FOLDER/lib/modules
  # Remove broken symlinks
  rm -rf */build
  rm -rf */source

  # Create an archive for the modules
  tar -cvI "xz -9 -T0" -f $BUILD_ROOT_DIRECTORY/modules.tar.xz *
  write_output "Modules archive created." "blue"

}

#Installs kernel headers to $HEADERS_FOLDER
install_headers() {
  # Create an archive containing headers to build out of tree modules
  # Taken from the archlinux linux PKGBUILD
  cd $KERNEL_SOURCE_FOLDER

  # Create empty headers folder
  sudo rm -rf $HEADERS_FOLDER
  mkdir $HEADERS_FOLDER

  HDR_PATH=$HEADERS_FOLDER/linux-headers-$KVER

  # Build files
  install -Dt "$HDR_PATH" -m644 .config Makefile Module.symvers System.map # vmlinux
  install -Dt "$HDR_PATH/kernel" -m644 kernel/Makefile
  install -Dt "$HDR_PATH/arch/x86" -m644 arch/x86/Makefile
  cp -t "$HDR_PATH" -a scripts

  # Fixes errors when building
  install -Dt "$HDR_PATH/tools/objtool" tools/objtool/objtool
  # install -Dt "$HDR_PATH/tools/bpf/resolve_btfids" tools/bpf/resolve_btfids/resolve_btfids # Disabled in kconfig

  # Install header files
  cp -t "$HDR_PATH" -a include
  cp -t "$HDR_PATH/arch/x86" -a arch/x86/include
  install -Dt "$HDR_PATH/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s
  install -Dt "$HDR_PATH/drivers/md" -m644 drivers/md/*.h
  install -Dt "$HDR_PATH/net/mac80211" -m644 net/mac80211/*.h
  install -Dt "$HDR_PATH/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h
  install -Dt "$HDR_PATH/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
  install -Dt "$HDR_PATH/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
  install -Dt "$HDR_PATH/drivers/media/tuners" -m644 drivers/media/tuners/*.h
  install -Dt "$HDR_PATH/drivers/iio/common/hid-sensors" -m644 drivers/iio/common/hid-sensors/*.h

  # Install kconfig files
  find . -name 'Kconfig*' -exec install -Dm644 {} "$HDR_PATH/{}" \;

  # Remove uneeded architectures
  for arch in "$HDR_PATH"/arch/*/; do
    [[ $arch = */x86/ ]] && continue
    rm -rf "$arch"
  done

  # Remove broken symlinks
  find -L "$HDR_PATH" -type l -printf 'Removing %P\n' -delete

  # Strip files
  find "$HDR_PATH" -type f -exec strip {} \;

  # Strip vmlinux
  # strip "$HDR_PATH/vmlinux"

  # Remove duplicate folder
  rm -rf "$HDR_PATH"/hdr

  # Create an archive for the headers
  cd "$HDR_PATH"/..
  tar -cvI "xz -9 -T0" -f $BUILD_ROOT_DIRECTORY/headers.tar.xz *
  write_output "Header archive created!" "blue"
  echo -e "\n"

}

#launches kernel config graphical editor
edit_kernel_config() {

  cd $KERNEL_SOURCE_FOLDER
  make menuconfig
}

#uses dracut to generate initramfs
create_initramfs() {
  cd $KERNEL_SOURCE_FOLDER

  write_output "Building initramfs" "blue"
  echo -e "\n"
  # Generate initramfs from the built modules
  # when --confdir is not set dracut will use the systems config -> create empty folder to prevent dracut from using the systems config
  if [[ ! -d $DRACUT_CONFIG_DIR ]]; then
      mkdir $DRACUT_CONFIG_DIR
  fi 
  dracut -c $DRACUT_CONFIG --confdir $DRACUT_CONFIG_DIR $INITRAMFS_NAME --kver $KVER --kmoddir "$MODULES_FOLDER/lib/modules/$KVER" --force
  # copy initramfs to build root for the GitHub release
  cp $INITRAMFS_NAME $BUILD_ROOT_DIRECTORY/$INITRAMFS_NAME
  write_output "Building kernel with initramfs" "blue"
  echo -e "\n"
  build_kernel 0
  echo -e "\n"
}

#Gets required input from user to run the kernel build.
user_input() {

  write_output "Would you like to make edits to the kernel config? (y/n): " "green"
  read -n 1 -r -s response
  echo $response
  echo -e "\n"
  if [[ $response =~ ^[Yy]$ ]]; then
    edit_kernel_config
  fi

  write_output "Do you want to perform a clean build?\nThis will generate a new build from the ground up, \nrather than using the previous build. (y/n): " "green"
  read -n 1 -r -s response
  echo $response
  echo -e "\n"
  if [[ $response =~ ^[Yy]$ ]]; then
    build_kernel 1
  else
    build_kernel 0
  fi

}

#get_kernel_source
apply_kernel_patches
setup_kernel_config

# Check if running in a terminal and not in a docker container
if [[ -t 0 ]] && [[ ! -f /.dockerenv ]]; then
  user_input
else
  build_kernel 0
fi

install_modules
install_headers
create_initramfs

# Copy kernel to root
write_output "Copying kernel to root." "blue"
echo -e "\n"
cp $KERNEL_SOURCE_FOLDER/arch/x86/boot/bzImage $BUILD_ROOT_DIRECTORY/bzImage
write_output "Build complete!" "blue"
echo -e "\n"
