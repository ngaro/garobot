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
use Mojo::IRC;
use Data::Dumper;	#TODO remove

#default settings
my $settingsfile = "/home/user/readonlydata/settings";
my $settings={ verbose => 4 };	#TODO lower

#prints $message to STDOUT unless $verbose is higher then the allowed setting
sub verbose {
	my ($verbose, $message) = @_;
	say $message if($settings->{verbose} >= $verbose);
}

#prints $message as hexadecimal chars to STDOUT if $verbose is higher then 3 (if used to skip unnecessary conversion)
sub verb4hex {
	my $message = shift;
	if($settings->{verbose} > 3) {
		my $hex = $message;
		$hex =~ s/(.)/sprintf("%x-",ord($1))/eg; chop $hex;
		verbose(4, "'$message' as hex: $hex");
	}
}

#Read the settings
sub readsettings {
	open(my $fh, $settingsfile) or die "Can't open settings";
	while(<$fh>) {
		unless(/^\s*#/) {
			/^(.*?)\t(.*)\n/;
			$settings->{$1} = $2;
		}
	}
	close $fh;
}

#Create the bot
readsettings;
my $irc = Mojo::IRC->new(nick => $settings->{nick}, user => $settings->{user}, name => $settings->{name},  server => $settings->{server}) or die "Can't create IRC object";
$irc->parser(Parse::IRC->new(ctcp => 1));

##Configure all events and methods
#Connect the bot
$irc = $irc->connect( sub {
	my ($irc, $message) = @_;
	unless($message eq "") {
		print STDERR "ERROR: Connection as '$settings->{nick}' to '$settings->{server}' : $message\n";
		exit 1;
	}
	verbose(3, "Connecting...");
} );

#Set all handlers
$irc->on( close => sub {
	print STDERR "ERROR: Connection to '$settings->{server}' is lost\n";
} );

$irc->on( error => sub {
	my ($irc, $error) = @_;
	print STDERR "ERROR: (Streamerror) '$error'\n";
} );

$irc->on( irc_privmsg => sub {
	my ($irc, $msghash) = @_;
	my $message = @{$msghash->{params}}[1];
	my $from = IRC::Utils::parse_user($msghash->{prefix});
	verbose(3, "From: '$from'");
	verbose(3, "Message: '$message'");
	verb4hex($message);
	if($message =~ /^\s*disconnect\s*$/i) {
		$irc->disconnect( sub { verbose(2, "Disconnected"); } );
	} else {
		say "TODO handle '$message' from '$from'";
	}
} );

$irc->on( ctcp_version => sub {
	verbose(2, "Connected");
} );

#Start the bot
Mojo::IOLoop->start;
