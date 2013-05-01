# Name

File::DataClass - Structured data file IO with OO paradigm

# Version

This document describes version v0.18.$Rev: 11 $ of [File::DataClass](https://metacpan.org/module/File::DataClass)

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

Provides CRUD methods for structured data stored in files of different formats

The documentation for this distribution starts in the class
[File::DataClass::Schema](https://metacpan.org/module/File::DataClass::Schema)

# Configuration and Environment

Defines these class attributes. They are set on first use when an instance
of [File::DataClass::Schema](https://metacpan.org/module/File::DataClass::Schema) is created

- __Cache__

    This is a [Cache::Cache](https://metacpan.org/module/Cache::Cache) object which is used to cache the results of
    reading a file. Maybe of type `Cache`

# Subroutines/Methods

None

# Diagnostics

None

# Dependencies

- [namespace::autoclean](https://metacpan.org/module/namespace::autoclean)
- [MooseX::ClassAttribute](https://metacpan.org/module/MooseX::ClassAttribute)

# Incompatibilities

On `MSWin32` and `Cygwin` it is assumed that NTFS is being used and
that it does not support `mtime` so caching on those platforms is
disabled

# Bugs and Limitations

There are no known bugs in this module.  Please report problems to the
address below. Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

The class structure and API where taken from [DBIx::Class](https://metacpan.org/module/DBIx::Class)

The API for the file IO was taken from [IO::All](https://metacpan.org/module/IO::All)

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/module/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
