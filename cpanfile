requires "Cache::FastMmap" => "1.40";
requires "Class::Null" => "2.110730";
requires "File::Path" => "2.08";
requires "File::ReadBackwards" => "1.05";
requires "Hash::Merge" => "0.200";
requires "JSON::MaybeXS" => "1.002002";
requires "Module::Pluggable" => "5.1";
requires "Module::Runtime" => "0.014";
requires "Moo" => "1.006";
requires "Subclass::Of" => "0.003";
requires "Try::Tiny" => "0.22";
requires "Type::Tiny" => "1.000002";
requires "Unexpected" => "v0.35.0";
requires "namespace::autoclean" => "0.22";
requires "namespace::clean" => "0.25";
requires "perl" => "5.010001";

on 'build' => sub {
  requires "File::pushd" => "1.00";
  requires "Module::Build" => "0.4004";
  requires "Path::Tiny" => "0.013";
  requires "Test::Deep" => "0.108";
  requires "Test::Requires" => "0.06";
  requires "Text::Diff" => "1.37";
  requires "version" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
