#!/bin/bash

get_scan () {
  #### Find bootable drives ####
  echo "Finding bootable drives ..."

  DRIVES=($(lsblk -ro NAME,LABEL | grep KC-BOOT))
  DRIVES_NAME=()
  for drive in ${DRIVES[@]}
  do
    if [[ $drive != "KC-BOOT" ]]; then
      DRIVES_NAME+=($drive)
    fi
  done
  


  echo "Boot partitions found: ${#DRIVES_NAMES[@]}"
  

  #### Mount and search for kernels ####
  echo "Mounting and looking for kernels ..."

  OPTIONS=()
  echo ${DRIVES_NAME[2]}
  for drive in ${DRIVES_NAME[@]};
  do
    mkdir -p /mnt/$drive
    mount /dev/$drive /mnt/$drive
    cd /mnt/$drive  
    for folder in "/mnt/$drive"/*;
    do
      echo "Scanning: $folder"
      if   [ -f $folder/bzImage ] \
        && [ -f $folder/kernel.flags ] \
        && [ -f $folder/initrd ]; then 
        OPTIONS+=($folder)
      fi
    done
    cd /
    umount /dev/$drive
  done
  echo "Options detected: ${#OPTIONS[@]}"
}

#get_scan
#echo "return value: $OPTIONS"
