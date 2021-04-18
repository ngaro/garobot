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
my $settings={ verbose => 2 };

use Mojo::IRC;
use Data::Dumper;	#TODO remove

sub verbose {
	my ($verbose, $message) = @_;
	say $message if($settings->{verbose} >= $verbose);
}

open(my $fh, $settingsfile) or die "Can't open settings";
while(<$fh>) {
	unless(/^\s*#/) {
		/^(.*?)\t(.*)\n/;
		$settings->{$1} = $2;
	}
}
close $fh;

my $irc = Mojo::IRC->new(nick => $settings->{nick}, user => $settings->{user}, name => $settings->{name},  server => $settings->{server}) or die "Can't create IRC object";

my $foo = $irc->connect( sub {
	my ($irc, $message) = @_;
	unless($message eq "") {
		print STDERR "ERROR: Connection as '$settings->{nick}' to '$settings->{server}' : $message\n";
		exit 1;
	}
	verbose(2, "Connected");
#begin TODO 1
	verbose(3, "Sleeping 60 seconds");
	sleep 60;
	verbose(3, "Done sleeping");
	$irc->disconnect;
	verbose(2, "Disconnected");
#end TODO 1
} );

Mojo::IOLoop->start;
