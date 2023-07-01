#!/bin/sh

get_scan() {
  #### Find bootable drives ####
  echo "Finding bootable drives ..."

  IFS='
  ' read -a DRIVES <<< $(lsblk -ro name,partlabel | grep "Boot")

  # Separate Drives lines to only keep drive name
  DRIVES_PATH=()
  for drive in "${DRIVES[@]}";
  do
    IFS=' ' read -a d <<< $drive
    DRIVES_PATH="${DRIVES_PATH} ${d[0]}"
  done
  echo "Boot partitions found: ${#DRIVES_PATH[*]}"
  echo ${DRIVES_PATH[*]}

  #### Mount and search for kernels ####
  echo "Mounting and searching for kernels ..."

  OPTIONS=()
  for drive in "${DRIVES_PATH[@]}";
  do 
    drive=$(echo $drive | sed 's/ //g')
    mount --mkdir /dev/$drive /mnt/$drive
    cd /mnt/$drive  
    for folder in "/mnt/$drive"/*;
    do
      echo "Scanning: $folder"
      if   [ -f $folder/bzImage ] \
        && [ -f $folder/kernel.flags ] \
        && [ -f $folder/initrd ]; then 
        OPTIONS="${OPTIONS} '$folder'"
      fi
    done
    cd /
    umount /dev/$drive
  done
  echo "Options detected: ${#OPTIONS[*]}"
  echo ${OPTIONS[*]}
  return ${OPTIONS[*]}
}
