package TestCSL;
use strict;
use warnings;
use Safe;
use CPAN::Search::Lite::Lang qw(%langs);

use base qw(Exporter);
our ($expected, @EXPORT_OK, %has_doc);
@EXPORT_OK = qw($expected make_soap download load_cs lang_wanted %has_doc);

$expected = {
             GBARR => {mod => 'Net::FTP',
                       dist => 'libnet',
                       chapter => 5,
                       subchapter => 'Net',
                       fullname => 'Graham Barr'},
             GAAS => {mod => 'LWP',
                      dist => 'libwww-perl',
                      chapter => 15,
                      subchapter => 'LWP',
                      fullname => 'Gisle Aas'},
             GSAR => {mod => 'Alias',
                      dist => 'Alias',
                      chapter => 2,
                      fullname => 'Gurusamy Sarathy',
                      subchapter => 'Alias',
                     },
            };

%has_doc = ('Net::FTP::I' => undef,
            'Net::FTP::E' => undef,
            'Net::FTP::L' => undef,
            'Net::FTP' => 1,
            'Net::Time' => 1,
            'Net::SMTP' => 1,
           );

sub make_soap {
  my ($soap_uri, $soap_proxy) = @_;
  unless (eval { require SOAP::Lite }) {
    print STDERR "SOAP::Lite is unavailable to make remote call\n"; 
    return;
  } 
  
  return SOAP::Lite
    ->uri($soap_uri)
      ->proxy($soap_proxy,
              options => {compress_threshold => 10000})
        ->on_fault(sub { my($soap, $res) = @_; 
                         print STDERR "SOAP Fault: ", 
                           (ref $res ? $res->faultstring 
                                     : $soap->transport->status),
                           "\n";
                         return undef;
                       });
}

sub download {
  my ($cpanid, $file) = @_;
  (my $fullid = $cpanid) =~ s{^(\w)(\w)(.*)}{$1/$1$2/$1$2$3};
  my $download = 'authors/id' . '/' . $fullid . '/' . $file;
  return $download;
}

# routine to verify the CHECKSUMS for a file
# adapted from the MD5 check of CPAN.pm

sub load_cs {
    my $cs = shift;
    my ($cksum, $fh);
    unless (open $fh, $cs) {
        warn "Could not open $cs: $!";
        return;
    }
    local($/);
    my $eval = <$fh>;
    $eval =~ s/\015?\012/\n/g;
    close $fh;
    my $comp = Safe->new();
    $cksum = $comp->reval($eval);
    if ($@) {
        warn $@;
        return;
    }
    return $cksum;
}

sub lang_wanted {
  my $r = shift;
  my $accept = $r->headers_in->{'Accept-Language'};
  return 'en' unless $accept;
  my %wanted;
  foreach my $lang(split /,/, $accept) {
    if ($lang !~ /;/) {
      $lang =~ s{(\w+)-\w+}{$1};
      $wanted{1} = lc $lang;
    }
    else {
      my @q = split /;/, $lang, 2;
      $q[1] =~ s{q=}{};
      $q[1] = trim($q[1]);
      $q[0] =~ s{(\w+)-\w+}{$1};
      $wanted{$q[1]} = lc trim($q[0]);
    }
  }
  for (reverse sort {$a <=> $b} keys %wanted) {
    return $wanted{$_} if $langs{$wanted{$_}};
  }
  return 'en';
}

1;
