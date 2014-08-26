[![Build Status](https://travis-ci.org/pjfl/p5-file-dataclass.svg?branch=master)](https://travis-ci.org/pjfl/p5-file-dataclass)
[![CPAN version](https://badge.fury.io/pl/File-DataClass.svg)](http://badge.fury.io/pl/File-DataClass)

# Name

File::DataClass - Structured data file IO with OO paradigm

# Version

This document describes version v0.45.$Rev: 3 $ of [File::DataClass](https://metacpan.org/pod/File::DataClass)

# Synopsis

    use File::DataClass::Schema;

    $schema = File::DataClass::Schema->new
       ( path    => [ qw(path to a file) ],
         result_source_attributes => { source_name => {}, },
         tempdir => [ qw(path to a directory) ] );

    $schema->source( q(source_name) )->attributes( [ qw(list of attr names) ] );
    $rs = $schema->resultset( q(source_name) );
    $result = $rs->find( { name => q(id of field element to find) } );
    $result->$attr_name( $some_new_value );
    $result->update;
    @result = $rs->search( { 'attr name' => q(some value) } );

# Description

Provides methods for manipulating structured data stored in files of
different formats

The documentation for this distribution starts in the class
[File::DataClass::Schema](https://metacpan.org/pod/File::DataClass::Schema)

[File::DataClass::IO](https://metacpan.org/pod/File::DataClass::IO) is a [Moo](https://metacpan.org/pod/Moo) based implementation of [IO::All](https://metacpan.org/pod/IO::All)s API.
It implements the file and directory methods only

# Configuration and Environment

Defines no attributes

# Subroutines/Methods

## F\_DC\_Cache

    $hash_ref_of_CHI_objects = File::DataClass->F_DC_Cache;

A class method which returns a hash ref of [CHI](https://metacpan.org/pod/CHI) objects which are
used to cache the results of reading files

# Diagnostics

None

# Dependencies

- [Moo](https://metacpan.org/pod/Moo)

# Incompatibilities

On `MSWin32` and `Cygwin` it is assumed that NTFS is being used and
that it does not support `mtime` so caching on those platforms is
disabled

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
