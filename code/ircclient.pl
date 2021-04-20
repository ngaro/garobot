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
use Capture::SystemIO qw/cs_system/;

#default settings
my $rodir= "/home/user/readonlydata";
my $rwdir= "/home/user/readwritedata";
my $settingsfile = "settings";
my $settings = { verbose => 3 };	#TODO set this lower in master

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

#Send replies to commands, but keep the output reasonable
sub sendreplies {
	my ($irc, $from, $to, $linesref) = @_;
	#by default reply to the sender, but if it's send to the channel and has a reasonable size, reply to the channel
	my $replyto = $from; $replyto = $to if($to=~/^#/);
	my @lines = @$linesref; my $numlines = @lines;
	if($numlines <= 3) {	#Max 3 lines: reply to the channel if sent to the channel, reply to sender if it's a private message
		foreach(@lines) { $irc->write("PRIVMSG $replyto :$_"); }
	} elsif($numlines <= 20) {	#3-20 lines:
		if($replyto=~/^#/) {	#send first 2 lines to the channel if it was sent to the channel
			$irc->write("PRIVMSG $replyto :The result was too large ($numlines lines). I'm sending it to $from. These are the first 2 lines:");
			$irc->write("PRIVMSG $replyto :" . $lines[0]);
			$irc->write("PRIVMSG $replyto :" . $lines[1]);
		}
		#always send all lines to the sender
		foreach(@lines) { $irc->write("PRIVMSG $from :$_"); }
	} else {	# > 20 lines
		if($replyto=~/^#/) {	#send first 2 lines to the channel if it was sent to the channel
			$irc->write("PRIVMSG $replyto :The result was WAY too large ($numlines lines). This are the first 2 and I'll send 20 lines to $from:");
			$irc->write("PRIVMSG $replyto :" . $lines[0]);
			$irc->write("PRIVMSG $replyto :" . $lines[1]);
		}
		#send 20 first lines to sender
		$irc->write("PRIVMSG $from :The result was WAY too large ($numlines lines). This are the first 20 lines:");
		foreach(my $i=0; $i<20; $i++) { $irc->write("PRIVMSG $from :$lines[$i]"); }
	}
}

#run $command requested by $from to channel $to and sent the output here, our to $from if there is no channel
#runbash fails if /tmp is not writable (cs_system needs this)
sub runbash {
	my ($irc, $from, $to, $command) = @_;
	my $stderr; my $stdout;
	eval { ($stdout, $stderr) = cs_system("$command"); };	#normally we ignore stderr
	if($@) {	#When bash complains we send stderr
		$stdout = $@->{stderr};
		$stdout =~ s/\s+at\s+\S+SystemIO.pm\s+line\s+\d+\.\s*\n$//;
	} else {	#stdout is standard a ref
		$stdout = $$stdout;
	}
	chomp $stdout; my @outputlines = split(/\n/, $stdout);
	sendreplies($irc, $from, $to, \@outputlines);
	verbose(2, "Result of '!bash $command':\n$stdout");
}

#Handle private message with rights
sub allowedprivmsg {
	my ($irc, $from, $to, $message) = @_;
	if($to=~/^#/) { # $from sent to channel
	} else { # $from sent to me
		if($message =~ /^\s*!\s*allow\s+(\S+)\s*$/i) {
			my $nick = $1;
			$settings->{allowedusers}->{$nick} = 1;
			$irc->write("PRIVMSG $nick :$from made you a botadmin");
			verbose(2, "$nick is now an admin");
			return;
		} elsif($message =~ /^\s*!?\s*disallow\s+(\S+)\s*$/i) {
			my $nick = $1;
			$settings->{allowedusers}->{$nick} = undef;
			$irc->write("PRIVMSG $nick :You are no longer a botadmin");
			verbose(2, "$nick is no longer an admin");
			return;
		}
	}
	if($message =~ /^\s*!\s*disconnect\s*$/i) {
		$irc->write("PRIVMSG $from :Disconnecting...");
		$irc->disconnect( sub { verbose(2, "Disconnected"); } );
		exit;
	} elsif($message =~ /^\s*!\s*join\s+(#\S+)\s*$/i) {
		my $channel = $1;
		$irc->write("JOIN $channel", sub { verbose(2, "Joined '$channel'"); } );
	} elsif($message =~ /^\s*!\s*leave\s+(#\S+)\s*$/i) {
		my $channel = $1;
		$irc->write("PART $channel", sub { verbose(2, "Left '$channel'"); } );
	} elsif($message =~ /^\s*!\s*nick\s+(\S+)\s*$/i) {
		my $nick = $1;
		$irc->write("NICK $nick", sub { verbose(2, "Changed nick to '$nick'"); } );
	} elsif($message =~ /^\s*!\s*bash\s+(.*)\s*$/i) {
		runbash($irc, $from, $to, $1);
	} else {
		$irc->write("PRIVMSG $from :I am not doing anything with this action.");
	}
}

#Handle private message from users withOUT rights
sub notallowedprivmsg {
	my ($irc, $from, $to, $message) = @_;
	if($to=~/^#/) { # $from sent to channel
	} else { # $from sent to me
	}
	$irc->write("PRIVMSG $from :Sorry $from, either '$message' isn't a command or you are not allowed to use it. Try '!help'");
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
	verbose(4, "Messagehash: ".Dumper($msghash));
	my $message = @{$msghash->{params}}[1];
	my $from = IRC::Utils::parse_user($msghash->{prefix});
	my $to = @{$msghash->{params}}[0];
	verbose(3, "From '$from' to '$to' this message: '$message'");
	verb4hex($message);
	#Handle messages that do the same thing for everyone
	if($to=~/^#/) { # $from sent to channel
		return unless($message=~/^\s*!\s*/);	#Only reply to !-commands in channels
	} else { # $from sent to me
		$message="!$message" unless($message=~/^\s*!/)	#Make sure there is a '!' so we can handle it better
	}
	if($message =~ /^\s*!\s*help\s*$/i) {
		my $help=<<EINDE;
Some commands are for botadmins only
Some commands are not allowed in channels
In channels precede them with a '!'

disconnect     -> Disconnects this bot from the server
help           -> Show this
join #channel  -> Joins #channel (without leaving others)
leave #channel -> Leave #channel
nick newnick   -> Changes nick to newnick
allow nick     -> nick becomes botadmin
disallow nick  -> nick is no longer botadmin
bash command   -> run command in bash
EINDE
		foreach(split /\n/, $help) { $irc->write("PRIVMSG $from :$_"); }
		verbose(3,$help);
	}
	#Handle messages that do different things for users with different rights
	elsif(defined $settings->{allowedusers}->{$from}) { allowedprivmsg($irc, $from, $to, $message); }
	else { notallowedprivmsg($irc, $from, $to, $message); }
} );

$irc->on( ctcp_version => sub {
	verbose(2, "Connected");
} );

#Start the bot
Mojo::IOLoop->start;
