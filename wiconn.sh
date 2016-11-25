#!/bin/sh
# Copyright (c) 2011-2016, ax0n@h-i-r.net
# BSD 2-Clause (see LICENSE)
# https://github.com/n0xa/wiconn

# Assumes you are in the wheel group and have doas(1) configured with
# nopass rules for dhclient, ifconfig and pkill. At a bare minimum, the
# below lines should be added to the end of /etc/doas.conf and uncommented:
#
#permit nopass :wheel as root cmd /usr/bin/pkill args dhclient
#permit nopass :wheel as root cmd /sbin/ifconfig
#permit nopass :wheel as root cmd /sbin/dhclient


# Uncomment and change as needed to match wireless interface.
#dev=athn0 
#
# You can also add a DefaultDev line to ~/.wiconn like
#   the below example (without the leading "# "
# ||DefaultDev|athn0

nwid=$1
wpakey=$2

# Functions and spaghetti code
setup_wifi(){
  if [ -z "${nwid}" ]
  then
    scan_wifi
    prompt_ssid
  fi
  return
}

autodetect_dev(){
dev=$(grep "^||DefaultDev|" ~/.wiconn | cut -f4 -d\| | tail -n 1)
if [ -z "${dev}" ]
then
  echo "No device specified"
  unset devlist
  iflist=$(ifconfig | grep ^[a-z].*: | cut -f1 -d:)
  for iface in $(echo ${iflist})
  do
    ifconfig ${iface} | grep "media:.*IEEE802.11">/dev/null && devlist="${iface} ${devlist}"
  done
  num=$(echo ${devlist} | wc -w | tr -d " \t")
  case ${num} in
  0)
    echo "No 802.11 devices found"
    exit 1
  ;;
  1)
    dev=${devlist}
  ;;
  *)
    echo "${num} different wifi interfaces found."
    for iface in ${devlist}
    do
      echo -n "Set up ${iface}? [y/N] "
      read q
      case ${q} in
      [yY])
        dev=${iface}
        setup_wifi
      ;;
      *)
        dev=""
      ;;
      esac
    done
  ;;
  esac 
  else
    echo "Using ${dev}"
  fi 
  return
}

scan_wifi(){
  lines=$(expr $(tput lines) - 3)  ## A few lines of room for header/prompt
  current=$(ifconfig ${dev} | tr " " "\n" | grep -A1 nwid | tail -n 1)
  cbssid=$(ifconfig ${dev} | tr " " "\n" | grep -A1 bssid | tail -n 1)
    (echo " ... Scanning ... "
    doas /sbin/ifconfig ${dev} scan | grep -e "	nwid" > /tmp/$$.tmp 
    netlength=$(
      awk '{ if (length($2) > max) max = length($2) } END { print max }' \
      /tmp/$$.tmp
    )
    # Screen setup
    columns=$(tput cols)
    if [ ${columns} -gt 99 ]
    then
      firstcol=${netlength}
    else
      # Static SSID Width of 15 chars, truncating some on narrow terminals
      firstcol=15
    fi
    lastcol=$(expr ${columns} - 35 - ${firstcol})
    echo -en "\033[1;44m"
    printf "%-${firstcol}.${firstcol}s | %4.4s | %2.2s | %-17.17s | %-${lastcol}.${lastcol}s" SSID S/N Ch BSSID Flags
    echo -e "\033[0m"
    cat /tmp/$$.tmp | while read line
    do
      ssid=$(echo ${line} | cut -b6- | sed s/" chan [1-9].*"//)
      chan=$(echo ${line} | sed s/"^.* chan "// | cut -f1 -d" ")
      sn=$(echo ${line} | awk -F: '{print $NF}'| cut -f2 -d" ")
      bssid=$(echo ${line} | grep -o -E "([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}" | head -n 1)
      flags=$(echo ${line} | awk '{print $NF}')
      echo "${ssid}|${sn}|${chan}|${bssid}|${flags}" \
        | awk -F"|" '{ printf "%-'${firstcol}'.'${firstcol}'s | %4.4s | %2.2s | %17.17s | %-'${lastcol}'.'${lastcol}'s\n", $1, $2, $3, $4, $5}' \
        | sed -E "s/(.*privacy.*)/\[1;40m\1\[0m/" \
        | sed -E "s/("${current}".*"${cbssid}".*)/\[1;42m\1\[0m/" \
        | sed -E "s/(.*)/\[1;41m\1\[0m/"  
    done) | less -F -E -X -r -z ${lines}
  rm /tmp/$$.tmp
}

check_ssids(){
  if [ $(grep ^${nwid}\| ~/.wiconn) ]
  then
    echo "Found saved wifi"
    tbssid=$(grep ^${nwid}\| ~/.wiconn | cut -f3 -d\|)
    wpakey=$(grep ^${nwid}\| ~/.wiconn | cut -f2 -d\|)
    connect_wifi
  fi
}

prompt_ssid(){
  echo -en "SSID: "
  read nwid
  if [ -z "${nwid}" ]
  then
    echo "Aborted."
    exit 1
  fi
  line=$(doas /sbin/ifconfig ${dev} scan | grep "	nwid.*${nwid}")
  if [ -z "${line}" ]
  then
    echo -en "\033[1m${nwid}\033[0m not found. Try to connect anyway? [y/N] "
    read q
    case ${q} in
    [yY])
      echo -n "WPA Key (ENTER for none): "
      read wpakey
      continue=1
    ;;
    *)
      echo "Abort."
      exit 1
    ;;
    esac
  fi
  check_ssids
  if [[ "${line}" == *privacy* ]]
  then
    echo -e "\033[1m${nwid}\033[0m is encrypted."
    if [ -z "${wpakey}" ]
    then
      echo -n "Enter WPA key (will echo): "
      read wpakey
      if [ -z "${wpakey}" ]
      then
        echo "Aborted."
        exit 1
      fi
    else
      echo "Key supplied on command line"
    fi
  fi
  connect_wifi
}

connect_wifi(){
  if [ -z "${tbssid}" ] 
  then
    bssid="-bssid"
  else
    bssid="bssid ${tbssid}"
    echo "BSSID forced: ${tbssid}"
  fi
  if [ -z "${wpakey}" ]
  then
    echo "Attempting to connect to \033[1m${nwid}\033[0m as an open network..."
    doas /usr/bin/pkill dhclient
    doas /sbin/ifconfig ${dev} -wpakey nwid ${nwid} ${bssid}
    doas /sbin/dhclient ${dev}
  else
    echo "Attempting to connect to \033[1m${nwid}\033[0m with WPA key..."
    doas /usr/bin/pkill dhclient
    doas /sbin/ifconfig ${dev} nwid ${nwid} wpakey ${wpakey} ${bssid}
    doas /sbin/dhclient ${dev} 
  fi 
  if [ $(grep ^${nwid}\| ~/.wiconn) ]
  then
    exit 0
  else
    save_wifi
  fi
  exit 0
}

save_wifi(){
  echo "Save this network for future use?"
  echo "You may also save this network with the BSSID to help protect against "
  echo "certain types of evil twin networks. To do this, use the 'B' option."
  echo -en "Save connection details for \033[1m${dev}\033[0m? (y/N/b) "
  read save
  case ${save} in
    [yY])
      echo "${nwid}|${wpakey}" >> ~/.wiconn
      echo "${nwid} saved."
    ;;  
    [bB])
      bssid=$(ifconfig | grep "nwid $NWID" | grep -o -E "([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}")
      echo "${nwid}|${wpakey}|${bssid}" >> ~/.wiconn
      echo "${nwid} saved with static BSSID."
    ;;
    *)
      echo "${nwid} not saved."
    ;;
  esac
  return
}

# Create config file and lock it down if it doesn't exist
if [ ! -f ~/.wiconn ]
then
  touch ~/.wiconn
  chmod 0600 ~/.wiconn
fi

if [ -z "${dev}"]
then
  autodetect_dev
fi 

if [ -z "${nwid}" ]
then
  setup_wifi
fi

if [ `grep ^${nwid}\| ~/.wiconn` ]
then
  echo "Found saved access point"
  tbssid=`grep ^${nwid}\| ~/.wiconn | cut -f3 -d\|`
  wpakey=`grep ^${nwid}\| ~/.wiconn | cut -f2 -d\|`
  connect_wifi
fi

