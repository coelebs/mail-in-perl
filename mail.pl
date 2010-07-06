#!/usr/bin/perl 
use strict;
use warnings;
use Mail::Box::Maildir;
use Mail::Message;
use Mail::Address;
use Date::Parse;
use Email::Simple;
use Curses;
use Encode qw(decode);
use POSIX qw(strftime);

my $maildir = Mail::Box::Maildir->new(
		folder => '/home/vincent/.mail/vincent@vincentkriek.nl/INBOX',
	);

#################################################
## Init, create new curses, read messages from ##
## folder                                      ##
#################################################
my $win = new Curses;
my $offset = 0;
noecho();
curs_set(0);

my @messages = $maildir->messages;

print_inbox();
show_inbox();

# Stop curses, restore settings
endwin();

sub print_message {
	$win->clear;
	my $message = $messages[shift];
	my @from = $message->from;
	my $text = "From: ".$from[0]->format."\n";
	$text .= "To: ";
	my @to = $message->to;
	$text .= $_->format.", " foreach(@to);
	$text .= "\nDate: ";
	$text .= strftime("%A %d %B %Y %H:%M", localtime(str2time($message->get('date'))))."\n";
	
	$text .= "\n\n";
	$text .= "-"x 80;
	$text .= "\n\n";

	if($message->body->isMultipart) {
		$text .= $message->body->part(0)->decoded->string;
	} else {
		$text .= $message->body->decoded->string;
	}
	my $i = 0;
	for(split(/^/, $text)) {
		$win->addstr($i++, 0, $_);
	}
}

sub print_inbox {
	#my $offset = $cursor - $win->getmaxy + 1;
	$win->clear;
	if($offset < 0) {
		$offset = 0;
	} elsif($offset + $win->getmaxy > @messages) {
		$offset = @messages - $win->getmaxy;
	}

	for (my $i = 0; $i < $win->getmaxy || $i + $offset < @messages; $i++) {
		inbox_print_message($messages[$i + $offset], $i);
	}
}

sub scroll_cursor {
	my $prev = shift;
	my $new = shift;
	if($new - $offset > $win->getmaxy - 1) {
		$offset += $win->getmaxy;
		print_inbox();
	} elsif($new - $offset < 0) {
		$offset -= $win->getmaxy;
		print_inbox();
	}
	$win->addstr($new - $offset, 0, "> ");
	$win->addstr($prev - $offset, 0, "  ");
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
	#$_ = $message->get('subject') || "(no subject)";
	#my $subj = $message->study('subject');
	#$subj = $subj->decodedBody; 
	#Use of uninitialized value $decoded[0] in join or string at 
	#/usr/share/perl5/vendor_perl/Mail/Message/Field/Full.pm line 317.
	$win->addstr($line, 52, $_);
}

sub show_message {
	print_message(shift);
	while((my $ch = $win->getch) ne 'q') {
		
	}
	print_inbox();
}

sub show_inbox {
	my $start = 0;
	while((my $ch = $win->getch) ne 'q') {
		if($ch eq 'j') {
			#$start = print_inbox(++$start);
			scroll_cursor($start, $start + 1);
			$start++;
		} elsif($ch eq 'k') {
			scroll_cursor($start--, $start);
		} elsif($ch eq "\n") {
			show_message($start);
		} elsif($ch eq "G") {
			$win->clear;
			$start = @messages - 1;
			print_inbox($start);
		} elsif($ch eq "g") {
			next unless $win->getch eq 'g';
			$win->clear;
			$start = 0;
			print_inbox($start);
		}
	}
}
