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
use Capture::Tiny ':all';
use Term::ReadPassword;
use WWW::Mechanize; use WWW::Mechanize::TreeBuilder;

#default settings
my $rodir= "/usr/local/readonlydata";
my $settingsfile = "settings";
my $settings = { verbose => 3 };	#TODO set this lower in master

#global vars
my $currentnick;

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
	open(my $fh, "$rodir/$settingsfile") or die "Can't open settings";
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
	my $cmdlinesettings = {};
	foreach(@ARGV) {
		if(/^--(.*?)=(.*)/) {
			my $key = $1; my $value = $2;
			if(defined $cmdlinesettings->{$key}) { $cmdlinesettings->{$key}.=" $value" } else { $cmdlinesettings->{$key} = $value }
		}
		if(/^--nickserv/) {
			$settings->{nickserv} = read_password('NickServ password: ');
			chomp $settings->{nickserv};
		}
	}
	foreach(keys %$cmdlinesettings) { $settings->{$_} = $cmdlinesettings->{$_}; }	#cmdlinesettings overwrite (not append) settings in $settings file
}

#Send replies to commands, but keep the output reasonable
sub sendreplies {
	my ($irc, $from, $to, $linesref, $command) = @_;
	#by default reply to the sender, but if it's send to the channel and has a reasonable size, reply to the channel
	my $replyto = $from; $replyto = $to if($to=~/^#/);
	my @lines = @$linesref; my $numlines = @lines;
	if($numlines == 0) {	#no output
		$irc->write("PRIVMSG $replyto :### '$command' Doesn't output anything");
	} elsif($numlines <= 3) {	#Max 3 lines: reply to the channel if sent to the channel, reply to sender if it's a private message
		foreach(@lines) { $irc->write("PRIVMSG $replyto :$_"); }
	} elsif($numlines <= 20) {	#3-20 lines:
		if($replyto=~/^#/) {	#send first 2 lines to the channel if it was sent to the channel
			$irc->write("PRIVMSG $replyto :### The result was too large ($numlines lines). I'm sending it to $from. These are the first 2 lines:");
			$irc->write("PRIVMSG $replyto :" . $lines[0]);
			$irc->write("PRIVMSG $replyto :" . $lines[1]);
		}
		#always send all lines to the sender
		foreach(@lines) { $irc->write("PRIVMSG $from :$_"); }
	} else {	# > 20 lines
		if($replyto=~/^#/) {	#send first 2 lines to the channel if it was sent to the channel
			$irc->write("PRIVMSG $replyto :### The result was WAY too large ($numlines lines). These are the first 2 and I'll send 20 lines to $from:");
			$irc->write("PRIVMSG $replyto :" . $lines[0]);
			$irc->write("PRIVMSG $replyto :" . $lines[1]);
		}
		#send 20 first lines to sender
		$irc->write("PRIVMSG $from :### The result was WAY too large ($numlines lines). These are the first 20 lines:");
		foreach(my $i=0; $i<20; $i++) { $irc->write("PRIVMSG $from :$lines[$i]"); }
	}
}

#run $command requested by $from to channel $to and sent the output here, our to $from if there is no channel
#runsh fails if /tmp is not writable (cs_system needs this)
sub runsh {
	my ($irc, $from, $to, $command) = @_;
	my ($stdout, $stderr, $returncode) = capture { system("timeout $settings->{waitsh} sh -c '$command'"); };
	while( system("killall sh") == 0 ) {}	#forkbomb protection
	if($returncode == 31744) {
		my $replyto = $from; $replyto = $to if($to=~/^#/);
		$irc->write("PRIVMSG $replyto :### I stopped '$command' because it took longer then " . $settings->{waitsh} . " seconds" );
	}
	$stdout.=$stderr;
	chomp $stdout; my @outputlines = split(/\n/, $stdout);
	sendreplies($irc, $from, $to, \@outputlines, $command);
	verbose(2, "Result of '!sh $command':\n$stdout");
}

#Handle private message with rights
sub allowedprivmsg {
	my ($irc, $from, $to, $message) = @_;
	if($to=~/^#/) { # $from sent to channel
	} else { # $from sent to me
		if($message =~ /^allow\s+(\S+)\s*$/i) {
			my $nick = $1;
			$settings->{allowedusers}->{$nick} = 1;
			$irc->write("PRIVMSG $nick :$from made you a botadmin");
			$irc->write("PRIVMSG $from :$nick is now a botadmin");
			verbose(2, "$nick is now an admin");
			return;
		} elsif($message =~ /^disallow\s+(\S+)\s*$/i) {
			my $nick = $1;
			$settings->{allowedusers}->{$nick} = undef;
			$irc->write("PRIVMSG $nick :You are no longer a botadmin");
			$irc->write("PRIVMSG $from :$nick is no longer a botadmin");
			verbose(2, "$nick is no longer an admin");
			return;
		} elsif($message =~ /^restart\s*/) {
			verbose(2, "Restarting");
			exec $0, @ARGV;
		}
	}
	if($message =~ /^disconnect\s*$/i) {
		$irc->write("PRIVMSG $from :Disconnecting...");
		$irc->disconnect( sub { verbose(2, "Disconnected"); } );
		exit;
	} elsif($message =~ /^join\s+(#\S+)\s*$/i) {
		my $channel = $1;
		$irc->write("JOIN $channel", sub { verbose(2, "Joined '$channel'"); } );
	} elsif($message =~ /^leave\s+(#\S+)\s*$/i) {
		my $channel = $1;
		$irc->write("PART $channel", sub { verbose(2, "Left '$channel'"); } );
	} elsif($message =~ /^nick\s+(\S+)\s*$/i) {
		$currentnick = $1;
		$irc->write("NICK $currentnick", sub { verbose(4, "Changed nick to '$currentnick'"); } );
	} elsif($message =~ /^sh\s+(.*)\s*$/i) {
		runsh($irc, $from, $to, $1);
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
if($< eq 0) {
	system("chown -R user:user /home/user");	#When a tmpfs is mounted over /home, /home/user becomes root:root
	exec("sudo", "-u", "user", $0, @ARGV);
}
readsettings;
$currentnick = $settings->{nick};
my $mech = WWW::Mechanize->new(autocheck=>0); WWW::Mechanize::TreeBuilder->meta->apply($mech);
if($settings->{server}=~/ /) { print STDERR "ERROR: Too much servers given, use a different bot for each server\n";  exit 1; }
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
	if($msghash->{prefix} =~ /NickServ/) { verbose(2, "'" . $msghash->{prefix} . "' sent '$message'"); }
	return unless($message=~/^\s*!\s*/);	#Only reply to !-commands
	my $from = IRC::Utils::parse_user($msghash->{prefix});
	my $to = @{$msghash->{params}}[0];
	verbose(3, "From '$from' to '$to' this message: '$message'");
	verb4hex($message);
	$message=~s/^\s*!\s*//;
	if($message =~ /^help\s*$/i) {
		my $help=<<EINDE;
Some commands are for botadmins only
Some commands are not allowed in channels

!disconnect     -> Disconnects this bot from the server
!help           -> Show this
!join #channel  -> Joins #channel (without leaving others)
!leave #channel -> Leave #channel
!nick newnick   -> Changes nick to newnick
!allow nick     -> nick becomes botadmin
!disallow nick  -> nick is no longer botadmin
!sh command     -> run command in a shell
!poccy nick     -> use magic to get rid of demon 'nick'
!w thing        -> get some info about thing from wikipedia
!restart        -> clears all settings and restarts the bot (filesystem status is preserved)
EINDE
		foreach(split /\n/, $help) { $irc->write("PRIVMSG $from :$_"); }
		verbose(3,$help);
	} elsif($message =~ /^w\s*(\S+)/) {
		my $subject = $1; my $info = "Sorry, I don't know anything about that, find someone else to help you.";
		$mech->get("https://en.wikipedia.org/wiki/$subject");
		if($mech->success and $mech->is_html) {
			#search the first 'real' <p></p>. This contains a short description of $subject. <p class="mw-empty-elt"></p> is usually the first <p> but it's empty
			my $firstrealp = $mech->look_down('_tag' => 'p', sub { not defined $_[0]->attr('class') or $_[0]->attr('class') ne "mw-empty-elt"; } );
			foreach($firstrealp->look_down('class'=>'reference')) { $_->delete(); }	#remove all citations so that we don't get "[number]" things in the output
			foreach($firstrealp->look_down('_tag'=>'span')) { $_->delete(); }	#remove all <span>'s (hard to parse)
			$info = ucfirst($firstrealp->as_text()); $info=~s/\s*$//; $info=~s/\(\s*;/\(/;	#After removing span's sometimes things like "( ;" are left behind
		}
		foreach my $line (split(/\.\s+/, $info)) {
			$line.='.'; $line=~s/\.\.$/./;
			if($to=~/^#/) { # $from sent to channel
				$irc->write("PRIVMSG $to :$line")
			} else { # $from sent to me
				$irc->write("PRIVMSG $from :$line")
			}
			verbose(2, "!w '$subject' -> '$line'");
		}
	} elsif($message =~ /^poccy\s*(\S+)$/i) {
		my $demon = $1;
		$irc->write("NICK garodemonkiller", sub { verbose(2, "Changed nick to 'garodemonkiller'"); } );
		$irc->write("PRIVMSG $demon :The power of Christ compels you !!! AWAY Demon !!! BE GOOOOOONE !!!");
		$irc->write("PRIVMSG $demon :https://www.youtube.com/watch?v=f0ZS9sImoOE");
		$irc->write("NICK $currentnick", sub { verbose(2, "Changed nick to '$currentnick'"); } );
		verbose(3,"!poccy to $demon\n");
	}
	#Handle messages that do different things for users with different rights
	elsif(defined $settings->{allowedusers}->{$from}) { allowedprivmsg($irc, $from, $to, $message); }
	else { notallowedprivmsg($irc, $from, $to, $message); }
} );

$irc->on( ctcp_version => sub {
	verbose(2, "Connected");
	if(defined $settings->{nickserv}) {
		verbose(2, "Identifying...");
		$irc->write("PRIVMSG NickServ :identify $settings->{nickserv}");
	}
} );

$irc->on( irc_notice => sub {
	my ($irc, $msghash) = @_;
	verbose(4, "Noticehash: ".Dumper($msghash));
	my $notice = @{$msghash->{params}}[1];
	my $from = IRC::Utils::parse_user($msghash->{prefix});
	verbose(2, "From '$from' this notice: '$notice'");
	verb4hex($notice);
	if($from eq "NickServ") {
		if($notice=~/You\s+are\s+now\s+identified\s+for\s+/i) {
			verbose(1, "Identified");
		} elsif($notice=~/Invalid\s+password\s+for\s+/i) {
			verbose(1, "Failed to identify");
		} else {
			verbose(1, "NickServ sent this: '$notice'");
		}
	}
} );

#Start the bot
Mojo::IOLoop->start;
