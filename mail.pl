#!/usr/bin/perl 
use strict;
use warnings;
use Mail::Box::Maildir;
use Mail::Message;
use Mail::Message::Convert::EmailSimple;
use Date::Parse;
use Email::Simple;
use Curses;
use Encode qw(decode);
use POSIX qw(strftime);

my $maildir = Mail::Box::Maildir->new(
		folder => '/home/vincent/.mail/vincent@vincentkriek.nl/INBOX',
	);

my $win = new Curses;
noecho();
curs_set(0);
init_pair(1, COLOR_RED, COLOR_BLACK);
my @messages = $maildir->messages();
			print_inbox();
show_inbox();
endwin();

sub print_message {
	$win->clear;
	my $message = $messages[shift];
	if($message->body->isMultipart) {
		$message = $message->body->part(0);
		my $text = $message->decoded->string();
		$win->addstr(10, 20, $text);
	} else {
		$win->addstr(10, 20, $message->body->decoded->string());
	}
}

sub print_inbox {
	my $cursor = shift // 0;
	if($cursor < 0) {
		$cursor = 0;
	} elsif($cursor > @messages) {
		$cursor = @messages;
	}

	my $offset = $cursor - $win->getmaxy + 1;
	if($offset < 0) {
		$offset = 0;
	}

	for (my $i = 0; $i < $win->getmaxy() && $i + $offset < @messages; $i++) {
		if($cursor == $i + $offset) {
			$win->attron(COLOR_PAIR(1));
			inbox_print_message($messages[$i + $offset], $i, 1);
			$win->attroff(COLOR_PAIR(1));
		} else {
			inbox_print_message($messages[$i + $offset], $i);
		}

	}
	return $cursor;
}

sub inbox_print_message {
	my $message = shift;
	my $line = shift;
	if(shift) {
		$win->addstr($line, 0, "> ");
	} else {
		$win->addstr($line, 0, "  ");
	}

	$win->addstr($line, 2, 
		strftime("%d-%m-%Y %H:%M", localtime(str2time($message->get('date')))));
	my @from = $message->from;
	if($from[0]->phrase) {
		$_ = $from[0]->phrase;
		$_ = decode('MIME-Header', $_);
		s/["](.*)["]/$1/;
		$win->addstr($line, 20, substr($_, 0, 30)."\n");
	} else {
		$win->addstr($line, 20, substr($from[0]->address, 0, 30)."\n");
	}
	$_ = decode("MIME-Header", $message->get('subject')) || "(no subject)";
	#my $subj = $message->study('subject');
	#$subj = $subj->decodedBody(); 
	#Use of uninitialized value $decoded[0] in join or string at 
	#/usr/share/perl5/vendor_perl/Mail/Message/Field/Full.pm line 317.
	$win->addstr($line, 52, $_);
}

sub show_message {
	my $message = shift;
	while((my $ch = $win->getch) ne 'q') {
		
	}
	
}

sub show_inbox {
	my $start = 0;
	while((my $ch = $win->getch) ne 'q') {
		if($ch eq 'j') {
			$win->clear;
			$start = print_inbox(++$start);
		} elsif($ch eq 'k') {
			$win->clear;
			$start = print_inbox(--$start);
		} elsif($ch eq "\n") {
			print_message($start);
		} elsif($ch eq "G") {
			$win->clear;
			$start = @messages - 1;
			print_inbox($start);
		} elsif($ch eq "g") {
			next unless $win->getch() eq 'g';
			$win->clear;
			$start = 0;
			print_inbox($start);
		}
	}
	$win->refresh;
}
