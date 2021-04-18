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

$irc = $irc->connect( sub {
	my ($irc, $message) = @_;
	unless($message eq "") {
		print STDERR "ERROR: Connection as '$settings->{nick}' to '$settings->{server}' : $message\n";
		exit 1;
	}
	verbose(3, "Connecting...");
} );


$irc->on( close => sub {
	print STDERR "ERROR: Connection to '$settings->{server}' is lost\n";
} );

$irc->on( error => sub {
	my ($irc, $error) = @_;
	print STDERR "ERROR: (Streamerror) '$error'\n";
} );

$irc->on( irc_privmsg => sub {
	my ($irc, $msghash) = @_;
	my ($fromnick, $message) = @{$msghash->{params}};
	if($fromnick =~ /$irc->{nick}/ and $message =~ /VERSION/) {	#TODO Check why it fails without regexps
		verbose(2, "Connected");
		return;
	} elsif($message eq "disconnect") {
		$irc->disconnect( sub { verbose(2, "Disconnected"); } );
	} else {	#TODO
		print Dumper($msghash);
	}
} );

Mojo::IOLoop->start;
