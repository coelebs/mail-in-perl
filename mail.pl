#!/usr/bin/perl 
################################################################################
# My perl mail thing, TODO-list                                                #
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
init_pair(1, COLOR_RED, -1);
init_pair(2, COLOR_WHITE, COLOR_GREEN);
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

##
# Print message to curses window, fullscreen
##
sub print_message {
	$win->clear;
	my $message = $messages[shift];
	my @from = $message->from;
	my @to = $message->to;
	my $header = "From: ".decode("MIME-Header", $from[0]->format)."\n";
	$header .= "To: ";
	$header .= decode("MIME-Header", $_->format).", " foreach(@to);
	$header .= "\nDate: ";
	$header .= strftime("%A %d %B %Y %H:%M", localtime(str2time($message->get('date'))))."\n";
	$header .= "Subject: ".decode("MIME-Header", $message->get('subject'))."\n";
	my @header = split(/\n/, $header);
	$win->attron(COLOR_PAIR(2));
	my $i = 0;
	foreach (@header) {
		$win->addstr($i, 0, " "x$win->getmaxx);
		$win->addstr($i, 0, $_);
		$i++;
	}
	#Set cursor to next line, to avoid the message to be printed right after
	#the subject header
	$win->addstr($i++, 0, "");

	$win->attroff(COLOR_PAIR(2));

	# If a message has multiple part, take the first part || just take the body
	# FIXME html decoding has to go here...
	my $formatter = Mail::Message::Convert::HtmlFormatText->new;

	my $body;
	if($message->body->isMultipart) {
		$body = $message->body->epilogue || $message->body->preamble;
		$_ = $message->body->part(0)->decoded->string;
	} else {
		$_ = $message->body->decoded->string;
	}

	my $offset = shift;
	my @text = split(/^/, $_);
	if(@text > $offset) {
		$i = $offset;
	} else {
		$i = 0;
	}

	for (; $i < @text; $i++) {
		last unless $i % $win->getmaxy < $win->getmaxy - 7;
		$win->addstr($text[$i]);
	}

	# Return the offset so we now if we are scrolled
	return $offset if $i > $offset;
}

##
# Print inbox to curses window full screen. Starts at oldest mail...
##
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

##
# Scrolls the cursor, and prints it
# it gives the current cursorline a different color, and yes that was stolen,
# like everything else, from mutt
##
sub scroll_cursor {
	my $prev = shift;
	my $new = shift;

	# if the new cursor is invalid, return the old one.
	return $prev if $new >= @messages || $new < 0; 

	# Check if the inbox window needs to switch page
	if($new - $offset >= $win->getmaxy) {
		$offset += $win->getmaxy;
		print_inbox($new);
	} elsif($new - $offset < 0) {
		$offset -= $win->getmaxy;
		print_inbox($new);
	}

	$win->addstr($prev - $offset, 0, "  ");
	inbox_print_message($messages[$prev], $prev - $offset);
	$win->attron(COLOR_PAIR(1));
	$win->addstr($new - $offset, 0, "> ");
	inbox_print_message($messages[$new], $new - $offset);
	$win->attroff(COLOR_PAIR(1));
	return $new;
}

##
#  Print the message line to the curses window
##
sub inbox_print_message {
	my $message = shift;
	my $line = shift;

	$win->addstr($line, 0, " "x$win->getmaxx);
	
	$win->addstr($line, 1, "2") if $message->body->isMultipart;

	$win->addstr($line, 2, 
		strftime("%d-%m-%Y %H:%M", localtime(str2time($message->get('date')))));
	my @from = $message->from;
	if($from[0]->phrase) {
		$_ = $from[0]->phrase;
		$_ = decode('MIME-Header', $_);
		s/["](.*)["]/$1/;
		$win->addstr($line, 20, substr($_, 0, 30));
	} else {
		$win->addstr($line, 20, substr($from[0]->address, 0, 30));
	}
	$_ = decode("MIME-Header", $message->get('subject')) || "(no subject)";
	#$_ = $message->get('subject') || "(no subject)";
	#my $subj = $message->study('subject');
	#$subj = $subj->decodedBody; 
	#Use of uninitialized value $decoded[0] in join or string at 
	#/usr/share/perl5/vendor_perl/Mail/Message/Field/Full.pm line 317.
	$win->addnstr($line, 52, $_, $win->getmaxx - 52);
}

##
# Loop for reading mail, makes that you can scroll etc
##
sub show_message {
	my $cursor = shift;
	my $offset = 0;
	print_message($cursor);
	
	$messages[$cursor]->labels(seen => 1);
	$messages[$cursor]->labelsToFilename;
	while((my $ch = $win->getch) ne 'q') {
		if($ch eq "\n") {
			$offset = print_message($cursor, $win->getmaxy + $offset);
		}
	}

	print_inbox($cursor);
}

##
# Inbox loop
##
sub show_inbox {
	my $start = 0;
	while((my $ch = $win->getch) ne 'q') {
		if($ch eq 'j') {
			$start = scroll_cursor($start++, $start);
		} elsif($ch eq 'k') {
			$start = scroll_cursor($start--, $start);
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
