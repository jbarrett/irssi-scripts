# vim: filetype=perl

use strict;
use warnings;

use Irssi;

use vars qw($VERSION %IRSSI);
$VERSION = '0.01';
%IRSSI   = (
    authors     => 'John Barrett',
    contact     => 'johna.barrett@gmail.com',
    name        => '8ball',
    description => '8 Ball answers your questions... or flip a coin',
    license     => 'GPLv3+',
    url         => 'https://github.com/jbarrett/irssi-scripts',
    changed     => '2009-08-22',
    version     => $VERSION
);

sub eightball {
    my ( $server, $target ) = @_;
    state @answers = (
        "As I see it, yes",
        "It is certain",
        "It is decidedly so",
        "Most likely",
        "Outlook good",
        "Signs point to yes",
        "Without a doubt",
        "Yes",
        "Yes - definitely",
        "You may rely on it",
        "Reply hazy, try again",
        "Ask again later",
        "Better not tell you now",
        "Cannot predict now",
        "Concentrate and ask again",
        "Don't count on it",
        "My reply is no",
        "My sources say no",
        "Outlook not so good",
        "Very doubtful"
    );
    my $answer = int( rand(20) );
    $server->command(
        "msg $target The Magic 8-ball says: " . $answers[$answer] 
    );
}

sub event_privmsg {
    my ( $server, $data, $nick, $netmask ) = @_;
    my ( $target, $text ) = split / :/, $data, 2;

    if ( $text =~ /^!8ball/i ) {
        $text =~ s/!8ball[\ \t]*//;
        if ( !$text ) {
            $server->command(
                "msg $target You must ask the Magic 8 Ball a question to receive an answer!"
            );
        }
        else {
            eightball( $server, $target );
        }

    }
    elsif ( $text =~ /^!flip/i ) {
        $server->command( 
              "msg $target Coin flip: "
            . ( int( rand(2) ) ? "Heads" : "Tails" )
            . "!" );
    }
}

Irssi::signal_add( 'event privmsg', 'event_privmsg' );

