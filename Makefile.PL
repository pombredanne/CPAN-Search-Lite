use strict;
use ExtUtils::MakeMaker;
my @exe_files = map {"bin/$_"} qw(csl_index csl_query csl_soap);
my %opts = (
	    NAME => 'CPAN::Search::Lite',
            VERSION_FROM => 'lib/CPAN/Search/Lite.pm',
            EXE_FILES => \@exe_files,
	    dist   => {
			 SUFFIX   => 'gz',
			 COMPRESS => 'gzip -9f',
			},
	   );

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
   $opts{ABSTRACT} = 'Lightweight interface to search CPAN';
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
               'Compress::Zlib' => 0,
               'File::Temp' => 0,
               'HTML::TextToHTML' => 0,
               'Pod::Select' => 0,
               'DBD::mysql' => 0,
               'SOAP::Lite' => 0,
               'CPAN::DistnameInfo' => 0,
               'Sort::Versions' => 0,
               'Lingua::Stem' => 0,
               'AI::Categorizer' => 0,
               'Lingua::StopWords' => 0,
	       );

WriteMakefile( %opts, PREREQ_PM => \%prereqs);

print <<'END';

Please read the INSTALL file for further installation instructions.

END
