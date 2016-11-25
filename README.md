# wiconn
A text-based 802.11 wireless network manager for OpenBSD

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

Wiconn assumes you are in the wheel group and have doas(1) configured 
with nopass rules for dhclient, ifconfig and pkill. At a bare minimum, 
the below lines should be added to the end of /etc/doas.conf:

permit nopass :wheel as root cmd /usr/bin/pkill args dhclient
permit nopass :wheel as root cmd /sbin/ifconfig
permit nopass :wheel as root cmd /sbin/dhclient

Enjoy!
