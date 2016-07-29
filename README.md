<div>
    <a href="https://travis-ci.org/pjfl/p5-file-dataclass"><img src="https://travis-ci.org/pjfl/p5-file-dataclass.svg?branch=master" alt="Travis CI Badge"></a>
    <a href="https://roxsoft.co.uk/coverage/report/file-dataclass/latest"><img src="https://roxsoft.co.uk/coverage/badge/file-dataclass/latest" alt="Coverage Badge"></a>
    <a href="http://badge.fury.io/pl/File-DataClass"><img src="https://badge.fury.io/pl/File-DataClass.svg" alt="CPAN Badge"></a>
    <a href="http://cpants.cpanauthors.org/dist/File-DataClass"><img src="http://cpants.cpanauthors.org/dist/File-DataClass.png" alt="Kwalitee Badge"></a>
</div>

# Name

File::DataClass - Structured data file IO with caching and searching

# Version

This document describes version v0.70.$Rev: 0 $ of [File::DataClass](https://metacpan.org/pod/File::DataClass)

# Synopsis

    use File::DataClass::Schema;

    $schema = File::DataClass::Schema->new
       ( path    => [ 'path to a file' ],
         result_source_attributes => { source_name => {}, },
         tempdir => [ 'path to a directory' ] );

    $schema->source( 'source_name' )->attributes( [ qw( list of attr names ) ] );
    $rs = $schema->resultset( 'source_name' );
    $result = $rs->find( { name => 'id of field element to find' } );
    $result->$attr_name( $some_new_value );
    $result->update;
    @result = $rs->search( { 'attr name' => 'some value' } );

# Description

Provides methods for manipulating structured data stored in files of
different formats

The documentation for this distribution starts in the class
[File::DataClass::Schema](https://metacpan.org/pod/File::DataClass::Schema)

[File::DataClass::IO](https://metacpan.org/pod/File::DataClass::IO) is a [Moo](https://metacpan.org/pod/Moo) based implementation of [IO::All](https://metacpan.org/pod/IO::All)s API.
It implements the file and directory methods only

# Configuration and Environment

Defines the distributions `VERSION` number using a polyglot interpreted by
both Perl and hooks in the `VCS`

# Subroutines/Methods

None

# Diagnostics

None

# Dependencies

- [version](https://metacpan.org/pod/version)

# Incompatibilities

On `mswin32` and `cygwin` it is assumed that NTFS is being used and
that it does not support `mtime` so caching on those platforms is
disabled

Due to the absence of an `mswin32` environment for testing purposes that
platform is not supported

# Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=File-DataClass. Patches are
welcome

# Acknowledgements

Larry Wall - For the Perl programming language

The class structure and API where taken from [DBIx::Class](https://metacpan.org/pod/DBIx::Class)

The API for the file IO was taken from [IO::All](https://metacpan.org/pod/IO::All)

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2016 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
