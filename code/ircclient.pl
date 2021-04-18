#!/usr/bin/env perl

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

use v5.30;	#TODO change to 5.32
use strict;
use warnings;

my $settingsfile = "/home/user/readonlydata/settings";

use Mojo::IRC;

open(my $fh, $settingsfile);
while(<$fh>) {
	unless(/^\s*#/) {
		print $_;
	}
}
close $fh;

#my $irc = Mojo::IRC->new(nick => 'garobot', user => 'Garobot', server => 
