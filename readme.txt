#
# Peteris Krumins (peteris.krumins@gmail.com, twitter: @pkrumins)
# http://www.catonmat.net -- good coders code, great coders reuse
#

Shorten bitly urls without api, plus shorten to custom keywords, too!

Here is how to shorten a URL:

    use bitly;

    my $bitly = bitly->new('username', 'password');
    my $url = bitly->shorten('http://www.url.com');

    unless ($url) {
        say $bitly->{error};
    }
    else {
        say $url;
    }

Here is how to shorten a URL to a custom keyword:

    use bitly;

    my $bitly = bitly->new('username', 'password');
    my $url = bitly->shorten_custom(
        'http://www.url.com', 'XyzzY'
    );

    unless ($url) {
        say $bitly->{error};
    }
    else {
        say $url;
    }

That's it.

