#!/usr/bin/perl
use strict;
use warnings;
use Apache2;
use Apache::Test;
use Apache::TestUtil qw(t_cmp t_write_perl_script);
use Apache::TestRequest qw(GET);
use CPAN::Search::Lite::Util qw(%chaps);
use FindBin;
use lib "$FindBin::Bin/../lib";
use TestCSL qw($expected);

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config) || '';

plan tests => 43;

my $result;

for my $id (keys %$expected) {
  my $result = GET "/author/$id";
  ok t_cmp($result->code, 200, "fetching /author/$id");
  $result = GET "/search?mode=author&query=$id";
  ok t_cmp($result->code, 200, "fetching /search?mode=author&query=$id");

  my $dist = $expected->{$id}->{dist};
  $result = GET "/dist/$dist";
  ok t_cmp($result->code, 200, "fetching /dist/$dist");
  $result = GET "/~$id";
  ok t_cmp($result->code, 200, "fetching /~$id");
  $result = GET "/~$id/$dist";
  ok t_cmp($result->code, 200, "fetching /~$id/$dist");
  $result = GET "/search?mode=dist&query=$dist";
  ok t_cmp($result->code, 200, "fetching /search?mode=dist&query=$dist");

  my $module = $expected->{$id}->{mod};
  $result = GET "/module/$module";
  ok t_cmp($result->code, 200, "fetching /module/$module");
  $result = GET "/search?mode=module&query=$module";
  ok t_cmp($result->code, 200, "fetching /search?mode=module&query=$module");

  my $chapter = $chaps{$expected->{$id}->{chapter}};
  $result = GET "/chapter/$chapter";
  ok t_cmp($result->code, 200, "fetching /chapter/$chapter");
  my $subchapter = $expected->{$id}->{subchapter};
  $result = GET "/chapter/$chapter/$subchapter";
  ok t_cmp($result->code, 200, "fetching /chapter/$chapter/$subchapter");
}

for (qw(dist module author recent mirror chapter search)) {
  $result = GET "/$_";
  ok t_cmp($result->code, 200, "fetching /$_");
}

my $no_such = 'XXX';
for (qw(dist module author)) {
  $result = GET "/$_/$no_such";
  ok t_cmp($result->code, 200, "fetching /$_/$no_such");
  $result = GET "/search?mode=$_&query=$no_such";
  ok t_cmp($result->code, 200, "fetching /search?mode=$_&query=$no_such");
}
