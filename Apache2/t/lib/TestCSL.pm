package TestCSL;
use strict;
use warnings;

use base qw(Exporter);
our ($expected, @EXPORT_OK);
@EXPORT_OK = qw($expected make_soap download);

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
  my $download = $fullid . '/' . $file;
  return $download;
}

1;
