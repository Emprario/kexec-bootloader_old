#!/bin/sh

idx_array () {
  # $1 is the array and $2 is the idx
  cc=0
  for e in $1; 
  do
    if [ $cc -eq $2 ];then
      echo "$e"
      exit
    fi
    cc=$(( $cc+1 ))
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

  DRIVES=$(blkid | grep "BOOT" | tr "\n" ' ' | tr ':' ' ')
  
  # Separate Drives lines to only keep drive name
  DRIVES_NAME=""
  for drive in $DRIVES;
  do
    if [ -n "$(ls -l $drive 2>/dev/null)" ];then # supress error output
      DRIVES_NAME="$(echo "$drive" | cut -c6-) $DRIVES_NAME"
    fi
  done

  echo "Boot partitions found: $(len_array "$DRIVES_NAME")"

  #### Mount and search for kernels ####
  echo "Mounting and looking for kernels ..."

  OPTIONS=""
  for drive in $DRIVES_NAME;
  do 
    #drive=$(echo $drive | sed 's/ //g')
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
  echo "Options detected: $(len_array "$OPTIONS")"
}

#get_scan
#echo "return value: $OPTIONS"
