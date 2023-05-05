requires   "version";
requires   "HTTP::Tiny";
requires   "Text::Wrap";
requires   "JSON::MaybeXS";
requires   "IO::Socket::SSL";

recommends "HTTP::Tiny"                => "0.059";
recommends "IO::Socket::SSL"           => "1.35";

suggests   "version"                   => "0.9929";
suggests   "HTTP::Tiny"                => "0.082";
suggests   "IO::Socket::SSL"           => "2.081";
suggests   "JSON::MaybeXS"             => "1.004005";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker";
    recommends "ExtUtils::MakeMaker"   => "7.22";
    suggests   "ExtUtils::MakeMaker"   => "7.70";
    };

on "test" => sub {
    requires   "Test::More";
    suggests   "Test::More"            => "1.302195";
    };
