use strict;
use ExtUtils::MakeMaker;
use Config;
use File::Spec::Functions;

my @exe_files = map {"bin/$_"} qw(csl_index csl_query csl_soap);
my %opts = (
	    NAME => 'CPAN::Search::Lite',
            VERSION_FROM => 'lib/CPAN/Search/Lite.pm',
            PMLIBDIRS => [qw(lib Apache2)],
            EXE_FILES => \@exe_files,
            DIR => [qw(lib Apache2)],
            NO_META => 1,
	    dist   => {
			 SUFFIX   => 'gz',
			 COMPRESS => 'gzip -9f',
			},
           clean => {FILES => 'lib/t/POD lib/t/HTML lib/pod2htm*'},
	   );

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
   $opts{ABSTRACT_FROM} = 'lib/CPAN/Search/Lite.pm';
   $opts{AUTHOR} = 'Randy Kobes <r.kobes@uwinnipeg.ca>';
}

my %prereqs = ('Config::IniFiles' => 0,
	       'File::Spec' => 0,
	       'LWP' => 0,
	       'YAML' => 0,
	       'XML::Parser' => 2,
               'Locale::Country' => 0,
               'Archive::Zip' => 1.09,
               'Archive::Tar' => 1.08,
               'IO::Zlib' => 0,
               'File::Temp' => 0,
               'HTML::TextToHTML' => 0,
               'Pod::Select' => 0,
               'DBD::mysql' => 0,
               'CPAN::DistnameInfo' => 0,
               'Sort::Versions' => 0,
               'Lingua::Stem' => 0,
               'AI::Categorizer' => 0,
               'Lingua::StopWords' => 0,
               'Perl::Tidy' => 0,
	       );

eval {require Apache2;};
eval {require Apache::Test;};
if ($@) {
    print <<'END';

Apache::Test is required to run the part of the test suite.
I can add this to the list of prerequisites, if you like.

END
    my $ans = prompt("Add Apache::Test to prerequisites?", 'yes');
    $prereqs{'Apache::Test'} = 0 if ($ans =~ /^y/i);
}

eval {require SOAP::Lite;};
if ($@) {
    print <<'END';

SOAP::Lite is required to run the part of the test suite,
and also to provide SOAP-based web services. I can add this
to the list of prerequisites, if you like.

END
    my $ans = prompt("Add SOAP::Lite to prerequisites?", 'yes');
    $prereqs{'SOAP::Lite'} = 0 if ($ans =~ /^y/i);
}

eval {require mod_perl;};
if ($@) {
    print <<'END';

mod_perl is required to run the part of the test suite,
and also to use the included Apache handlers. You will
need mod_perl 1.99_xx (which is the development version of
mod_perl 2, used for Apache 2.0). See
   http://perl.apache.org/
for details on mod_perl, including links on how to install it.

END

}
else {
    my $mpv = $mod_perl::VERSION;
    if ($mpv < 1.99) {
        print <<'END';

Part of the test suite, as well as the included Apache handlers,
require a later version of mod_perl 1.99 (which is the development
version of mod_perl 2.0, based on Apache 2.0). This is not
compatible with mod_perl 1.2x (based on Apache 1.3), but you
can in principle have mod_perl 1.2x and mod_perl 1.99_xx
coexisting. See
   http://perl.apache.org/
for details on mod_perl, including links on how to install it.

END
    }
}

eval {require Apache::Upload;};
if ($@) {
    print <<'END';

Apache::Request and Apache::Cookie from the libapreq2
distribution (based on Apache 2.0) is required to run part
of the test suite and to use the included Apache handlers
(this is not compatible with Apache::Request and
Apache::Cookie from the libapreq distribution, which is
based on Apache 1.3). See
   http://httpd.apache.org/apreq/
for details on the libapreq2 library, including links
on how to install it.

END
}

WriteMakefile( %opts, PREREQ_PM => \%prereqs);
my $make = $Config{make};
my $config = catfile 'build', 'gen_conf.pl';

print <<"END";

***************************************************************
You can now execute
   $make
   $make test
   $make install
After this, you can optionally run
   $^X $config
to set up some basic configuration details for your system.
Please read the INSTALL file for further installation instructions.
***************************************************************

END

eval {require CPAN::Search::Lite};
unless ($@) {
    my $version = $CPAN::Search::Lite::VERSION;
    if ($version < 0.64) {
  print <<"END";

***************************************************************
You seem to be running an older version ($version) of CPAN::Search::Lite.
There are some changes to the database schema that occur with
this version - addition of primary keys to the ppms, chaps, and
reqs tables, increasing the size of mod_name in the modules
table, adding a src field to the mods table to indicate the
presence of the module's source, and addition of a md5 field in
the dists table to specify the CPAN checksum. A script
fix_db.pl is included in the build subdirectory which you can
run to alter an exisiting table to include these changes.
***************************************************************

END
}
}
