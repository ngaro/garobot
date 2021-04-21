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

serverip=$(docker inspect ngircd -f "{{ .NetworkSettings.IPAddress }}")
echo "The ip of the server is: $serverip"
echo "Make sure it's in admin.conf and regular.conf"
echo "Now run (in window 'garobot'): /usr/local/sbin/garobot.pl --server=$serverip"
read notimportant
