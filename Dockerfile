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

#When not in dev move lines around and combine more
FROM perl:5.32.1-buster
RUN cpanm install Mojo::IRC
RUN rm -r /root/.cpanm
RUN useradd --create-home --home-dir /home/user user && mkdir /home/user/readwritedata && mkdir /home/user/readonlydata && chown -R user:user /home/user
ADD code/ircclient.pl /usr/local/bin
WORKDIR /home/user
#Uncomment this when not in dev: USER user
