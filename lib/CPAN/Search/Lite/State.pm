package CPAN::Search::Lite::State;
use strict;
use warnings;
no warnings qw(redefine);
use DBI;
require Sort::Versions;

our ($dbh);

my $no_ppm;
my %tbl2obj;
$tbl2obj{$_} = __PACKAGE__ . '::' . $_ for (qw(dists mods auths ppms));
my %obj2tbl = reverse %tbl2obj;

sub new {
  my ($class, %args) = @_;
  
  foreach (qw(db user passwd) ) {
    die "Must supply a '$_' argument" unless $args{$_};
  }
    
  if ($args{setup}) {
      die "No state information available under setup";
  }

  $no_ppm = $args{no_ppm};

  my $index = $args{index};
  my @tables = qw(dists mods auths);
  push @tables, 'ppms' unless $no_ppm;
  foreach my $table (@tables) {
      my $obj = $index->{$table};
      die "Please supply a CPAN::Search::Lite::Index::$table object"
          unless ($obj and ref($obj) eq "CPAN::Search::Lite::Index::$table");
  }
  $dbh = DBI->connect("DBI:mysql:$args{db}", $args{user}, $args{passwd},
                      {RaiseError => 1, AutoCommit => 0})
    or die "Cannot connect to $args{db}";

  my $self = {index => $index,
              obj => {},
             };
  bless $self, $class;
}

sub state {
    my $self = shift;
    unless ($self->create_objs()) {
        print "Cannot create objects";
        return;
    }
    unless ($self->state_info()) {
        print "Getting state information failed";
        return;
    };
    return 1;
}

sub create_objs {
    my $self = shift;
    my @tables = qw(dists auths mods);
    push @tables, 'ppms' unless $no_ppm;

    foreach my $table (@tables) {
        my $obj;
        my $pack = $tbl2obj{$table};
        my $index = $self->{index}->{$table};
        if ($index and ref($index) eq "CPAN::Search::Lite::Index::$table") {
            my $info = $index->{info};
            return unless $self->has_data($info);
            $obj = $pack->new(info => $info);
        }
        else {
            $obj = $pack->new();
        }
        $self->{obj}->{$table} = $obj;
    }
    foreach my $table (@tables) {
        my $obj = $self->{obj}->{$table};
        foreach (@tables) {
            next if ref($obj) eq $tbl2obj{$_};
            $obj->{obj}->{$_} = $self->{obj}->{$_};
        }
    }
    return 1;
}

sub state_info {
    my $self = shift;
    my @methods = qw(ids state);
    my @tables = qw(dists auths mods);
    push @tables, 'ppms' unless $no_ppm;

    for my $method (@methods) {
        for my $table (@tables) {
            my $obj = $self->{obj}->{$table};
            unless ($obj->$method()) {
                if (my $error = $obj->{error_msg}) {
                    print "Fatal error from ", ref($obj), ": ", $error, $/;
                    return;
                }
                else {
                    my $info = $obj->{info_msg};
                    print "Info from ", ref($obj), ": ", $info, $/;
                }
            }
       }
    }
    return 1;
}

package CPAN::Search::Lite::State::auths;
use base qw(CPAN::Search::Lite::State);

sub new {
  my ($class, %args) = @_;
  my $info = $args{info};
  die "No author info available" unless $class->has_data($info);
  my $self = {
              info => $info,
              insert => {},
              update => {},
              delete => {},
              ids => {},
              obj => {},
              error_msg => '',
              info_msg => '',
             };
  bless $self, $class;
}

sub ids {
  my $self = shift;
  my $fields = [qw(auth_id cpanid)];
  $self->fetch_ids($fields) or return;
  return 1;
}

sub state {
  my $self = shift;
  my $auth_ids = $self->{ids};
  return unless my $dist_obj = $self->{obj}->{dists};
  my $dist_update = $dist_obj->{update};
  my $dist_insert = $dist_obj->{insert};
  my $dists = $dist_obj->{info};
  my ($update, $insert);
  if ($self->has_data($dist_insert)) {
    foreach my $distname (keys %{$dist_insert}) {
      my $cpanid = $dists->{$distname}->{cpanid};
      if (my $auth_id = $auth_ids->{$cpanid}) {
        $update->{$cpanid} = $auth_id;
      }
      else {
        $insert->{$cpanid}++;
      }
    }
  }
  if ($self->has_data($dist_update)) {
    foreach my $distname (keys %{$dist_update}) {
      my $cpanid = $dists->{$distname}->{cpanid};
      if (my $auth_id = $auth_ids->{$cpanid}) {
        $update->{$cpanid} = $auth_id;
      }
      else {
        $insert->{$cpanid}++;
      }
    }
  }
  $self->{update} = $update;
  $self->{insert} = $insert;
  return 1;
}

package CPAN::Search::Lite::State::dists;
use base qw(CPAN::Search::Lite::State);

sub new {
  my ($class, %args) = @_;
  my $info = $args{info};
  die "No dist info available" unless $class->has_data($info);
  my $self = {
              info => $info,
              insert => {},
              update => {},
              delete => {},
              ids => {},
              versions => {},
              obj => {},
              error_msg => '',
              info_msg => '',
  };
  bless $self, $class;
}

sub ids {
  my $self = shift;
  my $fields = [qw(dist_id dist_name dist_vers)];
  $self->fetch_ids($fields) or return;
  return 1;
}

sub state {
  my $self = shift;
  my $dist_versions = $self->{versions};
  my $dists = $self->{info};
  my $dist_ids = $self->{ids};
  my ($insert, $update, $delete);
  foreach my $distname (keys %$dists) {
    if (not defined $dist_versions->{$distname}) {
      $insert->{$distname}++;
    }
    elsif ($self->vcmp($dists->{$distname}->{version}, 
                       $dist_versions->{$distname}) > 0) {
      $update->{$distname} = $dist_ids->{$distname};
    }
  }
  $self->{update} = $update;
  $self->{insert} = $insert;
  foreach my $distname(keys %$dist_versions) {
    next if $dists->{$distname};
    $delete->{$distname} = $dist_ids->{$distname};
    print "Will delete $distname\n";
  }
  $self->{delete} = $delete;
  return 1;
}

package CPAN::Search::Lite::State::mods;
use base qw(CPAN::Search::Lite::State);

sub new {
  my ($class, %args) = @_;
  my $info = $args{info};
  die "No module info available" unless $class->has_data($info);
  my $self = {
              info => $info,
              insert => {},
              update => {},
              delete => {},
              ids => {},
              obj => {},
              error_msg => '',
              info_msg => '',
             };
  bless $self, $class;
}

sub ids {
  my $self = shift;
  my $fields = [qw(mod_id mod_name)];
  $self->fetch_ids($fields) or return;
  return 1;
}

sub state {
  my $self = shift;
  my $mods = $self->{info};
  my $mod_ids = $self->{ids};
  return unless my $dist_obj = $self->{obj}->{dists};
  my $dists = $dist_obj->{info};
  my $dist_update = $dist_obj->{update};
  my $dist_insert = $dist_obj->{insert};
  my ($update, $insert, $delete);
  if ($self->has_data($dist_insert)) {
    foreach my $distname (keys %{$dist_insert}) {
      foreach my $module(keys %{$dists->{$distname}->{modules}}) {
        $insert->{$module}++;
      }   
    }
  }
  if ($self->has_data($dist_update)) {
    foreach my $distname (keys %{$dist_update}) {
      foreach my $module(keys %{$dists->{$distname}->{modules}}) {
        my $mod_id = $mod_ids->{$module};
        if ($mod_id) {
          $update->{$module} = $mod_id;
        }
        else {
          $insert->{$module}++;
        }
      }   
    }
  }
  $self->{update} = $update;
  $self->{insert} = $insert;
  return 1;
}

package CPAN::Search::Lite::State::ppms;
use base qw(CPAN::Search::Lite::State);

sub new {
  my ($class, %args) = @_;
  my $info = $args{info};
  die "No ppm info available" unless $class->has_data($info);
  my $self = {
              info => $info,
              insert => {},
              update => {},
              delete => {},
              ids => {},
              versions => {},
              obj => {},
              error_msg => '',
              info_msg => '',
             };
  bless $self, $class;
}

sub ids {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  my ($ppm_ids, $ppm_versions);
  my $sql = q{SELECT rep_id,dist_name,dists.dist_id,ppm_vers} .
    q{ FROM dists,ppms} .
      q{ WHERE ppms.dist_id = dists.dist_id};
  my $sth = $dbh->prepare($sql) or do {
    db_error($self, $dbh);
    return;
  };
  $sth->execute() or do {
    db_error($self, $dbh, $sth);
    return;
  };
  while (my ($rep_id, $distname, $dist_id, $ppm_vers) = 
         $sth->fetchrow_array()) {
    $ppm_ids->{$rep_id}->{$distname} = $dist_id;
    $ppm_versions->{$rep_id}->{$distname} = $ppm_vers;
  }
  $sth->finish();
  $self->{ids} = $ppm_ids;
  $self->{versions} = $ppm_versions;
  return 1;
}

sub state {
  my $self = shift;
  my $ppm_versions = $self->{versions};
  my $ppms = $self->{info};
  my $ppm_ids = $self->{ids};
  my ($update, $insert, $delete);
  foreach my $id (keys %$ppms) {
      my $values = $ppms->{$id};
      next unless $self->has_data($values);
      foreach my $package (keys %{$values}) {
          if (not defined $ppm_versions->{$id}->{$package}) {
              $insert->{$id}->{$package}->{version} =
                  $ppms->{$id}->{$package}->{version};
          }
          elsif ($self->vcmp($ppms->{$id}->{$package}->{version}, 
                             $ppm_versions->{$id}->{$package}) > 0) {
              $update->{$id}->{$package} = 
              {dist_id => $ppm_ids->{$id}->{$package},
               ppm_vers => $ppms->{$id}->{$package}->{version}};
          }
      }
 }
  $self->{insert} = $insert;
  $self->{update} = $update;
   foreach my $id (keys %$ppms) {
      my $values = $ppms->{$id};
      next unless $self->has_data($values);
      foreach my $package (keys %{$values}) {
          next unless not $ppms->{$id}->{$package};
          $delete->{$id}->{$package} = 
              $ppm_ids->{$id}->{$package};
      }
  }
  $self->{delete} = $delete;
  return 1;
}

package CPAN::Search::Lite::State;

sub fetch_ids {
    my ($self, $fields) = @_;
    unless ($dbh) {
        $self->{error_msg} = q{No db handle available};
        return;
    }
    my @fields = @$fields;
    my ($ids, $versions);
    my $sql = q{SELECT } . join(',', @fields) .
        q{ FROM } . $obj2tbl{ref($self)};
    my $sth = $dbh->prepare($sql) or do {
        $self->db_error();
        return;
    };
    $sth->execute() or do {
        $self->db_error($sth);
        return;
    };
    if (scalar @fields == 2) {
        while (my ($id, $key) = $sth->fetchrow_array()) {
            $ids->{$key} = $id;
        }
        $sth->finish;
        $self->{ids} = $ids;
    }
    else {
        while (my ($id, $key, $vers) = $sth->fetchrow_array()) {
            $ids->{$key} = $id;
            $versions->{$key} = $vers;
        }
        $sth->finish;
        $self->{ids} = $ids;
        $self->{versions} = $versions;        
    }
    return 1;
}

sub db_error {
    my ($obj, $sth) = @_;
    return unless $dbh;
    $sth->finish if $sth;
    $obj->{error_msg} = q{Database error: } . $dbh->errstr;
}

sub has_data {
  my ($self, $data) = @_;
  return unless (defined $data and ref($data) eq 'HASH');
  return (scalar keys %$data > 0) ? 1 : 0;
}

sub vcmp {
    my ($self, $v1, $v2) = @_;
    return unless (defined $v1 and defined $v2);
    return Sort::Versions::versioncmp($v1, $v2);
}

sub DESTROY {
    $dbh->disconnect;
}

1;

__END__

=head1 NAME

CPAN::Search::Lite::State - get state information on the database

=head1 DESCRIPTION

This module gets information on the current state of the
database and compares it to that obtained from the CPAN
index files from I<CPAN::Search::Lite::Info> and from the
repositories from I<CPAN::Search::Lite::PPM>. For each of the
four tables I<dists>, I<mods>, I<auths>, and I<ppms>,
two methods are used to get this information:

=over 3

=item * C<ids>

This method gets the ids of the relevant names, and
versions, if applicable, in the table.

=item * C<state>

This method compares the information in the tables
obtained from the C<ids> method to that from the
CPAN indices and ppm repositories. One of three actions
is then decided, which is subsequently acted upon in 
I<CPAN::Search::Lite::Populate>.

=over 3

=item * C<insert>

If the information in the indices is not in the
database, this information is marked for insertion.

=item * C<update>

If the information in the database is older than that
form the indices (generally, this means an older version),
the information is marked for updating.

=item * C<delete>

If the information in the database is no longer present
in the indices, the information is marked for deletion.

=back

=back

=cut

