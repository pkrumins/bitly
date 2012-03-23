#
# Peteris Krumins (peteris.krumins@gmail.com, twitter: @pkrumins)
# http://www.catonmat.net -- good coders code, great coders reuse
#

package bitly;

use warnings;
use strict;

use Carp;
use JSON;
use LWP::UserAgent;
use LWP::Debug qw(+);
use HTTP::Request::Common;
use HTTP::Cookies;

sub new {
    my $class = shift;
    croak "bitly->new() takes (user, pass) as args" unless @_ == 2;
    my ($user, $pass) = @_;

    my $jar = HTTP::Cookies->new(hide_cookie2 => 1);
    my $lwp = _new_lwp($jar);

    #$lwp->add_handler("request_send",  sub { shift->dump; return });
    #$lwp->add_handler("response_done",  sub { shift->dump; return });

    my $self = {
        jar => $jar,
        lwp => $lwp,
        user => $user,
        pass => $pass
    };
    bless $self, $class;
    return $self;
}

sub shorten {
    my ($self, $url) = @_;
    my $json = $self->_shorten($url);
    return unless $json;
    return $json->{data}->{url};
}

sub shorten_custom {
    my ($self, $url, $custom) = @_;
    my $json = $self->_shorten($url);

    return unless $json;

    my $user_cookie = _extract_user_cookie($self->{jar});
    unless ($user_cookie) {
        $self->{error} = "Failed extracting user cookie.";
        return;
    }

    my $lwp = _new_lwp();

    my $request = POST('https://bitly.com/data/keyword/',
        {
            keyword => $custom,
            hash => $json->{data}->{hash},
            url => $json->{data}->{url}
        },
        "Host" => "bitly.com",
        "Origin" => "http://bitly.com",
        "Referer" => "http://bitly.com/",
        "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With" => "XMLHttpRequest",
        "X-XSRFToken" => $self->{xsrf},
        "Cookie" => "_xsrf=$self->{xsrf}; user=$user_cookie"
    );

    my $resp = $lwp->request($request);

    unless ($resp->is_success) {
        $self->{error} = "Failed customizing your shortened URL. See resp object for details.";
        $self->{resp} = $resp;
        return;
    }

    eval {
        $json = decode_json($resp->decoded_content);
    };
    if ($@) {
        $self->{error} = "Failed JSON decoding custom shortened response. Error was: $@";
        $self->{resp} = $resp;
        return;
    }

    unless ($json->{status_code} == 200) {
        $self->{error} = "Failed shortening your URL. Response from bitly was: $json->{status_txt}";
        $self->{resp} = $resp;
        return;
    }

    return $json->{data}->{url};
}

sub _shorten {
    my $self = shift;
    my $url = shift;

    unless ($self->{loggedin}) {
        my $resp = $self->{lwp}->get('http://bitly.com/');
        unless ($resp->is_success) {
            $self->{error} = "Failed getting http://bitly.com/. See resp object for details.";
            $self->{resp} = $resp;
            return;
        }

        $resp = $self->{lwp}->get('http://bitly.com/a/sign_in');
        unless ($resp->is_success) {
            $self->{error} = "Failed getting http://bitly.com/a/sign_in. See resp object for details.";
            $self->{resp} = $resp;
            return;
        }
        my $xsrf = _extract_xsrf($resp->decoded_content);
        unless ($xsrf) {
            $self->{error} = "Failed extracting xsrf from sing in page. See resp object for details.";
            $self->{resp} = $resp;
            return;
        }
        $resp = $self->{lwp}->post('http://bitly.com/a/sign_in',
            {
                username => $self->{user},
                password => $self->{pass},
                signIn => "Sign In",
                _xsrf => $xsrf
            }
        );
        unless ($resp->is_success) {
            $self->{error} = "Failed logging into http://bitly.com/a/sign_in. See resp object for details.";
            $self->{resp} = $resp;
            return;
        }

        $self->{xsrf} = $xsrf;

        unless ($resp->decoded_content =~ m|/u/$self->{user}|) {
            $self->{error} = "Login incorrect or bit.ly have redesigned. See resp object for details.";
            $self->{resp} = $resp;
            return;
        }

        $self->{loggedin} = 1;
    }

    my $user_cookie = _extract_user_cookie($self->{jar});
    unless ($user_cookie) {
        $self->{error} = "Failed extracting user cookie.";
        return;
    }

    my $lwp = _new_lwp();

    my $request = POST('http://bitly.com/data/shorten/', { url => $url },
        "Host" => "bitly.com",
        "Origin" => "http://bitly.com",
        "Referer" => "http://bitly.com/",
        "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With" => "XMLHttpRequest",
        "X-XSRFToken" => $self->{xsrf},
        "Cookie" => "_xsrf=$self->{xsrf}; user=$user_cookie"
    );

    my $resp = $lwp->request($request);

# for some reason the cookies in the existing jar won't work
# bit.ly just keeps returning 405 unknown error.
# so i created a new useragent and set cookies myself (above)
# below is code that i used before 

#    my $request = POST('http://bitly.com/data/shorten/', { url => $url },
#        "Host" => "bitly.com",
#        "Origin" => "http://bitly.com",
#        "Accept" => "application/json, text/javascript, */*; q=0.01",
#        "Accept_Charset" => "ISO-8859-1,utf-8;q=0.7,*;q=0.3",
#        "Accept_Language" => "en-us,en;q=0.5",
#        "Accept_Encoding" => "gzip,deflate",
#        "Keep-Alive" => 300,
#        "Connection" => "keep-alive",
#        "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
#        "X-Requested-With" => "XMLHttpRequest",
#        "X-XSRFToken" => $self->{xsrf},
#        "Referer" => "http://bitly.com/",
#    );
#
#    my $resp = $self->{lwp}->request($request);

# this wont work either, i had it before using POST above

#    my $resp = $self->{lwp}->post('http://bitly.com/data/shorten/',
#        {
#            url => $url
#        },
#        "X-XSRFToken" => $self->{xsrf},
#        "Host" => "bitly.com",
#        "Origin" => "http://bitly.com",
#        "X-Requested-With" => "XMLHttpRequest",
#        "Referer" => "arnold"
#    );

    unless ($resp->is_success) {
        $self->{error} = "Failed shortening your URL. See resp object for details.";
        $self->{resp} = $resp;
        return;
    }

    my $json;
    eval {
        $json = decode_json($resp->decoded_content);
    };
    if ($@) {
        $self->{error} = "Failed JSON decoding shortened response. Error was: $@";
        $self->{resp} = $resp;
        return;
    }

    unless ($json->{status_code} == 200) {
        $self->{error} = "Failed shortening your URL. Response from bitly was: $json->{status_txt}";
        $self->{resp} = $resp;
        return;
    }

    return $json;
}

sub _new_lwp {
    my $jar = shift || {};
    LWP::UserAgent->new(
        agent => "Mozilla/5.0 (Windows NT 5.1) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.79 Safari/535.11",
        cookie_jar => $jar,
        requests_redirectable => ['GET', 'HEAD', 'POST']
    );
}

sub _extract_user_cookie {
    my $jar = shift;
    my $cookies = $jar->as_string;
    return _extract($cookies, qr/user=(.+);/);
}

sub _extract_xsrf {
    my $page = shift;
    return _extract($page, qr/input type="hidden" name="_xsrf" value="(.+?)"/);
}

sub _extract {
    my ($str, $rx) = @_;
    my ($x) = $str =~ /$rx/;
    return $x;
}

1;
