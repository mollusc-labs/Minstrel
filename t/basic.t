use Test::More;

use strict;
use warnings;

BEGIN {
    use_ok 'Minstrel';
}

use Minstrel;

eval { my $instance = Minstrel->new() } or do { ok 1, 'dies without dbh?' };

done_testing;
