#!perl
use strict;
use warnings FATAL => 'all';
use Apache::TestRunPerl();
eval {require Apache2;};
use blib;
Apache::TestRunPerl->new->run(@ARGV);
