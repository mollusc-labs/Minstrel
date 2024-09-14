package Migratus;

use strict;
use warnings;

use Carp ();
use DBI;
use YAML::Tiny;
use Digest::MD5 qw(md5_hex);
use File::Find;

our $VERSION            = '0.0.1';
our $TableName          = 'migratus_migrations';
our $MigrationDirectory = 'mig';

sub new {
    my ( $class, %args ) = @_;

    Carp::croak("Argument error, argument dbh is required by Migratus->new")
      unless $args{dbh};

    eval {
        no warnings;
        local $args{dbh}->{PrintError} = 0;
        local $args{dbh}->{RaiseError} = 0;
        local $args{dbh}->{PrintWarn}  = 0;
        $args{dbh}->do(
qq[CREATE TABLE $TableName (id int unique, name varchar(500), up text, down text, file varchar(500));]
        );
    } or do { CORE::say 'Table already exists ... ' if exists $args{loud} };

    return bless {
        quiet => exists $args{quiet},
        loud  => exists $args{loud},
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

sub migrate {
    my ( $self, $direction ) = @_;

    $direction //= 'up';

    my $dbh = $self->dbh;
    my @files;

    find(
        sub {
            push @files, $_ if $_ =~ /.*\.yaml$/xsmi;
        },
        "./$MigrationDirectory"
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

            my $yaml      = YAML::Tiny->read("$MigrationDirectory/$_");
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
new migration using "migratus make migration", that performs the changes
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

    CORE::say 'Migratus [DONE]'
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

    CORE::say "$_ $direction SQL : $sql"
      if $self->is_loud;

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    CORE::say "migration: $_ ... OK"
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

    return 0;
}

1;
