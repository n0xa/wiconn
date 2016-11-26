# wiconn
A text-based 802.11 wireless network manager for OpenBSD

## Walk through
If you run wiconn without any arguments, it will scan for wireless networks and display them in a list. The network you're connected to will show up with a green background. Open networks are shown with a red background.
![wiconn.sh network list](http://stuff.h-i-r.net/wiconn/wc1.png)

If you have a saved network in ~/.wiconn, you can simply run wiconn.sh with the network name as the first argument.
![wiconn.sh direct connection](http://stuff.h-i-r.net/wiconn/wc0.png)

Wiconn can save a network you've connected to, and can save the BSSID to protect you from most evil twin attacks.
![wiconn.sh save connection](http://stuff.h-i-r.net/wiconn/wc2.png)

The ~/.wiconn file can be used to set the default wireless interface, and also stores wireless network names, WPA keys and (optionally) BSSIDs. It should be readable and writable only by your user (chmod 0600). 
![~/.wiconn rc file](http://stuff.h-i-r.net/wiconn/wc3.png)

## About
Written in Bourne shell and relying only on tools available in the OpenBSD
base distribution, wiconn strives for ease of use without external
dependencies while remaining aesthetically-pleasing in any terminal or 
console supporting colors.

Wiconn can automatically detect wireless interfaces. If you have only one
such interface, it will use that one by default. If you have multiple 
wireless interfaces, you can specify which one you wish to use by default
in the script itself, or in the configuration file. Otherwise, it will
prompt you.

Wiconn can remember your wireless networks and their WPA/WPA2 PSK keys.
Note that for the time being, these keys are stored in the clear in 
~/.wiconn which is created with mode 0600 (only your user can read and 
write to the file). I suppose if this is good enough for your 
hostname.if(5) file and your private SSH keys, it should be good enough
for this. 

## Setup
Wiconn has to do a few things as root, and assumes you are in the wheel
group and have doas(1) configured with nopass rules for dhclient, 
ifconfig and pkill. To keep doas from incessantly prompting or failing
with errors, at a bare minimum, the below lines should be added 
to the end of /etc/doas.conf:

```
permit nopass :wheel as root cmd /usr/bin/pkill args dhclient
permit nopass :wheel as root cmd /sbin/ifconfig
permit nopass :wheel as root cmd /sbin/dhclient
```

## Colors and display
ANSI color escape sequences are hard-coded, which might mess with 
certain terminals. It seems to work great in most X11 terminals and 
on the wscons(4) console in text mode.

Enjoy!
