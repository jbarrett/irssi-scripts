# vim: filetype=perl

use warnings;
use strict;

use LWP::UserAgent;
use HTML::TreeBuilder;
use HTML::FormatText;
use Irssi;

use vars qw($VERSION %IRSSI);
$VERSION = '0.01';
%IRSSI   = (
    authors     => 'John Barrett',
    contact     => 'johna.barrett@gmail.com',
    name        => 'bashbot',
    description => 'Gives random quotes from bash.org/qdb.us',
    license     => 'GPLv3+',
    url         => 'https://github.com/jbarrett/irssi-scripts',
    changed     => '2009-09-02',
    version     => $VERSION
);

my @quotes;
my $maxlen = 440;

sub get_page {
    my $url = shift;
    my $ua  = LWP::UserAgent->new;
    my $response;
    $ua->timeout(5);
    $ua->agent("BashBot $VERSION");
    $response = $ua->get("$url");
    if ( $response->is_success ) {
        return $response->decoded_content;    # or whatever
    }
    0;
}

sub html_to_txt {
    my $html      = shift;
    my $tree      = HTML::TreeBuilder->new->parse_content($html);
    my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 90 );
    return $formatter->format($tree);
}

sub txt_to_quotes {
    my $text  = shift;
    my @lines = split( /[\r\n]/, $text );
    my $quote = "";
    @quotes = ();
    splice( @lines, 0,  7 );
    splice( @lines, -8, 8 );
    for my $line (@lines) {
        if ( $line =~ /^#[0-9]+\ / ) {
            if ($quote) {
                $quote =~ s/-\+\ $//;
                push( @quotes, $quote );
                $quote = "";
            }
        }
        else {
            if ($line) {
                $quote .= $line . " ";
            }
        }
    }
    $quote =~ s/-\+\ $//;
    push( @quotes, $quote );
}

sub get_quote {
    my $quote;
    do {
        $quote = pop(@quotes);

        if ( !defined $quote ) {
            Irssi::print "Getting quote page!";
            txt_to_quotes(
                html_to_txt(
                    get_page(
                        ( rand() > .5 )
                        ? "http://bash.org/?random1"
                        : "http://qdb.us/random"
                    )
                )
            );
            $quote = pop(@quotes);
        }
    } while ( $quote && length($quote) > $maxlen );
    return $quote;
}

sub event_privmsg {
    my ( $server, $data, $nick, $netmask ) = @_;
    my ( $target, $text ) = split / :/, $data, 2;

    # Handle /msg target
    if ( $target eq $server->{nick} ) {
        $target = $nick;
    }
    if ( $text =~ /^!bash/i ) {
        $server->command( "msg $target " . get_quote() );
    }
}

Irssi::signal_add( 'event privmsg', 'event_privmsg' );

