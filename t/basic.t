use Test::More;

use strict;
use warnings;

BEGIN {
    use_ok 'Migratus';
}

use Migratus;

eval { my $instance = Migratus->new() } or do { ok 1, 'dies without dbh?' };

done_testing;
