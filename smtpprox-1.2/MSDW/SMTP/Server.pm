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

package MSDW::SMTP::Server;
use IO::Socket;
use IO::File;

=head1 NAME

  MSDW::SMTP::Server --- SMTP server for content-scanning proxy

=head1 SYNOPSIS

  use MSDW::SMTP::Server;

  my $server = MSDW::SMTP::Server->new(interface => $interface,
				       port => $port);
  while (1) {
    # prefork here
    $server->accept([options]);
    # per-connect fork here
    $server->ok("220 howdy");
    while (my $what = $server->chat) {
      if ($what =~ /^mail/i) {
	if (isgood($server->{from})) {
	  $server->ok([ ack msg ]);
	} else {
	  $server->fail([ fail msg ]);
	}
      } elsif ($what =~ /^rcpt/i) {
	if (isgood(@{$server}{qw(from to)})) {
	  $sever->ok([ ack msg ]);
	} else {
	  $server->fail([ fail msg ]);
	}
      } elsif ($what =~ /^data/i) {
	if (isgood(@{$server}{qw(from to)})) {
	  # NB to is now an array of all recipients
	  $self->ok("354 natter on.");
	} else {
	  $self->fail;
	}
      } elsif ($what eq '.') {
        if (isgood(@server->{from,to,data})) {
	  $server->ok;
	} else {
	  $server->fail;
	}
      } else {
        # deal with other msg types as you will
	die "can't happen";
      }
      # process $server->{from,to,data} here
      $server->ok; # or $server->fail;
    }
  }

=head1 DESCRIPTION

MSDW::SMTP::Server fills a gap in the available range of Perl SMTP
servers. The existing candidates are not suitable for a
high-performance, content-scanning robust SMTP proxy. They insist on
heavy-weight structuring and parsing of the body, and they
acknowledge receipt of the data before returning control to the
caller.

This server simply gathers the SMTP acquired information (envelope
sender and recipient, and data) into unparsed memory buffers (or a
file for the data), and returns control to the caller to explicitly
acknowlege each command or request. Since acknowlegement or failure
are driven explicitly from the caller, this module can be used to
create a robust SMTP content scanning proxy, transparent or not as
desired.

=head1 METHODS

=over 8

=item new(interface => $interface, port => $port);

The interface and port to listen on must be specified. The interface
must be a valid numeric IP address (0.0.0.0 to listen on all
interfaces, as usual); the port must be numeric. If this call
succeeds, it returns a server structure with an open
IO::Socket::INET in it, ready to listen on. If it fails it dies, so
if you want anything other than an exit with an explanatory error
message, wrap the constructor call in an eval block and pull the
error out of $@ as usual. This is also the case for all other
methods; they succeed or they die.

=item accept([debug => FD]);

accept takes optional args and returns nothing. If an error occurs
it dies, otherwise it returns when a client connects to this server.
This is factored out as a separate entry point to allow preforking
(e.g. Apache-style) or fork-per-client strategies to be implemented
on the common protocol core. If a filehandle is passed for debugging
it will receive a complete trace of the entire SMTP dialogue, data
and all. Note that nothing in this module sends anything to the
client, including the initial login banner; all such backtalk must
come from the calling program.

=item chat;

The chat method carries the SMTP dialogue up to the point where any
acknowlegement must be made. If chat returns true, then its return
value is the previous SMTP command. If the return value begins with
'mail' (case insensitive), then the attribute 'from' has been filled
in, and may be checked; if the return value begins with 'rcpt' then
both from and to have been been filled in with scalars, and should
be checked, then either 'ok' or 'fail' should be called to accept
or reject the given sender/recipient pair. If the return value is
'data', then the attributes from and to are populated; in this case,
the 'to' attribute is a reference to an anonymous array containing
all the recipients for this data. If the return value is '.', then
the 'data' attribute (which may be pre-populated in the "new" or
"accept" methods if desired) is a reference to a filehandle; if it's
created automatically by this module it will point to an unlinked
tmp file in /tmp. If chat returns false, the SMTP dialogue has been
completed and the socket closed; this server is ready to exit or to
accept again, as appropriate for the server style.

The return value from chat is also remembered inside the server
structure in the "state" attribute.

=item ok([message]);

Approves of the data given to date, either the recipient or the
data, in the context of the sender [and, for data, recipients]
already given and available as attributes. If a message is given, it
will be sent instead of the internal default.

=item fail([message]);

Rejects the current info; if processing from, rejects the sender; if
processing 'to', rejects the current recipient; if processing data,
rejects the entire message. If a message is specified it means the
exact same thing as "ok" --- simply send that message to the sender.

=back

=cut

sub new {
    my ($this, @opts) = @_;
    my $class = ref($this) || $this;
    my $self = bless { @opts }, $class;
    $self->{sock} = IO::Socket::INET->new(
	LocalAddr => $self->{interface},
	LocalPort => $self->{port},
	Proto => 'tcp',
	Type => SOCK_STREAM,
	Listen => 65536,
	Reuse => 1,
    );
    die "$0: socket bind failure: $!\n" unless defined $self->{sock};
    $self->{state} = 'just bound',
    return $self;
}

sub accept {
    my ($self, @opts) = @_;
    %$self = (%$self, @opts);
    ($self->{"s"}, $self->{peeraddr}) = $self->{sock}->accept or
	die "$0: accept failure: $!\n";
    $self->{state} = ' accepted';
}


sub chat {
    my ($self) = @_;
    local(*_);
    if ($self->{state} !~ /^data/i) {
	return 0 unless defined($_ = $self->getline);
	s/[\r\n]*$//;
	$self->{state} = $_;
	if (s/^helo\s+//i) {
	    s/\s*$//;s/\s+/ /g;
	    $self->{helo} = $_;
	} elsif (s/^rset\s*//i) {
	    delete $self->{to};
	    delete $self->{data};
	    delete $self->{recipients};
	} elsif (s/^mail\s+from:\s*//i) {
	    delete $self->{to};
	    delete $self->{data};
	    delete $self->{recipients};
	    s/\s*$//;
	    $self->{from} = $_;
	} elsif (s/^rcpt\s+to:\s*//i) {
	    s/\s*$//; s/\s+/ /g;
	    $self->{to} = $_;
	    push @{$self->{recipients}}, $_;
	} elsif (/^data/i) {
	    $self->{to} = $self->{recipients};
	}
    } else {
	if (defined($self->{data})) {
	    $self->{data}->seek(0, 0);
	    $self->{data}->truncate(0);
	} else {
	    $self->{data} = IO::File->new_tmpfile;
	}
	while (defined($_ = $self->getline)) {
	    if ($_ eq ".\r\n") {
		$self->{data}->seek(0,0);
		return $self->{state} = '.';
	    }
	    s/^\.\./\./;
	    $self->{data}->print($_) or die "$0: write error saving data\n";
	}
	return(0);
    }
    return $self->{state};
}

sub getline {
    my ($self) = @_;
    local ($/) = "\r\n";
    return $self->{"s"}->getline unless defined $self->{debug};
    my $tmp = $self->{"s"}->getline;
    $self->{debug}->print($tmp) if ($tmp);
    return $tmp;
}

sub print {
    my ($self, @msg) = @_;
    $self->{debug}->print(@msg) if defined $self->{debug};
    $self->{"s"}->print(@msg);
}

sub ok {
    my ($self, @msg) = @_;
    @msg = ("250 ok.") unless @msg;
    $self->print("@msg\r\n") or
	die "$0: write error acknowledging $self->{state}: $!\n";
}

sub fail {
    my ($self, @msg) = @_;
    @msg = ("550 no.") unless @msg;
    $self->print("@msg\r\n") or
	die "$0: write error acknowledging $self->{state}: $!\n";
}

1;
