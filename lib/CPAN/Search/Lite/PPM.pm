package CPAN::Search::Lite::PPM;
use strict;
use LWP::UserAgent;
use SOAP::Lite;
use XML::Parser;
use PPM::XML::PPD;
use PPM::XML::PPMConfig;
use CPAN::Search::Lite::Util qw($repositories);
our $VERSION = 0.68;

my %current_package;

sub new {
    my ($class, %args) = @_;
    die "Please supply distribution data" unless $args{dists};
    my $self = {dists => $args{dists}, ppms => {}};
    bless $self, $class;
}

sub fetch_info {
    my $self = shift;
    my $dists = $self->{dists};
    my $ppm = {};
    for my $id (keys %$repositories) {
        my $location = $repositories->{$id}->{LOCATION};
        print "Getting ppm information from $location\n";
        my $packages = summary($location);
        next unless $packages;
        foreach my $package (keys %$packages) {
            next unless $dists->{$package};
            my $version = ppd2cpan_version($packages->{$package}->{VERSION});
            my $abstract = $packages->{$package}->{ABSTRACT};
            $dists->{$package}->{description} = $abstract
                unless $dists->{$package}->{description};
            $ppm->{$id}->{$package} = {
                                       version => $version,
                                       abstract => $abstract,
                                      };
        }
    }
    $self->{ppms} = $ppm;
    return 1;
}

sub summary {
    my $loc = shift;
    my $packages;
    # see if the repository has server-side searching
    # see if a summary file is available
    my %summary = RepositorySummary(location => $loc);
    return unless %summary;
    foreach my $package (keys %{$summary{$loc}}) {
        $packages->{$package} = \%{$summary{$loc}{$package}};
    }
    return $packages;
}

sub ppd2cpan_version {
    local $_ = shift;
    s/(,0)*$//;
    tr/,/./;
    return $_;
}
# Returns a summary of available packages for all repositories.
# Returned hash has the following structure:
#
#    $hash{repository}{package_name}{NAME}
#    $hash{repository}{package_name}{VERSION}
#    etc.
#
sub RepositorySummary {
    my %argv = @_;
    my $location = $argv{location}; 
    my (%summary, $locations);

    # If we weren't given the location of a repository to query the summary
    # for, check all of the repositories that we know about.
    foreach (keys %$repositories) {
        if ($location =~ /^\Q$repositories->{$_}->{LOCATION}\E$/i) {
            $locations->{$repositories->{$_}->{LOCATION}} =
                $repositories->{$_}->{SUMMARYFILE};
            last;
        }
    }

    # Check all of the summary file locations that we were able to find.
    foreach $location (keys %$locations) {
        my $summaryfile = $locations->{$location};
        next unless ($summaryfile);
        my $data;
        next unless 
            ($data = read_href(request => 'GET',
                               href => "$location/$summaryfile"));
        $summary{$location} = parse_summary($data);
    }

    return %summary;
}

sub read_href {
    my %argv = @_;
    my $href = $argv{href};
    my $request = $argv{request};
    my $target = $argv{target};
    my ($proxy_user, $proxy_pass);
    # If this is a SOAP URL, handle it differently than FTP/HTTP/file.
    if ($href =~ m#^(http://.*)\?(.*)#i) {
        my ($proxy, $uri) = ($1, $2);
        my $fcn;
        if ($uri =~ m#(.*:/.*)/(.+?)$#) {
            ($uri, $fcn) = ($1, $2);
        }
        my $client = SOAP::Lite -> uri($uri) -> proxy($proxy);
        if ($fcn eq 'fetch_summary') {
            my $summary = eval { $client->fetch_summary()->result; };
            if ($@) {
                warn $@;
                return;
            }
            return $summary;
        }
        $fcn =~ s/\.ppd$//i;
        my $ppd = eval { $client->fetch_ppd($fcn)->result };
        if ($@) {
                warn $@;
                return;
        }
        return $ppd;
        # todo: write to disk file if $target
    }
    # Otherwise it's a standard URL, go ahead and request it using LWP.
    my $ua = new LWP::UserAgent;
    $ua->agent($ENV{HTTP_proxy_agent} || ("$0/0.1 " . $ua->agent));
    if (defined $ENV{HTTP_proxy}) {
        $proxy_user = $ENV{HTTP_proxy_user};
        $proxy_pass = $ENV{HTTP_proxy_pass};
        $ua->env_proxy;
    }
    my $req = new HTTP::Request $request => $href;
    if (defined $proxy_user && defined $proxy_pass) {
        $req->proxy_authorization_basic("$proxy_user", "$proxy_pass");
    }

    # Do we need to do authorization?
    # This is a hack, but will have to do for now.
    foreach (keys %$repositories) {
        if ($href =~ /^$repositories->{$_}->{LOCATION}/i) {
            my $username = 'anonymous';
            my $password = 'cpan-search@cpan.org';
            if (defined $username && defined $password) {
                $req->authorization_basic($username, $password);
                last;
            }
        }
    }

    my $response = $ua->request($req);
    if ($response && $response->is_success) {
        return $response->content;
    }
    if ($response) {
        warn(qq{Error reading $href: } . $response->code . " " . 
             $response->message);
         }
    else {
        warn ("read_href: Error reading $href");
    }
    return;
}

sub parse_summary {
    my $data = shift;
    my (%summary, @parsed);

    # take care of '&'
    $data =~ s/&(?!\w+;)/&amp;/go;

    my $parser = new XML::Parser( Style => 'Objects', 
        Pkg => 'PPM::XML::RepositorySummary' );
    eval { @parsed = @{ $parser->parse( $data ) } };
    if ($@) {
        warn $@;
        return;
    }

    my $packages = ${$parsed[0]}{Kids};

    foreach my $package (@{$packages}) {
        my $elem_type = ref $package;
        $elem_type =~ s/.*:://;
        next if ($elem_type eq 'Characters');

        if ($elem_type eq 'SOFTPKG') {
            my %ret_hash;
            parsePPD(%{$package});
            %ret_hash = map { $_ => $current_package{$_} } 
                qw(NAME TITLE AUTHOR VERSION ABSTRACT);
            $summary{$current_package{NAME}} = \%ret_hash;
        }
    }
    return \%summary;
}

sub parsePPD {
    my %PPD = @_;
    my $pkg;
    
    %current_package = ();

    # Get the package name and version from the attributes and stick it
    # into the 'current package' global var
    $current_package{NAME}    = $PPD{NAME};
    $current_package{VERSION} = $PPD{VERSION};
    
    # Get all the information for this package and put it into the 'current
    # package' global var.
    my $got_implementation = 0;
    my $elem;
    
    foreach $elem (@{$PPD{Kids}}) {
        my $elem_type = ref $elem;
        $elem_type =~ s/.*:://;
        next if ($elem_type eq 'Characters');
        
        if ($elem_type eq 'TITLE') {
            # Get the package title out of our _only_ char data child
            $current_package{TITLE} = $elem->{Kids}[0]{Text};
        }
        elsif ($elem_type eq 'ABSTRACT') {
            # Get the package abstract out of our _only_ char data child
            $current_package{ABSTRACT} = $elem->{Kids}[0]{Text};
        }
        elsif ($elem_type eq 'AUTHOR') {
            # Get the authors name out of our _only_ char data child
            $current_package{AUTHOR} = $elem->{Kids}[0]{Text};
        }
        else {
            next;
        }
    } # End of "for each child element inside the PPD"
    
}

1;

__END__

=head1 NAME

CPAN::Search::Lite::PPM - extract ppm package information from repositories

=head1 DESCRIPTION

This module gets information on available ppm packages on remote 
repositories. The repositories searched are specified in
C<$respositories> of I<CPAN::Search::Lite::Util>. Only those
distributions whose names appear from I<CPAN::Search::Lite::Info>
are saved. After creating a I<CPAN::Search::Lite::PPM> object through
the C<new> method and calling the C<fetch_info> method, the 
information is available as:

   my $ppms = $ppm_obj->{ppms};
   for my $rep_id (keys %{$ppms}) {
     print "For repository with id = $rep_id:\n";
     for my $package (keys %{$ppms->{$id}}) {
       print << "END";
 
 Package: $package
 Version: $ppms->{$rep_id}->{$package}->{version}
 Abstract: $ppms->{$rep_id}->{$package}->{abstract}

 END
     }
   }

=head1 SEE ALSO

L<CPAN::Search::Lite::Index>

=cut

=cut

