#!/usr/bin/perl
use strict;
use warnings;
use Test;
use Cwd;
use File::Spec::Functions;
use File::Path;
use CPAN::DistnameInfo;
use FindBin;
use lib "$FindBin::Bin/../../Apache2/t/lib";
use TestCSL qw($expected download %has_doc);
use CPAN::Search::Lite::Info;

plan tests => 100;

my $cwd = getcwd;
my $CPAN = catdir $cwd, 't', 'cpan';
ok (-d $CPAN);
my $info = CPAN::Search::Lite::Info->new(CPAN => $CPAN);
ok(defined $info);
$info->fetch_info();
ok(defined $info->{dists});
ok(defined $info->{mods});
ok(defined $info->{auths});
foreach my $id (keys %$expected) {
  my $mod = $expected->{$id}->{mod};
  my $dist = $expected->{$id}->{dist};
  my $chapter = $expected->{$id}->{chapter};
  my $fullname = $expected->{$id}->{fullname};
  my $subchapter = $expected->{$id}->{subchapter};

  ok($info->{auths}->{$id}->{fullname}, qq{$fullname});
  ok(defined $info->{auths}->{$id}->{email});

  ok($info->{mods}->{$mod}->{dist}, $dist);
  ok($info->{mods}->{$mod}->{version} > 0);
  ok($info->{mods}->{$mod}->{chapterid}, $chapter);
  ok(defined $info->{mods}->{$mod}->{dslip});
  ok(defined $info->{mods}->{$mod}->{description});

  ok($info->{dists}->{$dist}->{cpanid}, $id);
  my $filename = $info->{dists}->{$dist}->{filename};
  ok($filename, qr{^$dist});
  my $download = download($id, $filename);
  my $d = CPAN::DistnameInfo->new($download);
  ok($info->{dists}->{$dist}->{size} > 0);
  ok($info->{dists}->{$dist}->{version}, $d->version);
  ok(defined $info->{dists}->{$dist}->{date});
  ok(defined $info->{dists}->{$dist}->{modules}->{$mod});
  ok(exists $info->{dists}->{$dist}->{chapterid}->{$chapter});
  ok(exists $info->{dists}->{$dist}->{chapterid}->{$chapter}->{$subchapter});
}

ok(not defined $info->{auths}->{ZZZ});
ok(not defined $info->{mods}->{ZZZ});
ok(not defined $info->{dists}->{ZZZ});

my @tables = qw(dists mods auths);
my $index;
my $package = 'CPAN::Search::Lite::Index';
foreach my $table(@tables) {
  my $class = $package . '::' . $table;
  my $this = {info => $info->{$table}};
  $index->{$table} = bless $this, $class;
}

my $pod_root = catdir $cwd, 't', 'POD';
my $html_root = catdir $cwd, 't', 'HTML';
for my $dir ( ($pod_root, $html_root) ) {
    if (-d $dir) {
        rmtree ($dir, 1, 1) or die "Cannot rmtree $dir: $!";
    }
    mkpath($dir, 1, 0777) or die "Cannot mkpath $dir: $!";
}
use CPAN::Search::Lite::Extract;
my $extract = CPAN::Search::Lite::Extract->new(CPAN => $CPAN,
                                               setup => 1,
                                               index => $index,
                                               pod_root => $pod_root,
                                               html_root => $html_root,
                                               split_pod => 1,
                                              );
ok(defined $extract);
ok(ref($extract) eq 'CPAN::Search::Lite::Extract');
$extract->extract();
foreach my $id (keys %$expected) {
    my $dist = $expected->{$id}->{dist};
    my $d = catdir $pod_root, $dist;
    ok(-d $d, 1);
    for my $file (qw(Changes README)) {
        my $f = catfile $d, $file;
        ok(-f $f && -s _ > 0, 1);
    }
    my $mod = $expected->{$id}->{mod};
    my $f = (catfile($d, split /::/, $mod)) . '.pm';
    ok(-f $f && -s _ > 0, 1);
    $d = catdir $html_root, $dist;
    ok(-d $d, 1);
    for my $file (qw(Changes README index)) {
        my $f = catfile $d, "$file.html";
        ok(-f $f && -s _ > 0, 1);
    }
    $f = (catfile($d, split /::/, $mod)) . '.html';
    ok(-f $f && -s _ > 0, 1);
}

my $dist = 'libnet';

foreach my $mod (keys %has_doc) {
    my $d = catdir $pod_root, $dist;
    my $f = (catfile($d, split /::/, $mod)) . '.pm';
    ok(-f $f && -s _ > 0, 1);
    $d = catdir $html_root, $dist;
    if ($has_doc{$mod}) {
        $f = (catfile($d, split /::/, $mod)) . '.html';
        ok(-f $f && -s _ > 0, 1);
    }
    $f = (catfile($d, split /::/, $mod)) . '.pm.html';
    ok(-f $f && -s _ > 0, 1);
}

use CPAN::Search::Lite::Populate;
my ($db, $user, $passwd) = ('test', 'test', '');
my $pop = CPAN::Search::Lite::Populate->new(db => $db, user => $user,
                                            passwd => $passwd, setup => 1,
                                            no_ppm => 1, no_mirror => 1,
                                            index => $index);
ok(defined $pop);
ok(ref($pop) eq 'CPAN::Search::Lite::Populate');
$pop->populate();
ok(1);

