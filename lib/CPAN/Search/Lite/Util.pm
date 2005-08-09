package CPAN::Search::Lite::Util;
use strict;
use warnings;
use Sort::Versions;
our $VERSION = 0.71;

use base qw(Exporter);
our (@EXPORT_OK, %chaps, %chaps_rev, $repositories, %modes,
     $table_id, $query_info, $mode_info, $full_id, $tt2_pages);
@EXPORT_OK = qw(%chaps %chaps_rev $repositories $tt2_pages %modes
                vcmp $table_id $query_info $mode_info $full_id);

make_ids();

$mode_info = {
              module => {id => 'mod_id',
                         table => 'mods',
                         name => 'mod_name',
                         text => 'mod_abs',
                        },
              dist => {id => 'dist_id',
                       table => 'dists',
                       name => 'dist_name',
                       text => 'dist_abs',
                      },
              author => {id => 'auth_id',
                         table => 'auths',
                         name => 'cpanid',
                         text => 'fullname',
                        },
              chapter => {id => 'chapterid',
                          table => 'chaps',
                          name => 'subchapter',
                          text => 'subchapter',
                         },
             };

$tt2_pages = {module => {search => 'mod_search', 
                         info => 'mod_info', letter => 'mod_letter'},
              dist => {search => 'dist_search', recent => 'recent',
                       info => 'dist_info', letter => 'dist_letter'},
              author => {search => 'auth_search', 
                         info => 'auth_info', letter => 'auth_letter'},
              chapter => {search => 'chap_search', info => 'chap_info',
                          query => 'chap_query'},
             };

%modes = map {$_ => 1} keys %$mode_info;

$query_info = { module => {mode => 'module', type => 'name'},
                mod_id => {mode => 'module', type => 'id'},
                dist => {mode => 'dist', type => 'name'},
                dist_id => {mode => 'dist', type => 'id'},
                cpanid => {mode => 'author', type => 'name'},
                author => {mode => 'author', type => 'name'},
                auth_id => {mode => 'author', type => 'id'},
                recent => {mode => 'dist', type => 'recent'},
            };

%chaps = (
          2 => 'Perl_Core_Modules',
          3 => 'Development_Support',
          4 => 'Operating_System_Interfaces',
          5 => 'Networking_Devices_IPC',
          6 => 'Data_Type_Utilities',
          7 => 'Database_Interfaces',
          8 => 'User_Interfaces',
          9 => 'Language_Interfaces',
          10 => 'File_Names_Systems_Locking',
          11 => 'String_Lang_Text_Proc',
          12 => 'Opt_Arg_Param_Proc',
          13 => 'Internationalization_Locale',
          14 => 'Security_and_Encryption',
          15 => 'World_Wide_Web_HTML_HTTP_CGI',
          16 => 'Server_and_Daemon_Utilities',
          17 => 'Archiving_and_Compression',
          18 => 'Images_Pixmaps_Bitmaps',
          19 => 'Mail_and_Usenet_News',
          20 => 'Control_Flow_Utilities',
          21 => 'File_Handle_Input_Output',
          22 => 'Microsoft_Windows_Modules',
          23 => 'Miscellaneous_Modules',
          24 => 'Commercial_Software_Interfaces',
          99 => 'Not_In_Modulelist',
          99 => 'Not_Yet_In_Modulelist',
         );

%chaps_rev = reverse %chaps;


$repositories = {
                 1 => {
                       alias => 'crazy56',
                       LOCATION => 
                       'http://crazyinsomniac.perlmonk.org/perl/ppm',
                       SUMMARYFILE  => 'summary.ppm',
                       browse => 'http://crazyinsomniac.perlmonk.org/perl/ppm',
                       desc => 'crazyinsomniac Perl 5.6 repository',
                       build => '6xx',
                       PerlV         => 5.6,
                      },
                 2 => {
                       alias => 'crazy58',
                       LOCATION  => 
                       'http://crazyinsomniac.perlmonk.org/perl/ppm/5.8',
                       SUMMARYFILE  => 'summary.ppm',
                       browse => 'http://crazyinsomniac.perlmonk.org/perl/ppm/5.8',
                       desc => 'crazyinsomniac Perl 5.8 repository',
                       build => '8xx',
                       PerlV         => 5.8,
                      },
                 3 => {
                       alias => 'uwinnipeg56',
                       LOCATION  => 
                       'http://theoryx5.uwinnipeg.ca/cgi-bin/ppmserver?urn:/PPMServer',
                       SUMMARYFILE  => 'fetch_summary',
                       browse => 'http://theoryx5.uwinnipeg.ca/ppmpackages',
                       desc => 'uwinnipeg Perl 5.6 repository',
                       build => '6xx',
                       PerlV         => 5.6,
                      },
                 4 => {
                       alias => 'uwinnipeg58',
                       LOCATION  => 
                       'http://theoryx5.uwinnipeg.ca/cgi-bin/ppmserver?urn:/PPMServer58',
                       SUMMARYFILE  => 'fetch_summary',
                       browse => 'http://theoryx5.uwinnipeg.ca/ppms',
                       desc => 'uwinnipeg Perl 5.8 repository',
                       build => '8xx',
                       PerlV         => 5.8,
                      },
                 5 => {
                       alias => 'AS58',
                       LOCATION  => 
                       'http://ppm.ActiveState.com/cgibin/PPM/ppmserver-5.8-windows.pl?urn:/PPMServer',
                       SUMMARYFILE  => 'fetch_summary',
                       PerlV         => 5.8,
                       browse => 'http://ppm.activestate.com/BuildStatus/5.8-A.html',
                       desc => 'ActiveState default Perl 5.8 repository',
                       build => '8xx',
                      },
                 6 => {
                       alias => 'AS56',
                       LOCATION  => 
                       'http://ppm.activestate.com/cgibin/PPM/ppmserver.pl?urn:/PPMServer',
                       SUMMARYFILE  => 'fetch_summary',
                       browse => 'http://ppm.activestate.com/BuildStatus/5.6-A.html',
                       desc => 'ActiveState default Perl 5.6 repository',
                       build => '6xx',
                       PerlV         => 5.6,
                      },
                 7 => {
                       alias => 'bribes56',
                       LOCATION  => 
                       'http://www.bribes.org/cgi-bin',
                       SUMMARYFILE  => 'summary.cgi',
                       browse => 'http://www.bribes.org/perl/ppm',
                       desc => 'www.bribes.org Perl 5.6 repository',
                       build => '6xx',
                       PerlV         => 5.6,
                      },
                 8 => {
                       alias => 'bribes58',
                       LOCATION  => 
                       'http://www.bribes.org/cgi-bin',
                       SUMMARYFILE  => 'summary.cgi',
                       browse => 'http://www.bribes.org/perl/ppm',
                       desc => 'www.bribes.org Perl 5.8 repository',
                       build => '8xx',
                       PerlV         => 5.8,
                      },
                };

sub make_ids {
    my @tables = qw(mods dists auths reps);
    foreach my $table (@tables) {
        (my $id = $table) =~ s!(\w+)s$!$1_id!;
        $table_id->{$table} = $id;
        $full_id->{$id} = $table . '.' . $id;
    }
#    $full_id->{chapterid} = 'chaps.chapterid';
}

my $num_re = qr{^0*\.\d+$};
sub vcmp {
    my ($v1, $v2) = @_;
    return unless (defined $v1 and defined $v2);
    if ($v1 =~ /$num_re/ and $v2 =~ /$num_re/) {
        return $v1 <=> $v2;
    }
    return Sort::Versions::versioncmp($v1, $v2);
}

1;

__END__

=head1 NAME

CPAN::Search::Lite::Util - export some common data structures used by CPAN::Search::Lite::*

=head1 DESCRIPTION

This module exports some common data structures used by other
I<CPAN::Search::Lite::*> modules. At present these are

=over 3

=item * C<%chaps>

This is hash whose keys are the CPAN chapter ids with associated
values being the corresponding chapter descriptions.

=item * C<%chaps_rev>

This is the reverse hash of C<%chaps>.

=item * C<$repositories>

This is a hash reference whose keys are repository ids.
The associated values are hash references whose keys are

=over 3

=item C<alias> - an alias for the repository.

=item C<LOCATION> - the url of the repository.

=item C<SUMMARYFILE> - a file on the repository to fetch when requesting
a repository summary.

=item C<browse> - a url by which one can browse the contents of
a repository.

=item C<desc> - a repostitory description

=item C<build> - the ActivePerl build number appropriate for the
repository (eg, I<6xx>, for Perl 5.6, andI<8xx>, for 5.8).

=item C<PerlV> - the Perl version that the repository supports.

=back

=item * C<$table_id>

This is a hash reference whose keys are the tables used
and whose values are the associated primary keys.

=item * C<$full_id>

This is a hash reference whose keys are the primary keys
of the tables and whose values are the associated fully qualified
primary keys (ie, with the table name prepended).

=item * C<$mode_info>

This is a hash reference whose keys are the allowed
modes of I<CPAN::Search::Lite::Query> and whose associated values
are hash references with keys C<id>, C<name>, and C<text> describing
what columns to use for that key.

=item * C<$query_info>

This is a hash reference whose purpose is to provide
shortcuts to making queries using I<CPAN::Search::Lite::Query>. The
keys of this reference is the shortcut name, and the associated
value is a hash reference specifying the required I<mode> and
I<type> keys.

=item * C<$tt2_pages>

This is a hash reference whose keys are the modes
used in I<CPAN::Search::Lite::Query> and whose values are hash
references (with keys I<search>, I<info>, and I<letter>) specifying
what Template-Toolkit page to use for the specific result.

=item * C<vcmp>

This routine, used as

  if (vcmp($v1, $v2) > 0) {
    print "$v1 is higher than $v2\n";
  }

is used to compare two versions, and returns 1/0/-1 if
the first argument is considered higher/equal/lower than
the second. It uses C<Sort::Versions>.

=back

=cut
