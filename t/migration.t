#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Migratus;
use DBI;

$Migratus::MigrationDirectory = 't/mig';

my $dbh = DBI->connect( 'DBI:Mock:', '', '' )
  or die "Couldn't create DBD::Mock! $DBI::errstr\n";
my $m = Migratus->new( dbh => $dbh );

$m->migrate();

my @history = $dbh->{mock_all_history}->@*;

# 3 for each migration, and 1 for create migrations table.
is @history, 7, 'did correct number of queries run?';

is lc( $history[0]->{statement} ),
  lc(
'CREATE TABLE migratus_migrations (id int unique, name varchar(500), up text, down text, file varchar(500));'
  ), 'did correct create migratus_migrations table sql run?';

is lc( $history[2]->statement ),
  lc('create table users ( age int, name text );'),
  'did first migration run with correct sql?';

is lc( $history[5]->statement ), lc('create table other ( name text );'),
  'did second migration run with correct sql?';

$m->migrate('down');

my $orig_len = @history;

@history = $dbh->{mock_all_history}->@*;

shift @history for 1 .. $orig_len;

is lc( $history[1]->statement ), lc('drop table users;'),
  'did first migration go down with correct sql?';

is lc( $history[4]->statement ), lc('drop table other;'),
  'did second migration go down with correct sql?';

done_testing;
