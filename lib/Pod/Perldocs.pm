package Pod::Perldocs;
use strict;
use warnings;
require Pod::Perldoc;
use base qw(Pod::Perldoc);
our ($VERSION);
$VERSION = $Pod::Perldoc::VERSION;

################################################################
# Change the following to reflect your setup
# this is for cgi-bin/docserver.cgi
#my $soap_uri = 'http://localhost/Apache/DocServer';
#my $soap_proxy = 'http://localhost/cgi-bin/docserver.cgi';
#
# this is for the mod_perl 2 Apache::DocServer
my $soap_uri = 'http://localhost/Apache/DocServer';
my $soap_proxy = 'http://localhost/docserver';
###############################################################

sub grand_search_init {
    my($self, $pages, @found) = @_;
    @found = $self->SUPER::grand_search_init($pages, @found);
    return @found if @found;
    my $soap = make_soap() or return @found; # no SOAP::Lite available
    print STDERR "Searching on remote soap server ...\n";
    my $result = $soap->get_doc($pages->[0]);
    defined $result && defined $result->result or do {
        print STDERR "No matches found there either.\n";
        return @found;
    };
    my $lines = $result->result();
    unless ($lines and ref($lines) eq 'ARRAY') {
        print STDERR "Documentation not found there either.\n";
        return @found;
    }
    my ($fh, $filename) = $self->new_tempfile();
    print $fh @$lines;
    push @found, $filename;
    return @found;
}

sub make_soap {
  unless (eval { require SOAP::Lite }) {
    print STDERR "SOAP::Lite is unavailable to make remote call\n";
    return undef;
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

1;

=head1 NAME

Pod::Perldocs - soap-enhanced perldoc

=head1 DESCRIPTION

This is a drop-in replacement for C<perldoc> based on
C<Pod::Perldoc>. Usage is the same, except in the case
when documentation for a module cannot be found on the
local machine, in which case a query will be made to
a remote pod repository and, if the documentation is
found there, the results will be displayed as usual.

=head1 NOTE

Make sure to check the values of C<$soap_uri> and
C<$soap_proxy> at the top of this script.

=head1 SEE ALSO

L<Pod::Perldoc>.

=cut
