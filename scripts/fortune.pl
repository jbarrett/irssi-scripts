# vim: filetype=perl

use strict;
use warnings;

use AnyEvent;
use Irssi;
use IPC::Open3;
use Carp;
use File::Which qw/which/;

=encoding utf8

=head1 NAME

fortune.pl - fortunes for your irssi bot

=head1 SYNOPSIS

  /script load fortune.pl

Irssi instance will respond to lines beggining with '!fortune'

=head1 DESCRIPTION

fortune.pl watches all channels and queries for lines beginning !fortune,

=head1 INSTALL

Place this script in F<~/.irssi/scripts>.

To load the script on startup, ln or cp it to  F<~/.irssi/scripts/autorun>

=head1 COMMANDS

To pull a random quote from all fortune files:

!fortune

To list available fortune files:

!fortune list

This does mean you cannot specify a fortune file named 'list'...

To pull a random quote from one of the files:

!fortune filename

=head1 DEPENDENCIES

Requires Perl modules Irssi, AnyEvent, Carp, File::Which and IPC::Open3.
Requires the 'fortune' program to be installed in the path.

=head1 AUTHOR

John Barrett <johna.barrett@gmail.com>

=cut

use vars qw($VERSION %IRSSI);
our $VERSION = '0.02';

%IRSSI = (
    authors     => 'John Barrett',
    contact     => 'johna.barrett@gmail.com',
    name        => 'fortune',
    description => 'Quotes from your fortune files',
    license     => 'GPLv3+',
    url         => 'https://github.com/jbarrett/irssi-scripts',
    changed     => '2012-11-24',
    version     => $VERSION
);

# Ref to store AnyEvent timers
my $timer;

# Verbose operation, status messages printed to window 1
my $VERBOSE = 1;
# Maximum line length
my $MAXLEN = 510;
# Interval between random fortunes, set to 0 to disable
my $INTERVAL = 600;
# Attempt to locate fortune binary.
my $FORTUNEBIN = which('fortune') or croak("fortune not installed in path");

sub send_fortune {
    my ( $server, $target, $file ) = @_;
    my ( $in, $out, $err, $pid );
    $file = ( split ' ', $file )[0] if ($file);    # Discard all but first
    my @flines;
    my $fortune;
    ($VERBOSE) && Irssi::print "Processing request from $target" . (($file)? " params : $file" : "");

    do {
        $pid = open3( $in, $out, $err, $FORTUNEBIN, ($file) ? $file : "-a" );
        waitpid( $pid, 0 );
        if ( $? >> 8 ) {
            carp("Trouble retrieving fortune");
            $server->command("msg $target No fortunes...");
            return 1;
        }
        chomp( @flines = <$out> );
        ( $fortune = join " ", @flines ) =~ s/\s+/ /g;
    } while ( length($fortune) > $MAXLEN );

    ($VERBOSE) && Irssi::print "Sending fortune : $fortune to $target";
    $server->command("msg $target $fortune");
}

sub send_list {
    my ( $server, $target ) = @_;
    my ( $in, $out, $err, $pid );
    my @files;
    my $flist;

    $pid = open3( $in, $out, $err, $FORTUNEBIN, "-af" );
    waitpid( $pid, 0 );
    if ( $? >> 8 ) {
        carp("Trouble retrieving fortune file list");
        $server->command("msg $target No fortunes...");
        return 1;
    }

    chomp( @files = <$out> );
    $flist = join ", ", map { ( split ' ' )[-1] } @files[ 1 .. $#files ];

    ($VERBOSE) && Irssi::print "Sending file list : $flist to $target";
    $server->command("msg $target Fortune files: $flist");
}

sub create_timer {
    my ( $server, $target ) = @_;

    my $tname = $server->{'address'} . $target;
    undef $timer->{$tname};
    $timer->{$tname} = AnyEvent->timer(
        after    => $INTERVAL,
        interval => $INTERVAL,
        cb       => sub { send_fortune( $server, $target ); }
    );
    ($VERBOSE) && Irssi::print "Timer named $tname created/restarted with $INTERVAL second interval";
}

sub event_privmsg {
    my ( $server, $data, $nick, $netmask ) = @_;
    my ( $target, $text ) = split / :/, $data, 2;

    if ( $target eq $server->{'nick'} ) {
        $target = $nick;
    }
    elsif ($INTERVAL) {
        create_timer( $server, $target );
    }

    if ( $text =~ /^!fortune/i ) {
        ( my $cmd = $text ) =~ s/!fortune\s*//;
        ( $VERBOSE && $cmd ) && Irssi::print "Command specified : $cmd";
        if ( $cmd =~ /^list/ ) {
            ($VERBOSE) && Irssi::print "Fortune file list requested from $target";
            send_list( $server, $target );
        }
        elsif ($cmd) {
            ($VERBOSE) && Irssi::print "Fortune requested from $target";
            send_fortune( $server, $target, $cmd );
        }
        else {
            ($VERBOSE) && Irssi::print "Fortune requested from $target";
            send_fortune( $server, $target );
        }
    }
}

sub event_join {
    my ( $server, $data, $nick, $address ) = @_;
    (my $target = $data) =~ s/://g;

    ($VERBOSE) && Irssi::print "Joined $target";
    return if ( $target eq $server->{'nick'} );
    create_timer( $server, $target );
}

sub event_part {
    my ( $server, $data, $nick, $netmask ) = @_;
    my ( $target, $text ) = split / :/, $data, 2;

    return if ( $target eq $server->{'nick'} );
    my $tname = $server->{'address'} . $target;
    undef $timer->{$tname};
    ($VERBOSE) && Irssi::print "Timer $tname deleted";
}

Irssi::signal_add( 'event privmsg', 'event_privmsg' );
Irssi::signal_add( "event part",    'event_part' );
Irssi::signal_add( "event join",    'event_join' );

