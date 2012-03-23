#!/usr/bin/perl
#

use warnings;
use strict;

use bitly;

my $bitly = bitly->new('user', 'pass');
my $url = $bitly->shorten_custom(
    'http://www.site.com', 'xyzzY'
);

unless ($url) {
    print $bitly->{error}, "\n";
}
else {
    print $url, "\n";
}

my $url2 = $bitly->shorten('http://www.google.com/');
unless ($url2) {
    print $bitly->{error}, "\n";
}
else {
    print $url2, "\n";
}

