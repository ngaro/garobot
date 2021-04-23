#!/bin/sh

#Garobot
#Copyright (C) 2021  Nikolas Garofil
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <https://www.gnu.org/licenses/>.

hostextif=$(cat /proc/net/route | perl -ne 'if(/^(\S+)\s+00000000\s+/) {print $1;}')
garobotipv4=$(docker inspect garobot -f "{{ .NetworkSettings.IPAddress }}")
sudo iptables -D FORWARD -s $garobotipv4 -j DROP
sudo iptables -D FORWARD -o $hostextif -s $garobotipv4 -j ACCEPT
sudo iptables -D INPUT -s $garobotipv4 -j DROP
garobotipv6=$(docker inspect garobot -f "{{ .NetworkSettings.GlobalIPv6Address }}")
sudo ip6tables -D FORWARD -s $garobotipv6 -j DROP
sudo ip6tables -D FORWARD -o $hostextif -s $garobotipv6 -j ACCEPT
sudo ip6tables -D INPUT -s $garobotipv6 -j DROP
