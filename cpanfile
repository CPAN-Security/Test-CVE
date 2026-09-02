requires   "HTTP::Tiny";
requires   "IO::Socket::SSL"          => "1.968";
requires   "JSON::MaybeXS";
requires   "Module::CoreList";
requires   "Test::Builder::Module";
requires   "Text::Wrap";
requires   "YAML::PP";
requires   "version";

recommends "HTTP::Tiny"               => "0.093";

suggests   "HTTP::Tiny"               => "0.096";
suggests   "IO::Socket::SSL"          => "2.099";
suggests   "JSON::MaybeXS"            => "1.004008";
suggests   "Module::CoreList"         => "5.20260820";
suggests   "Perl::Tidy"               => "20260826";
suggests   "YAML::PP"                 => "0.41.0";
suggests   "version"                  => "0.9934";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker";

    recommends "ExtUtils::MakeMaker"      => "7.22";

    suggests   "ExtUtils::MakeMaker"      => "7.78";
    };

on "test" => sub {
    requires   "Test::More";

    suggests   "Test::More"               => "1.302224";
    };
