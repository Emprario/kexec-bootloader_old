#!/bin/sh

first_array () {
  for e in $1; 
  do
    echo "$e"
    exit
  done
}

len_array () {
  cc=0
  for e in $1;
  do
    cc=$(( $cc+1 ))
  done
  echo $cc
}

get_scan () {
  #### Find bootable drives ####
  echo "Finding bootable drives ..."

  DRIVES=$(lsblk -ro name,partlabel | grep "Boot")

  # Separate Drives lines to only keep drive name
  DRIVES_PATH=""
  for drive in "$DRIVES";
  do
    DRIVES_PATH="$(first_array $drive) $DRIVES_PATH "
  done
  echo "$DRIVES_PATH"
  echo "Boot partitions found: $(len_array $DRIVES_PATH)"

  #### Mount and search for kernels ####
  echo "Mounting and searching for kernels ..."

  OPTIONS=""
  for drive in "$DRIVES_PATH";
  do 
    drive=$(echo $drive | sed 's/ //g')
    mkdir -p /mnt/$drive
    mount /dev/$drive /mnt/$drive
    cd /mnt/$drive  
    for folder in "/mnt/$drive"/*;
    do
      echo "Scanning: $folder"
      if   [ -f $folder/bzImage ] \
        && [ -f $folder/kernel.flags ] \
        && [ -f $folder/initrd ]; then 
        OPTIONS="$folder $OPTIONS"
      fi
    done
    cd /
    umount /dev/$drive
  done
  echo "Options detected: $(len_array $OPTIONS)"
  echo $OPTIONS
}

#get_scan
#echo "return value: $OPTIONS"
