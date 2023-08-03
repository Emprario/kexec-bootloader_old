#!/bin/bash

read_key () {
  # Read a single character from the keyboard
  read -s -n 1 key
  case "$key" in
    $'\x1b') # Check if the key is an escape sequence
      read -s -n 2 -t 1 seq # read in busybox only accept entire values (time)
      case "$seq" in
        '[A') OP="UP";;
        '[B') OP="DOWN" ;;
        '[C') OP="RIGHT" ;;
        '[D') OP="LEFT" ;;
      esac ;;        
    '') OP="ENTER" ;; # Handle Enter key
    #'c') echo "Cancel operation; " && exit ;; # Stop process
    *) OP="$key" ;; # Handle other keys
  esac
  echo "$OP"
}

selection () {
  # With $1 as the en-tete and $2 the options 
  clear
  SEL=0
  OLD=-1
  ENTER=0 # bool values = hell
  while [ $ENTER -eq 0 ]; do
    if [ $OLD -ne $SEL ]; then
      OLD=$SEL
      clear
      cc=0
      echo "$1"
      PR="$2"
      for option in ${PR[@]}; do
        if [ $cc -eq $SEL ];then
          echo " * $( echo $option | tr "_" " ")"
        else
          echo "   $( echo $option | tr "_" " ")"
        fi
        cc=$(( $cc+1 ))
      done
    fi
    OP=$(read_key)
    case "$OP" in
      'UP') SEL=$(( $SEL-1 )) ;;
      'DOWN') SEL=$(( $SEL+1 )) ;;
      'ENTER') ENTER=1 ;;
    esac
    if [ $SEL -lt 0 ];then
      SEL=0
    fi
    if [ $SEL -gt $cc ];then
      SEL=$(( $cc-1 ))
    fi
  done
}

#selection "Bonjour !" "eupnea kboot"
#echo "return value: $SEL"
