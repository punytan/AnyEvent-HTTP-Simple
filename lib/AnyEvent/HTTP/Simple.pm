package AnyEvent::HTTP::Simple;
use strict;
use AnyEvent::HTTP ();
use HTTP::Request::Common ();
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use Any::Moose;

our $VERSION = '0.02';

has timeout    => (is => 'rw', isa => 'Int', default => sub { 30 });
has agent      => (is => 'rw', isa => 'Str', default => sub { join "/", __PACKAGE__, $VERSION });
has cookie_jar => (is => 'rw', isa => 'HTTP::Cookies', default => sub { my $jar = HTTP::Cookies->new; $jar; });

sub get    { _request(GET => @_) }
sub head   { _request(HEAD => @_) }
sub post   { _request(POST => @_) }
sub put    { _request(PUT => @_) }
sub delete { _request(DELETE => @_) }

sub _request {
    my $cb     = pop;
    my $method = shift;
    my $self   = shift;
    no strict 'refs';
    my $req = &{"HTTP::Request::Common::$method"}(@_);
    $self->request($req, $cb);
}

sub request {
    my ($self, $request, $cb) = @_;

    $request->headers->user_agent($self->agent);
    $self->cookie_jar->add_cookie_header($request);

    my %options = (
        timeout => $self->timeout,
        headers => $request->headers,
        body    => $request->content,
    );

    AnyEvent::HTTP::http_request $request->method, $request->uri, %options, sub {
        my ($body, $header) = @_;

        if (defined $header->{'set-cookie'}) {
            my @cookies;
            my $set_cookie = $header->{'set-cookie'};

            my @tmp = split(/,/, $set_cookie);
            while (@tmp) {
                my $t1 = shift @tmp;
                my $t2 = shift @tmp;
                push @cookies, "$t1,$t2";
            }

            $header->{'set-cookie'} = \@cookies;
        }

        my $res = HTTP::Response->new($header->{Status}, $header->{Reason});
        $res->request($request);
        $res->header(%$header);
        $self->cookie_jar->extract_cookies($res);
        
        $cb->($body, $header);
    };
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

AnyEvent::HTTP::Simple - AnyEvent::HTTP wrapper

=head1 SYNOPSIS

    use AnyEvent::HTTP::Simple;
    use HTTP::Cookies;
    use Data::Dumper;

    my $client = AnyEvent::HTTP::Simple->new();
    my $cookie_jar = HTTP::Cookies->new();

    $client->cookie_jar($cookie_jar);

    my $url  = 'https://secure.nicovideo.jp/secure/login?site=niconico';

    my $cv = AE::cv;
    $client->post($url, [ mail => '', password => '' ], sub {
        print Dumper $_[1], $client->cookie_jar;
        $client->get('http://www.nicovideo.jp/', sub {
            print Dumper $_[1], $client->cookie_jar;
        });
    });
    $cv->recv;

=head1 DESCRIPTION

AnyEvent::HTTP::Simple is a wrapper around AnyEvent::HTTP with cookies and some additional headers. 

The get() and post() methods behave the same as http_request but $hdr->{'set-cookie'}.
AnyEvent::HTTP::http_request returns $hdr->{'set-cookie'} as string, but this behavior cause a problem. (HTTP::Cookies cannot parse stringified Set-Cookie header.) 
Using this module, you would get $hdr->{'set-cookie'} as arrayref.

If you want to login into cookies-required web service, you should use callback. For example,

    $client->post($login_form, [ username => '', passowrd => ''  ], sub {
        my ($body1, $hdr1) = @_;
        $client->get($content_url, sub {
            my ($body2, $hdr2) = @_;
            # $body2
        });
    });

=head2 The reason why this module uses HTTP::Cookies to process cookie

=over 4

=item *

As far as I know, passing hashref style cookie_jar to AE::HTTP::http_request is too ridiculous to make time to write cookie parser.

=item *

I think that it would be better off using trusted modules (like HTTP::Cookies) than writing a own parser.

=item *

Thinking existence of security problem, it's a nightmare.

=back

=head1 METHODS

See also DESCRIPTION. You have to pay attention to use get() or post() method.

=over 4

=item AnyEvent::HTTP::Simple->new

Constructor.

=item $client->timeout

=item $client->timeout($seconds)

You can get/set the timeout.

=item $client->agent

=item $client->agent($user_agent_name)

This is used to get/set an User-Agent header into HTTP request headers.

=item $client->cookie_jar

=item $client->cookie_jar($cookie_jar)

This is used to get/set the HTTP::Cookies object. Usage is very similar to LWP::UserAgent.

=item $client->get($url, $cb)

This method is a wrapper for HTTP::Request::Common::GET(). The last argument must be a callback.

=item $client->post($url, [], $cb) 

This method is a wrapper for HTTP::Request::Common::POST(). The last argument must be a callback.
If you want post content, see SYNOPSIS. There is an example. For more details, see also HTTP::Request::Common.

=back

=head1 AUTHOR

punytan E<lt>punytan@gmail.comE<gt>

=head1 SEE ALSO

L<Tatsumaki::HTTPClient> L<HTTP::Request::Common> L<AnyEvent::HTTP>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
