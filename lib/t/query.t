#!/usr/bin/perl
use strict;
use warnings;
use Test;
use CPAN::Search::Lite::Query;
use FindBin;
use lib "$FindBin::Bin/../../Apache2/t/lib";
use TestCSL qw($expected);

plan tests => 56;

my ($db, $user, $passwd, $max_results) = ('test', 'test', '', 200);

my $query = CPAN::Search::Lite::Query->new(db => $db,
                                           user => $user,
                                           passwd => $passwd,
                                           max_results => $max_results);
ok(defined $query);
ok(ref($query) eq 'CPAN::Search::Lite::Query');

my ($results, $fields, $dist, $module);

for my $id (keys %$expected) {
    $fields = [qw(cpanid fullname email)];
    $query->query(mode => 'author', name => $id, fields => $fields);
    $results = $query->{results};
    ok(defined $results);
    ok($results->{cpanid}, $id);
    ok($results->{fullname}, $expected->{$id}->{fullname});
    ok(defined $results->{email});

    $dist = $expected->{$id}->{dist};
    $fields = [qw(dist_name dist_abs dist_vers cpanid dist_file size birth)];
    $query->query(mode => 'dist', name => $dist, fields => $fields);
    $results = $query->{results};
    ok(defined $results);
    ok($results->{dist_name}, $dist);
    ok($results->{dist_file}, qr{^$dist});
    ok($results->{cpanid}, $id);
    ok($results->{dist_vers} > 0);
    ok(defined $results->{size});
    ok(defined $results->{birth});

    $module = $expected->{$id}->{mod};
    $fields = [qw(mod_name mod_abs mod_vers dist_name cpanid dist_file)];
    $query->query(mode => 'module', name => $module, fields => $fields);
    $results = $query->{results};
    ok(defined $results);
    ok($results->{mod_name}, $module);
    ok($results->{dist_name}, $dist);
    ok($results->{dist_file}, qr{^$dist});
    ok(defined $results->{mod_vers});
    ok(defined $results->{mod_abs});
}

my $no_such = 'ZZZ';

$fields = [qw(cpanid fullname email)];
$query->query(mode => 'author', name => $no_such, fields => $fields);
$results = $query->{results};
ok(not defined $results);

$fields = [qw(dist_name dist_abs dist_vers cpanid dist_file size birth)];
$query->query(mode => 'dist', name => $no_such, fields => $fields);
$results = $query->{results};
ok(not defined $results);

$fields = [qw(mod_name mod_abs mod_vers dist_name cpanid dist_file)];
$query->query(mode => 'module', name => $no_such, fields => $fields);
$results = $query->{results};
ok(not defined $results);
