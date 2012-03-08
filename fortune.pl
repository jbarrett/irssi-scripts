# vim: filetype=perl

use strict;
use warnings;

use Irssi;
use AnyEvent;

use vars qw($VERSION %IRSSI);
$VERSION = '0.01';
%IRSSI   = (
    authors     => 'John Barrett',
    contact     => 'johna.barrett@gmail.com',
    name        => 'fortune',
    description => 'Quotes from your fortune files',
    license     => 'GPLv3+',
    url         => 'https://github.com/jbarrett/irssi-scripts',
    changed     => '2010-02-21',
    version     => $VERSION
);

my %timer;
my $DEBUG    = 1;      # Debug messages in status window
my $MAXLEN   = 512;    # Maximum line length
my $INTERVAL = 600;    # Interval between random fortunes, set to 0 to disable
my $FORTUNEBIN = '/usr/games/fortune';    # Fortune binary location

sub spit_fortune {
    my ( $server, $target, $file ) = @_;
    my $fortunecmd;
    if ($file) {
        $fortunecmd = "$FORTUNEBIN $file 2>&1";
    }
    else {
        $fortunecmd = "$FORTUNEBIN -a 2>&1";
    }
    my $fortune = `$fortunecmd`;
    if ( $? != 0 ) {
        return (1);
    }
    $fortune =~ s/[\r\n]+/\ /g;
    $fortune =~ s/[\ \t]+/\ /g;
    while ( length($fortune) > $MAXLEN ) {
        $fortune = `$fortunecmd`;
        $fortune =~ s/[\r\n]+/\ /g;
        $fortune =~ s/[\ \t]+/\ /g;
    }
    Irssi::print( "Fortune: $fortune :: length: " . length($fortune) );
    $server->command("msg $target $fortune");
}

sub spit_list {
    my ( $server, $target ) = @_;
    my @list  = `fortune -af 2>&1`;
    my $flist = "";
    my $first = 1;
    foreach my $line (@list) {
        if ( !( $line =~ /\// ) ) {
            if ( $first == 1 ) {
                $first = 0;
            }
            else {
                $flist .= ", ";
            }
            $line =~ s/[\ \t]*___%[\ ]*//;
            $flist .= $line;
        }
    }
    $server->command("msg $target Fortune files: $flist");

}

sub event_privmsg {
    my ( $server, $data, $nick, $netmask ) = @_;
    my ( $target, $text ) = split / :/, $data, 2;
    my $createtimer = 1;
    if ( $target eq $server->{nick} ) {
        $target      = $nick;
        $createtimer = 0;
    }
    if ( ( $INTERVAL > 0 ) && ( $createtimer == 1 ) ) {
        $tname = $server->{chatnet} . "|" . $target;
        undef $timer{$tname};
        $timer{$tname} = AnyEvent->timer(
            after    => $INTERVAL,
            interval => $INTERVAL,
            cb       => sub { spit_fortune( $server, $target ); }
        );
        Irssi::print $tname
          . " - created/restarted timer with $INTERVAL second interval";
    }

    if ( $text =~ /^!fortune/i ) {
        ( my $cmd = $text ) =~ s/!fortune[\ \t]*//;
        Irssi::print "cmd $cmd";
        if ( $cmd =~ /^list/ ) {
            spit_list( $server, $target );
        }
        elsif ( $cmd =~ /[a-zA-Z0-9\.]+/ ) {
            spit_fortune( $server, $target, $cmd );
        }
        else {
            spit_fortune( $server, $target );
        }

    }
}

sub event_part {
    my ( $server, $data, $nick, $netmask ) = @_;
    my ( $target, $text ) = split / :/, $data, 2;
    if ( $target eq $server->{nick} ) {
        $target = $nick;
    }
    if ( $nick eq $server->{'nick'} ) {
        $tname = $server->{chatnet} . "|" . $target;
        Irssi::print $tname. " - destroying timer";
        undef $timer{$tname};
    }
}

Irssi::signal_add( 'event privmsg', 'event_privmsg' );
Irssi::signal_add( "event part",    'event_part' );

