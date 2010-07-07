#!/usr/bin/perl 
################################################################################
# My perl mail thing, TODO-list                                                #
# TODO colors                                                                  #
# TODO mailbox switching, maybe with sidebar oslt                              #
# FIXME decode html mail, but not text                                         #
################################################################################
use strict;
use warnings;
use Encode;# qw(decode);
use Mail::Box::Maildir;
use Mail::Message;
use Mail::Address;
use Mail::Message::Convert::HtmlFormatText;
use HTML::TreeBuilder;
use HTML::FormatText;
use Date::Parse;
use Email::Simple;
use Curses;
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
start_color;
use_default_colors();
noecho();
curs_set(0);

#move all messages from new/ to cur/ 
#This makes conky think they are read... Gmail however looks at the flags
$maildir->acceptMessages; 
my @messages = $maildir->messages;


print_inbox(0);
show_inbox();

# Stop curses, restore settings
endwin();

sub print_message {
	$win->clear;
	my $message = $messages[shift];
	my @from = $message->from;
	my @to = $message->to;
	my $text = "From: ".decode("MIME-Header", $from[0]->format)."\n";
	$text .= "To: ";
	$text .= decode("MIME-Header", $_->format).", " foreach(@to);
	$text .= "\nDate: ";
	$text .= strftime("%A %d %B %Y %H:%M", localtime(str2time($message->get('date'))))."\n";
	$text .= "Subject: ".decode("MIME-Header", $message->get('subject'))."\n";
	
	$text .= "\n";
	$text .= "-"x 80;
	$text .= "\n\n";
	$win->addstr(0, 0, $text); #Print header to curses

	if($message->body->isMultipart) {
		$text = $message->body->part(0)->decoded->string;
	} else {
		$text = $message->body->decoded->string;
	}
	my $offset = shift;
	my @text = split(/^/, $text);
	my $i;
	if(@text > $offset) {
		$i = $offset;
	} else {
		$i = 0;
	}

	for (; $i < @text; $i++) {
		last unless $i % $win->getmaxy < $win->getmaxy - 7;
		$win->addstr($text[$i]);
	}

	return $offset if $i > $offset;
}

sub print_inbox {
	$win->clear;
	if($offset < 0) {
		$offset = 0;
	} elsif($offset + $win->getmaxy > @messages) {
		$offset = @messages - $win->getmaxy;
	}

	for (my $i = 0; $i < $win->getmaxy || $i + $offset < @messages; $i++) {
		inbox_print_message($messages[$i + $offset], $i);
	}

	my $start = shift;
	scroll_cursor($start, $start);
}

sub scroll_cursor {
	my $prev = shift;
	my $new = shift;
	if($new - $offset > $win->getmaxy - 1) {
		$offset += $win->getmaxy;
		print_inbox($new);
	} elsif($new - $offset < 0) {
		$offset -= $win->getmaxy;
		print_inbox($new);
	}
	$win->addstr($prev - $offset, 0, "  ");
	$win->addstr($new - $offset, 0, "> ");
	$win->attroff(COLOR_PAIR(3));
}

sub inbox_print_message {
	my $message = shift;
	my $line = shift;

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
	$win->addnstr($line, 52, $_, $win->getmaxx - 52);
}

sub show_message {
	my $cursor = shift;
	my $offset = 0;
	print_message($cursor);
	
	$message->labels(seen => 1);
	$message->labelsToFilename;
	while((my $ch = $win->getch) ne 'q') {
		if($ch eq "\n") {
			$offset = print_message($cursor, $win->getmaxy + $offset);
		}
	}

	print_inbox($cursor);
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
