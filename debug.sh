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

screen=byobu-screen #You can use 'screen' itself here

$screen -d -m -S garobot docker run -it --rm --name ngircd linuxserver/ngircd
sleep 3	#gives server a couple of seconds to start
$screen -S garobot -X screen docker run -v $PWD/admin.conf:/usr/local/etc/irssi.conf:ro -v $PWD/adv_windowlist.pl:/home/user/.irssi/scripts/autorun/adv_windowlist.pl -it --rm --name irssiadmin irssi
$screen -S garobot -X screen docker run -v $PWD/regular.conf:/usr/local/etc/irssi.conf:ro -v $PWD/adv_windowlist.pl:/home/user/.irssi/scripts/autorun/adv_windowlist.pl -it --rm --name irssiregular irssi
$screen -S garobot -X screen docker run --read-only --tmpfs /tmp:rw,exec,size=100m --tmpfs /home/user:rw,exec,size=100m -v $PWD/readonlydata:/usr/local/readonlydata:ro -v $PWD/code:/usr/local/bin:ro -it --rm --name garobot garobot /bin/bash
$screen -S garobot -X screen $PWD/debuginfo.sh

$screen -S garobot -p 0 -X title server
$screen -S garobot -p 1 -X title admin
$screen -S garobot -p 2 -X title regular
$screen -S garobot -p 3 -X title garobot
$screen -S garobot -p 4 -X title info

$screen -r garobot
