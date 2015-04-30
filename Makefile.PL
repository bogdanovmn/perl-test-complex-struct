

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Test::ComplexStruct',
    VERSION_FROM => 'lib/Test/ComplexStruct.pm', # finds \$VERSION
    AUTHOR       => 'Mikhail N Bogdanov (bogdanovmn@gmail.com)',
    ABSTRACT     => 'Simple tool for testing complex (and simple too) structures',
    PREREQ_PM    => {
                     'Test::More' => 0,
                    },
);
