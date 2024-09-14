use strict;
use warnings;

use Dancer2;
use Migratus;

my $dbh      = DBI->connect( 'dbi:SQLite:dbname=file.db', '', '' );
my $migratus = Migratus->new( dbh => $dbh );
$migratus->migrate();

get '/' => sub {
    my @users =
      $dbh->selectall_array(q[select * from users], { Slice => {} } );
    join '<br>', map { $_->{name} } @users;
};

get '/add-user/:name' => sub {
    $dbh->do( 'insert into users (name, age) values (?, ?)',
        undef, route_parameters->get('name'), 23 );
    "Inserted " . route_parameters->get('name');
};

dance;
