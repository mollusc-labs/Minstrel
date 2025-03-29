# This file is apart of Minstrel, a Free and Open-Source
# DBI migration toolkit for Perl 5 applications.
#
# Copyright (C) 2024  Mollusc Labs Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Minstrel;

use strict;
use warnings;

use Carp ();
use DBI;
use YAML::Tiny;
use Digest::MD5 qw(md5_hex);
use File::Find;
use feature 'say';

our $VERSION            = '0.0.1';
our $TableName          = 'minstrel_migrations';
our $MigrationDirectory = 'mig';

# ABSTRACT: a migration toolkit for DBI

sub new {
    my ( $class, %args ) = @_;

    Carp::croak("Argument error, argument dbh is required by Minstrel->new")
      unless $args{dbh};

    eval {
        no warnings;
        local $args{dbh}->{PrintError} = 0;
        local $args{dbh}->{RaiseError} = 0;
        local $args{dbh}->{PrintWarn}  = 0;
        $args{dbh}->do(
qq[CREATE TABLE $TableName (id int unique, name varchar(500), up text, down text, file varchar(500));]
        );
    } or do { say 'Table already exists ... OK' if exists $args{loud} };

    return bless {
        quiet => exists $args{quiet} && $args{quiet},
        loud  => exists $args{loud}  && $args{loud},
        path  => $args{path} // $MigrationDirectory,
        dbh   => $args{dbh},
    }, $class;
}

sub dbh {
    return shift->{dbh};
}

sub is_quiet {
    return shift->{quiet};
}

sub is_loud {
    return shift->{loud};
}

sub path {
    return shift->{path};
}

sub migrate {
    my ( $self, $direction ) = @_;

    $direction //= 'up';

    my $dbh = $self->dbh;
    my @files;

    find(
        sub {
            push @files, $_ if $_ =~ /.*\.yaml$/xsmi;
        },
        "./" . $self->path
    );

    if ( scalar @files > 1 ) {
        @files = sort {
            my ($av) = ( $a =~ /^([0-9]+)-.*/si );
            my ($bv) = ( $b =~ /^([0-9]+)-.*/si );
            $av <=> $bv;
        } @files;
    }

    for (@files) {
        my ($id) = ( $_ =~ /([0-9]+)/si );

        if (
            my ($record) = $dbh->selectall_array(
                qq[select * from $TableName where id = ?],
                { Slice => {} }, $id
            )
          )
        {
            my $yaml;
            eval { $yaml = YAML::Tiny->read("$MigrationDirectory/$_"); };
            if ($@) {
                Carp::croak(
                    qq[Database state invalidated!!

$_ is not consistent with what has been logged in the migration database!

Expected:
    Up:
        $record->{up}
    Down:
        $record->{down}

Got:
    File could not be read!
]
                );
            }

            my $migration = shift @$yaml;
            if (   $record->{up} ne $migration->{up}
                || $record->{down} ne $migration->{down} )
            {
                Carp::croak(
                    qq[Database state invalidated!!

$_ is not consistent with what has been logged in the migration database!

Expected:
    Up:
        $record->{up}
    Down:
        $record->{down}
Got:
    Up:
        $migration->{up}
    Down:
        $migration->{down}

To reconcile database changes, please revert this record, and create a
new migration using "minstrel make migration", that performs the changes
you intended.]
                );
            }
            else {
                next;
            }
        }

        my $error = $self->_run_migration( $_, $id, $direction );

        if ($error) {
            Carp::croak($error);
        }
    }

    say 'Minstrel [DONE]'
      unless $self->is_quiet;
}

sub _run_migration {
    my ( $self, $migration_file, $id, $direction ) = @_;

    if ( $direction ne 'up' && $direction ne 'down' ) {
        Carp::croak(
            'Invalid direction provided for migration, wanted "up" or "down".');
    }

    my $dbh       = $self->dbh;
    my $yaml      = YAML::Tiny->read("$MigrationDirectory/$migration_file");
    my $migration = shift @$yaml;

    my $sql = $migration->{$direction};
    $sql = $self->_trim($sql);

    say "$_ $direction SQL:\n\n$sql\n"
      if $self->is_loud;

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    say "migration: $_ ... OK"
      unless $self->is_quiet;

    if ( my $err = $sth->err ) {
        return $err;
    }

    $dbh->do(
qq[insert into $TableName (id, name, up, down, file) values (?, ?, ?, ?, ?)],
        undef,
        $id,
        $migration_file,
        $migration->{up},
        $migration->{down},
        "$MigrationDirectory/$migration_file"
    );

    $dbh->commit()
      if !$dbh->{AutoCommit};

    return 0;
}

sub _trim {

    # trim leading, and trailing white space
    return pop =~ s/^\s+|\s+$//gr;
}

1;

=begin
=cut
