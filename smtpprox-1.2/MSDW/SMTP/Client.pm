#   This code is Copyright (C) 2001 Morgan Stanley Dean Witter, and
#   is distributed according to the terms of the GNU Public License
#   as found at <URL:http://www.fsf.org/copyleft/gpl.html>.
#
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
# Written by Bennett Todd <bet@rahul.net>

package MSDW::SMTP::Client;
use IO::Socket;

=head1 NAME

  MSDW::SMTP::Client --- SMTP client for content-scanning proxy

=head1 SYNOPSIS

  use MSDW::SMTP::Client;

  my $client = MSDW::SMTP::Client->new(interface => $interface,
				       port => $port);
  my %response;
  $response{banner} = $client->hear;
  $client->say("helo bunky");
  $response{helo} = $client->hear;
  $client->say("mail from: me");
  $response{from} = $client->hear;
  $client->say("rcpt to: you");
  $response{to} = $client->hear;
  $client->say("data");
  $response{data} = $client->hear;
  $client->yammer(FILEHANDLE);
  $response{dot} = $client->hear;
  $client->say("quit");
  $response{quit} = $client->hear;
  undef $client;

=head1 DESCRIPTION

MSDW::SMTP::Client provides a very lean SMTP client implementation;
the only protocol-specific knowlege it has is the structure of SMTP
multiline responses. All specifics lie in the hands of the calling
program; this makes it appropriate for a semi-transparent SMTP
proxy, passing commands between a talker and a listener.

=head1 METHODS

=over 8

=item new(interface => $interface, port => $port[, timeout = 300]);

The interface and port to talk to must be specified. The interface
must be a valid numeric IP address; the port must be numeric. If
this call succeeds, it returns a client structure with an open
IO::Socket::INET in it, ready to talk to. If it fails it dies,
so if you want anything other than an exit with an explanatory
error message, wrap the constructor call in an eval block and pull
the error out of $@ as usual. This is also the case for all other
methods; they succeed or they die. The timeout parameter is passed
on into the IO::Socket::INET constructor.

=item hear

hear collects a complete SMTP response and returns it with trailing
CRLF removed; for multi-line responses, intermediate CRLFs are left
intact. Returns undef if EOF is seen before a complete reply is
collected.

=item say("command text")

say sends an SMTP command, appending CRLF.

=item yammer(FILEHANDLE)

yammer takes a filehandle (which should be positioned at the
beginning of the file, remember to $fh->seek(0,0) if you've just
written it) and sends its contents as the contents of DATA. This
should only be invoked after a $client->say("data") and a
$client->hear to collect the reply to the data command. It will send
the trailing "." as well. It will perform leading-dot-doubling in
accordance with the SMTP protocol spec, where "leading dot" is
defined in terms of CR-LF terminated lines --- i.e. the data should
contain CR-LF data without the leading-dot-quoting. The filehandle
will be left at EOF.

=back

=cut

sub new {
    my ($this, @opts) = @_;
    my $class = ref($this) || $this;
    my $self = bless { timeout => 300, @opts }, $class;
    $self->{sock} = IO::Socket::INET->new(
	PeerAddr => $self->{interface},
	PeerPort => $self->{port},
	Timeout => $self->{timeout},
	Proto => 'tcp',
	Type => SOCK_STREAM,
    );
    die "$0: socket connect failure: $!\n" unless defined $self->{sock};
    return $self;
}

sub hear {
    my ($self) = @_;
    my ($tmp, $reply);
    return undef unless $tmp = $self->{sock}->getline;
    while ($tmp =~ /^\d{3}-/) {
	$reply .= $tmp;
	return undef unless $tmp = $self->{sock}->getline;
    }
    $reply .= $tmp;
    $reply =~ s/\r\n$//;
    return $reply;
}

sub say {
    my ($self, @msg) = @_;
    return unless @msg;
    $self->{sock}->print("@msg", "\r\n") or die "$0: write error: $!";
}

sub yammer {
    my ($self, $fh) = (@_);
    local (*_);
    local ($/) = "\r\n";
    while (<$fh>) {
	s/^\./../;
	$self->{sock}->print($_) or die "$0: write error: $!\n";
    }
    $self->{sock}->print(".\r\n") or die "$0: write error: $!\n";
}

1;
