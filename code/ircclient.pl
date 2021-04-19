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

use v5.32;
use strict;
use warnings;
use Mojo::IRC;
use Data::Dumper;

#default settings
my $rodir= "/home/user/readonlydata";
my $rwdir= "/home/user/readwritedata";
my $settingsfile = "settings";
my $settings = { verbose => 4 };	#TODO set this lower in master

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

#Read the settings from the read/writedir
sub readsettings {
	open(my $fh, "$rwdir/$settingsfile") or die "Can't open settings";
	while(<$fh>) {
		unless(/^\s*#/) {
			/^(.*?)\t(.*)\n/;
			$settings->{$1} = $2;
		}
	}
	if(defined $settings->{allowedusers}) {
		my @allowedusers = split(/\s+/, $settings->{allowedusers});
		$settings->{allowedusers}={};
		foreach(@allowedusers) {
			$settings->{allowedusers}->{$_}=1;
		}
	}
	close $fh;
}

#Handle private message with rights
sub allowedprivmsg {
	my ($irc, $from, $message) = @_;
	if($message =~ /^\s*!?\s*disconnect\s*$/i) {
		$irc->write("PRIVMSG $from :Disconnecting...");
		$irc->disconnect( sub { verbose(2, "Disconnected"); } );
		exit;
	} elsif($message =~ /^\s*!?\s*join\s+(#\S+)\s*$/i) {
		my $channel = $1;
		$irc->write("JOIN $channel", sub { verbose(2, "Joined '$channel'"); } );
	} elsif($message =~ /^\s*!?\s*leave\s+(#\S+)\s*$/i) {
		my $channel = $1;
		$irc->write("PART $channel", sub { verbose(2, "Left '$channel'"); } );
	} elsif($message =~ /^\s*!?\s*nick\s+(\S+)\s*$/i) {
		my $nick = $1;
		$irc->write("NICK $nick", sub { verbose(2, "Changed nick to '$nick'"); } );
	} else {
		$irc->write("PRIVMSG $from :I am not doing anything with this action.");
	}
}

#Handle private message from users withOUT rights
sub notallowedprivmsg {
	my ($irc, $from, $message) = @_;
	$irc->write("PRIVMSG $from :Sorry $from, either this isn't a command or you are not allowed to use it. Try '!help'");
}

#Create the bot
system("cp $rodir/$settingsfile $rwdir");
readsettings;
verbose(3, Dumper($settings));
my $irc = Mojo::IRC->new(nick => $settings->{nick}, user => $settings->{user}, name => $settings->{name},  server => $settings->{server}) or die "Can't create IRC object";
$irc->parser(Parse::IRC->new(ctcp => 1));

##Configure all events and methods
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
	my $message = @{$msghash->{params}}[1];
	my $from = IRC::Utils::parse_user($msghash->{prefix});
	verbose(3, "From: '$from'");
	verbose(3, "Message: '$message'");
	verb4hex($message);
	#Handle messages that do the same thing for everyone
	if($message =~ /^\s*!?\s*help\s*$/i) {
		my $help=<<EINDE;
Commands for private messages. Not everyone is allowed to use them all.
disconnect     -> Disconnects this bot from the server
help           -> Show this
join #channel  -> Joins #channel (without leaving others)
leave #channel -> Leave #channel
nick newnick   -> Changes nick to newnick
EINDE
		foreach(split /\n/, $help) { $irc->write("PRIVMSG $from :$_"); }
		verbose(3,$help);
	}
	#Handle messages that do different things for users with different rights
	elsif(defined $settings->{allowedusers}->{$from}) { allowedprivmsg($irc, $from, $message); }
	else { notallowedprivmsg($irc, $from, $message); }
} );

$irc->on( ctcp_version => sub {
	verbose(2, "Connected");
} );

#Start the bot
Mojo::IOLoop->start;
