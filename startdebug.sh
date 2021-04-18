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

echo "Run with /usr/local/bin/code/ircclient.pl"
docker run --read-only --tmpfs /home/user/readwritedata:rw,exec,size=100m -v $PWD/readonlydata:/home/user/readonlydata:ro -v $PWD/code:/usr/local/bin/code -it --rm --name garobot garobot /bin/bash
