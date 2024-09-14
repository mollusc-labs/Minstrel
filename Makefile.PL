use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Migratus',
    VERSION_FROM => 'lib/Migratus.pm',
    ABSTRACT     => 'A straight forward, database agnostic migration tool-kit.',
    AUTHOR       => 'Mollusc Labs Inc.',
    LICENSE      => 'mit',
    META_MERGE   => {
        dynamic_config => 0,
        'meta-spec'    => { version   => 2 },
        no_index       => { directory => [ 'examples', 't' ] },
        prereqs        => { runtime   => { requires => { perl => '5.024' } } },
        resources      => {
            bugtracker =>
              { web => 'https://github.com/mollusc-labs/Migratus/issues' },
            license    => [qq{http://www.opensource.org/licenses/mit}],
            repository => {
                type => 'git',
                url  => 'https://github.com/mollusc-labs/Migratus'
            }
        },
    },
    PREREQ_PM => {
        'YAML::Tiny'   => '0',
        DBI            => '0',
        'IO::Prompter' => '0'
    },
    EXE_FILES => ['bin/migratus'],
    test      => { TESTS => 't/*.t' }
);
