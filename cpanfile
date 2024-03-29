# This file is generated by Dist::Zilla::Plugin::CPANFile v6.030
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "Cache::FastMmap" => "1.40";
requires "Class::Null" => "2.110730";
requires "File::Path" => "2.09";
requires "File::ReadBackwards" => "1.05";
requires "Hash::Merge" => "0.200";
requires "JSON::MaybeXS" => "1.003";
requires "Module::Pluggable" => "5.1";
requires "Module::Runtime" => "0.014";
requires "Moo" => "2.001001";
requires "Ref::Util" => "0.203";
requires "Sub::Install" => "0.928";
requires "Subclass::Of" => "0.003";
requires "Try::Tiny" => "0.22";
requires "Type::Tiny" => "1.000002";
requires "Unexpected" => "v1.0.3";
requires "boolean" => "0.45";
requires "namespace::autoclean" => "0.26";
requires "namespace::clean" => "0.25";
requires "perl" => "5.010001";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};

on 'test' => sub {
  requires "Capture::Tiny" => "0.30";
  requires "File::Spec" => "0";
  requires "File::pushd" => "1.00";
  requires "Module::Build" => "0.4004";
  requires "Module::Metadata" => "0";
  requires "Path::Tiny" => "0.013";
  requires "Sys::Hostname" => "0";
  requires "Test::Deep" => "0.117";
  requires "Test::Requires" => "0.06";
  requires "Text::Diff" => "1.37";
  requires "version" => "0.88";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
