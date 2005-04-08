package Apache::CPAN::SOAP;
use strict;
use warnings;
use CPAN::Search::Lite::Query;
use Apache2;
use mod_perl 1.99_11;     # sanity check for a recent version
use Apache::Const -compile => qw(TAKE1 RSRC_CONF ACCESS_CONF);
use Apache::Module ();
use Apache::RequestRec ();
our ($VERSION);
$VERSION = 0.64;

my @directives = (
                  {name      => 'CSL_soap_db',
                   errmsg    => 'database name',
                   args_how  => Apache::TAKE1,
                   req_override => Apache::RSRC_CONF | Apache::ACCESS_CONF,
                  },
                  {name      => 'CSL_soap_user',
                   errmsg    => 'user to log in as',
                   args_how  => Apache::TAKE1,
                   req_override => Apache::RSRC_CONF | Apache::ACCESS_CONF,
                  },
                  {name      => 'CSL_soap_passwd',
                   errmsg    => 'password for user',
                   args_how  => Apache::TAKE1,
                   req_override => Apache::RSRC_CONF | Apache::ACCESS_CONF,
                  },
                  {name      => 'CSL_soap_max_results',
                   errmsg    => 'maximum number of results',
                   args_how  => Apache::TAKE1,
                   req_override => Apache::RSRC_CONF | Apache::ACCESS_CONF,
                  },
                 );

Apache::Module::add(__PACKAGE__, \@directives);

my ($r, $cfg, $max_results, $query);

sub query  {
  my ($self, %args) = @_;
  return unless ($args{mode} and $args{name});
  $r = Apache->request;

  $cfg = Apache::Module::get_config(__PACKAGE__,
                                    $r->server,
                                    $r->per_dir_config) || { };

  $max_results ||= $cfg->{max_results} || 200;
  my $passwd = $cfg->{passwd} || '';
  $query ||= CPAN::Search::Lite::Query->new(db => $cfg->{db},
                                            user => $cfg->{user},
                                            passwd => $passwd,
                                            max_results => $max_results);
  
  $query->query(mode => $args{mode}, name => $args{name},
                fields => $args{fields} );
  my $results = $query->{results};
  if (my $error = $query->{error}) {
    print STDERR $error;
    return;
  }
  return $results;
}

sub CSL_soap_db {
  my ($cfg, $parms, $db) = @_;
  $cfg->{ db } = $db;
}

sub CSL_soap_user {
  my ($cfg, $parms, $user) = @_;
  $user = '' unless $user =~ /\w/;
  $cfg->{ user } = $user;
}

sub CSL_soap_passwd {
  my ($cfg, $parms, $passwd) = @_;
  $cfg->{ passwd } = $passwd;
}

sub CSL_soap_max_results {
  my ($cfg, $parms, $max_results) = @_;
  $cfg->{ max_results } = $max_results;
}

1;

__END__

=head1 NAME

Apache::CPAN::SOAP - soap interface to C<CPAN::Search::Lite::Query>

=head1 DESCRIPTION

This module provides some soap-based services to
C<CPAN::Search::Lite::Query> in a mod_perl 2 environment. 
The necessary Apache2 directives are

 PerlLoadModule Apache::CPAN::SOAP

 CSL_soap_db database_name
 CSL_soap_user user_name
 CSL_soap_passwd password_for_above_user

 <Location /soap>
   SetHandler perl-script
   PerlResponseHandler Apache2::SOAP
   PerlSetVar dispatch_to "D:/Perl/site/lib/Apache2, Apache::CPAN::SOAP"
 </Location>

where the C<Apache2::SOAP> module, included in this distribution,
is a mod_perl 2 aware version of C<Apache::SOAP> of the
C<SOAP::Lite> distribution. See the C<CSL_soap> script in
this distribution for an example of it's use. C<CSL_soap_passwd>
is optional if no password is required for the user
specified in C<CSL_soap_user>.

=head1 SEE ALSO

L<Apache::CPAN::Search>, L<Apache::CPAN::Query>,
and L<CPAN::Search::Lite::Query>.

=cut

