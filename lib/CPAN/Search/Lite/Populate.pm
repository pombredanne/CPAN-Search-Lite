package CPAN::Search::Lite::Populate;
use strict;
use warnings;
no warnings qw(redefine);
use DBI;
use CPAN::Search::Lite::Util qw($table_id);
use File::Find;
use File::Basename;
use File::Spec::Functions;

our ($dbh);

my ($setup, $no_ppm);
my %tbl2obj;
$tbl2obj{$_} = __PACKAGE__ . '::' . $_ 
    for (qw(dists mods auths ppms chaps reqs));
my %obj2tbl  = reverse %tbl2obj;

sub new {
  my ($class, %args) = @_;
  
  foreach (qw(db user passwd) ) {
    die "Must supply a '$_' argument" unless $args{$_};
  }
    
  $setup = $args{setup};
  $no_ppm = $args{no_ppm};

  my $index = $args{index};
  my @tables = qw(dists mods auths);
  push @tables, 'ppms' unless $no_ppm;
  foreach my $table (@tables) {
      my $obj = $index->{$table};
      die "Please supply a CPAN::Search::Lite::Index::$table object"
          unless ($obj and ref($obj) eq "CPAN::Search::Lite::Index::$table");
  }
  my $state = $args{state};
  unless ($setup) {
      die "Please supply a CPAN::Search::Lite::State object"
          unless ($state and ref($state) eq 'CPAN::Search::Lite::State');
  }

  $dbh = DBI->connect("DBI:mysql:$args{db}", $args{user}, $args{passwd},
                      {RaiseError => 1, AutoCommit => 0})
    or die "Cannot connect to $args{db}";

  my $no_mirror = $args{no_mirror};
  my $html_root = $args{html_root};
  unless ($no_mirror) {
      die "Please supply the html root" unless $html_root;
  }
  my $self = {index => $index,
              state => $state,
              obj => {},
              no_mirror => $no_mirror,
              html_root => $html_root,
             };
  bless $self, $class;
}

sub populate {
    my $self = shift;

    if ($setup) {
        unless ($self->create_tables()) {
            warn "Creating tables failed";
            return;
        }
    }
    unless ($self->create_objs()) {
        warn "Cannot create objects";
        return;
    }
    unless ($self->populate_tables()) {
        warn "Populating tables failed";
        return;
    }
    unless ($self->{no_mirror}) {
        $self->fix_links() or do {
            warn "Fixing html links failed";
            return;
        };
    }
    return 1;
}

sub create_objs {
    my $self = shift;
    my @tables = qw(dists auths mods reqs chaps);
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

    unless ($setup) {
        my $state = $self->{state};
        my @tables = qw(auths dists mods);
        push @tables, 'ppms' unless $no_ppm;
        my @data = qw(ids insert update delete);

        foreach my $table (@tables) {
            my $state_obj = $state->{obj}->{$table};
            my $pop_obj = $self->{obj}->{$table};
            $pop_obj->{$_} = $state_obj->{$_} for (@data);
        }
    }
    return 1;
}

sub populate_tables {
    my $self = shift;
    my @methods = $setup ? qw(insert) : qw(insert update delete);
    my @tables = qw(auths dists mods reqs chaps);
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

sub create_tables {
    return unless $setup;
    my $self = shift;
    unless ($dbh) {
        $self->{error_msg} = q{No db handle available};
        return;
    }
    
  $dbh->do(q{drop table if exists mods});
  $dbh->do(q{CREATE TABLE mods (
                                mod_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                dist_id SMALLINT UNSIGNED NOT NULL,
                                mod_name VARCHAR(50) NOT NULL,
                                mod_abs TINYTEXT,
                                doc bool,
                                mod_vers VARCHAR(10),
                                dslip CHAR(5),
                                chapterid TINYINT(2) UNSIGNED,
                                PRIMARY KEY (mod_id),
                                FULLTEXT (mod_abs),
                                KEY (dist_id),
                                KEY (mod_name(50)),
                               )})
    or do {
      $self->db_error();
      return;
    };
  
  $dbh->do(q{drop table if exists dists});
  $dbh->do(q{CREATE TABLE dists (
                                 dist_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                 stamp TIMESTAMP(8),
                                 auth_id SMALLINT UNSIGNED NOT NULL,
                                 dist_name VARCHAR(60) NOT NULL,
                                 dist_file VARCHAR(90) NOT NULL,
                                 dist_vers VARCHAR(20),
                                 dist_abs TINYTEXT,
                                 size MEDIUMINT UNSIGNED NOT NULL,
                                 birth DATE NOT NULL,
                                 readme bool,
                                 changes bool,
                                 meta bool,
                                 install bool,
                                 PRIMARY KEY (dist_id),
                                 FULLTEXT (dist_abs),
                                 KEY (auth_id),
                                 KEY (dist_name(60)),
                                )})
    or do {
      $self->db_error();
      return;
    };
  
  $dbh->do(q{drop table if exists auths});    
  $dbh->do(q{CREATE TABLE auths (
                                 auth_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                 cpanid VARCHAR(20) NOT NULL,
                                 fullname VARCHAR(40) NOT NULL,
                                 email TINYTEXT,
                                 PRIMARY KEY (auth_id),
                                 FULLTEXT (fullname),
                                 KEY (cpanid(20)),
                                )})
    or do {
      $self->db_error();
      return;
    };
  
  $dbh->do(q{drop table if exists chaps});
  $dbh->do(q{CREATE TABLE chaps (
                                 chapterid TINYINT UNSIGNED NOT NULL,
                                 dist_id SMALLINT UNSIGNED NOT NULL,
                                 subchapter TINYTEXT,
                                 KEY (dist_id),
                                )})
    or do {
      $self->db_error();
      return;
    };
  
  $dbh->do(q{drop table if exists reqs});
  $dbh->do(q{CREATE TABLE reqs (
                                dist_id SMALLINT UNSIGNED NOT NULL,
                                mod_id SMALLINT UNSIGNED NOT NULL,
                                req_vers VARCHAR(10),
                                KEY (dist_id),
                               )})
    or do {
      $self->db_error();
      return;
    };
  
  $dbh->do(q{drop table if exists ppms});
  $dbh->do(q{CREATE TABLE ppms (
                                dist_id SMALLINT UNSIGNED NOT NULL,
                                rep_id TINYINT(2) UNSIGNED NOT NULL,
                                ppm_vers VARCHAR(20),
                                KEY (dist_id),
                               )})
    or do {
      $self->db_error();
      return;
    };
  return 1;
}

sub fix_links {
    my $self = shift;
    unless ($dbh) {
        $self->{error_msg} = q{No db handle available};
        return;
    }
    my %textfiles = map {$_ . '.html' => 1} 
    qw(README META Changes META index INSTALL);
    my $html_root = $self->{html_root};

    my $docs;
    my $sql = q{ SELECT mod_name,dist_name,doc } .
        q { FROM mods,dists WHERE mods.dist_id = dists.dist_id };
    my $sth = $dbh->prepare($sql);
    $sth->execute() or do {
        $self->db_error($sth);
        return;
    };
    while (my ($mod_name, $dist_name, $doc) = $sth->fetchrow_array) {
        next unless $doc;
        $docs->{$mod_name} = $dist_name;
    }
    $sth->finish;

    my $dist_obj;
    unless ($dist_obj = $self->{obj}->{dists}) {
        warn "No dist object available";
        return;
    }
    my (@dist_roots, $data);
    if ($setup) {
        $data = $dist_obj->{info};
        if ($self->has_data($data)) {
            @dist_roots = keys %$data;
        }
    }
    else {
        $data = $dist_obj->{insert};
        if ($self->has_data($data)) {
            @dist_roots = keys %$data;
        }
        $data = $dist_obj->{update};
        if ($self->has_data($data)) {
            push @dist_roots, keys %$data;
        }
    }
    unless (@dist_roots) {
        print "No distributions need editing";
        return 1;
    }
    foreach my $dist_root (@dist_roots) {
        my $dist_path = catdir $html_root, $dist_root;
        my @files = ();
        finddepth( sub{
            not $textfiles{basename($File::Find::name)} 
            and push @files, $File::Find::name 
                if $File::Find::name =~ /\.html$/},
                   $dist_path);
        print "Editing links within $dist_root\n";
        edit_links(\@files, $dist_root, $docs) or do {
            warn "Editing links within $dist_root failed";
            return;
        };
    }
    return 1;
}

sub edit_links {
    my ($files, $dist_root, $docs) = @_;
    foreach my $file (@$files) {
        my $orig = $file . '.orig';
        rename $file, $orig or do {
            warn "Cannot rename $file to $orig: $!";
            return;
        };
        open(my $rfh, $orig) or do {
            warn "Cannot open $orig: $!";
            return;
        };
        open(my $wfh, '>', $file) or do {
            warn "Cannot open $file: $!";
            return;
        };
        while(my $line = <$rfh>) {
            if ($line =~ /manpage/) {
                my $copy = $line;
                while ($line =~ m!(<a href=[^>]+>the (\S+) manpage</a>)!g) {
                    my $link = $1;
                    my $mod = $2;
                    my ($section) = $mod =~ m!(\(\d+\))!;
                    $mod =~ s!\Q$section\E!! if $section;
                    my ($fixed, $dist);
                    if ($dist = $docs->{$mod}) {
                        ($fixed = $link) =~ s!$dist_root!$dist!;
                        $fixed =~ s/\Q$section\E//g if $section;
                    }
                    else {
                        $fixed = "<em>$mod</em>";
                    }
                    $copy =~ s/\Q$link\E/$fixed/;
                }
                print $wfh $copy;
            }
            else {
                print $wfh $line;
            }
        }
        close $wfh;
        close $rfh;
        unlink $orig or warn "Could not unlink $orig: $!";
    }
    return 1;
}
    
package CPAN::Search::Lite::Populate::auths;
use base qw(CPAN::Search::Lite::Populate);

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

sub insert {
    my $self = shift;
    unless ($dbh) {
        $self->{error_msg} = q{No db handle available};
        return;
    }
    my $info = $self->{info};
    my $data = $setup ? $info : $self->{insert};
    unless ($self->has_data($data)) {
        $self->{info_msg} = q{No author data to insert};
        return;
    }
    my $auth_ids = $self->{ids};
    my @fields = qw(cpanid email fullname);
    my $sql = $self->sql_insert(\@fields);
    my $sth = $dbh->prepare($sql) or $self->db_error();
    foreach my $cpanid (keys %$data) {
        my $values = $info->{$cpanid};
        next unless ($values and $cpanid);
        print "Inserting author $cpanid\n";
        $sth->execute($cpanid, $values->{email}, $values->{fullname})
            or do {
                $self->db_error($sth);
                return;
            };
        $auth_ids->{$cpanid} = $sth->{mysql_insertid};
    }
    $dbh->commit or do {
        $self->db_error($sth);
        return;
    };
    $sth->finish();
    return 1;
}

sub update {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  my $data = $self->{update};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No author data to update};
    return;
  }
  
  my $info = $self->{info};
  
  my @fields = qw(cpanid email fullname);
  foreach my $cpanid (keys %$data) {
    print "Updating author $cpanid\n";
    next unless $data->{$cpanid};
    my $sql = $self->sql_update(\@fields, $data->{$cpanid});
    my $sth = $dbh->prepare($sql) or do {
      $self->db_error();
      return;
    };
    my $values = $info->{$cpanid};
    next unless ($cpanid and $values);
    $sth->execute($cpanid, $values->{email}, $values->{fullname})
      or do {
        $self->db_error($sth);
        return;
      };
    $sth->finish();
  }
  $dbh->commit or $self->db_error();
  return 1;
}

sub delete {
  my $self = shift;
  $self->{info_msg} = q{No author data to delete};
  return;
}

package CPAN::Search::Lite::Populate::dists;
use base qw(CPAN::Search::Lite::Populate);

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
              obj => {},
              error_msg => '',
              info_msg => '',
  };
  bless $self, $class;
}

sub insert {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $auth_obj = $self->{obj}->{auths};
  my $auth_ids = $auth_obj->{ids};
  my $dists = $self->{info};
  my $data = $setup ? $dists : $self->{insert};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No dist data to insert};
    return;
  }
  unless ($dists and $auth_ids) {
    $self->{error_msg}->{index} = q{No dist index data available};
    return;
  }
  
  my $dist_ids = $self->{ids};
  my @fields = qw(auth_id dist_name dist_file dist_vers
                  dist_abs size birth readme changes meta install);
  my $sql = $self->sql_insert(\@fields);
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $distname (keys %$data) {
    my $values = $dists->{$distname};
    my $cpanid = $values->{cpanid};
    next unless ($values and $cpanid and $auth_ids->{$cpanid});
    print "Inserting $distname of $cpanid\n";
    $sth->execute($auth_ids->{$cpanid}, $distname, 
                  $values->{filename}, $values->{version}, 
                  $values->{description}, $values->{size}, 
                  $values->{date}, $values->{readme}, 
                  $values->{changes}, $values->{meta},
                  $values->{install}) 
      or do {
        $self->db_error($sth);
        return;
      };
    $dist_ids->{$distname} = $sth->{mysql_insertid};
  }
  $dbh->commit or do {
      $self->db_error($sth);
      return;
  };
  $sth->finish();
  return 1;
}

sub update {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  my $data = $self->{update};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No dist data to update};
    return;
  }
  return unless my $auth_obj = $self->{obj}->{auths};
  my $auth_ids = $auth_obj->{ids};
  my $dists = $self->{info};
  unless ($dists and $auth_ids) {
    $self->{error_msg} = q{No dist index data available};
    return;
  }
  
  my @fields = qw(auth_id dist_name dist_file dist_vers
                  dist_abs size birth readme changes meta install);
  foreach my $distname (keys %$data) {
      next unless $data->{$distname};
      my $sql = $self->sql_update(\@fields, $data->{$distname});
      my $sth = $dbh->prepare($sql) or do {
          $self->db_error();
          return;
      };
      my $values = $dists->{$distname};
      my $cpanid = $values->{cpanid};
      next unless ($values and $cpanid and $auth_ids->{$cpanid});
      print "Updating $distname of $cpanid\n";
      $sth->execute($auth_ids->{$values->{cpanid}}, $distname, 
                    $values->{filename}, $values->{version}, 
                    $values->{description}, $values->{size}, 
                    $values->{date}, $values->{readme}, 
                    $values->{changes}, $values->{meta},
                    $values->{install}) 
          or do {
              $self->db_error($sth);
              return;
          };
      $sth->finish();
  }
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

sub delete {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  my $data = $self->{delete};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No dist data to delete};
    return;
  }
  
  my $sql = $self->sql_delete('dist_id');
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $distname(keys %$data) {
    print "Deleting $distname\n";
    $sth->execute($data->{$distname}) or do {
      $self->db_error($sth);
      return;
    };
  }
  $sth->finish();
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

package CPAN::Search::Lite::Populate::mods;
use base qw(CPAN::Search::Lite::Populate);

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

sub insert {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $dist_ids = $dist_obj->{ids};
  my $mods = $self->{info};
  my $data = $setup ? $mods : $self->{insert};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No module data to insert};
    return;
  }
  unless ($mods and $dist_ids) {
    $self->{error_msg} = q{No module index data available};
    return;
  }
  
  my $mod_ids = $self->{ids};
  my @fields = qw(dist_id mod_name mod_abs doc 
                  mod_vers dslip chapterid);
  my $sql = $self->sql_insert(\@fields);
  my $sth = $dbh->prepare($sql) or do {
        $self->db_error();
        return;
      };
  foreach my $modname(keys %$data) {
    my $values = $mods->{$modname};
    next unless ($values and $dist_ids->{$values->{dist}});
    $sth->execute($dist_ids->{$values->{dist}}, $modname, 
                  $values->{description}, $values->{doc}, 
                  $values->{version}, $values->{dslip}, 
                  $values->{chapterid}) 
      or do {
        $self->db_error($sth);
        return;
      };
    $mod_ids->{$modname} = $sth->{mysql_insertid};
  }
  $dbh->commit or do {
    $self->db_error($sth);
    return;
  };
  $sth->finish();
  return 1;
}

sub update {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  my $data = $self->{update};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No module data to update};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $dist_ids = $dist_obj->{ids};
  my $mods = $self->{info};
  unless ($dist_ids and $mods) {
    $self->{error_msg} = q{No module index data available};
    return;
  }
  
  my @fields = qw(dist_id mod_name mod_abs doc 
                  mod_vers dslip chapterid);
  foreach my $modname (keys %$data) {
      next unless $data->{$modname};
      print "Updating $modname\n";
      my $sql = $self->sql_update(\@fields, $data->{$modname});
      my $sth = $dbh->prepare($sql) or do {
          $self->db_error();
          return;
      };
      my $values = $mods->{$modname};
      next unless ($values and $dist_ids->{$values->{dist}});
      $sth->execute($dist_ids->{$values->{dist}}, $modname, 
                    $values->{description}, $values->{doc}, 
                    $values->{version}, $values->{dslip}, 
                    $values->{chapterid}) 
          or do {
              $self->db_error($sth);
              return;
          };
      $sth->finish();
  }
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

sub delete {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
        return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $data = $dist_obj->{delete};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No module data to delete};
    return;
  }
  
  my $sql = $self->sql_delete('dist_id');
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $distname(keys %$data) {
    $sth->execute($data->{$distname}) or do {
      $self->db_error($sth);
      return;
    };
  }
  $sth->finish();
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

package CPAN::Search::Lite::Populate::chaps;
use base qw(CPAN::Search::Lite::Populate);

sub new {
  my ($class, %args) = @_;
  my $self = {
              obj => {},
              error_msg => '',
              info_msg => '',
             };
  bless $self, $class;
}

sub insert {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $dist_insert = $dist_obj->{insert};
  my $dists = $dist_obj->{info};
  my $dist_ids = $dist_obj->{ids};
  my $data = $setup ? $dists : $dist_insert;
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No chap data to insert};
    return;
  }
  unless ($dists and $dist_ids) {
    $self->{error_msg} = q{No chap index data available};
    return;
  }
  
  my @fields = qw(chapterid dist_id subchapter);
  my $sql = $self->sql_insert(\@fields);
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $dist (keys %$data) {
    my $values = $dists->{$dist};
    next unless defined $values->{chapterid};
    foreach my $chap_id(keys %{$values->{chapterid}}) {
      foreach my $sub_chap(keys %{$values->{chapterid}->{$chap_id}}) {
        next unless $dist_ids->{$dist};
        $sth->execute($chap_id, $dist_ids->{$dist}, $sub_chap)
          or do {
            $self->db_error($sth);
            return;
          };
      }
    }
  }
  $dbh->commit or do {
    $self->db_error($sth);
    return;
  };
    $sth->finish();
  return 1;
}

sub update {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $dists = $dist_obj->{info};
  my $dist_ids = $dist_obj->{ids};
  my $data = $dist_obj->{update};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No chap data to update};
    return;
  }
  unless ($dist_ids and $dists) {
    $self->{error_msg} = q{No chap index data available};
    return;
  }
  
  my $sql = $self->sql_delete('dist_id');
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $distname(keys %$data) {
      next unless $data->{$distname};
      $sth->execute($data->{$distname}) or do {
          $self->db_error($sth);
          return;
      };
  }
  $sth->finish();
  
  my @fields = qw(chapterid dist_id subchapter);
  $sql = $self->sql_insert(\@fields);
  $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $dist (keys %$data) {
    my $values = $dists->{$dist};
    next unless defined $values->{chapterid};
    foreach my $chap_id(keys %{$values->{chapterid}}) {
      foreach my $sub_chap(keys %{$values->{chapterid}->{$chap_id}}) {
        next unless $dist_ids->{$dist};
        $sth->execute($chap_id, $dist_ids->{$dist}, $sub_chap)
          or do {
            $self->db_error($sth);
            return;
          };
      }
    }
  }
  $dbh->commit or do {
    $self->db_error($sth);
    return;
  };
  $sth->finish();
  return 1;
}

sub delete {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
        return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $data = $dist_obj->{delete};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No chap data to delete};
    return;
  }
  
  my $sql = $self->sql_delete('dist_id');
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $distname(keys %$data) {
    $sth->execute($data->{$distname}) or do {
      $self->db_error($sth);
      return;
    };
  }
  $sth->finish();
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

package CPAN::Search::Lite::Populate::reqs;
use base qw(CPAN::Search::Lite::Populate);

sub new {
    my ($class, %args) = @_;
    my $self = {
                obj => {},
                error_msg => '',
                info_msg => '',
               };
    bless $self, $class;
  }

sub insert {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  return unless my $mod_obj = $self->{obj}->{mods};
  my $dist_insert = $dist_obj->{insert};
  my $dists = $dist_obj->{info};
  my $dist_ids = $dist_obj->{ids};
  my $mod_ids = $mod_obj->{ids};
  my $data = $setup ? $dists : $dist_insert;
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No req data to insert};
    return;
  }
  unless ($dist_ids and $mod_ids and $dists) {
    $self->{error_msg} = q{No req index data available};
    return;
  }
  
  my @fields = qw(dist_id mod_id req_vers);
  my $sql = $self->sql_insert(\@fields);
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $dist (keys %$data) {
    my $values = $dists->{$dist};
    next unless defined $values->{requires};
    foreach my $module (keys %{$values->{requires}}) {
      next unless ($dist_ids->{$dist} and $mod_ids->{$module});
      $sth->execute($dist_ids->{$dist}, $mod_ids->{$module}, 
                    $values->{requires}->{$module})
        or do {
          $self->db_error($sth);
          return;
        };
    }
  }
  $dbh->commit or do {
    $self->db_error($sth);
        return;
  };
  $sth->finish();
  return 1;
}

sub update {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  return unless my $mod_obj = $self->{obj}->{mods};
  my $dists = $dist_obj->{info};
  my $dist_ids = $dist_obj->{ids};
  my $mod_ids = $mod_obj->{ids};
  my $data = $dist_obj->{update};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No req data to update};
    return;
  }
  unless ($dist_ids and $mod_ids and $dists) {
    $self->{error_msg} = q{No author index data available};
    return;
  }
  
  my $sql = $self->sql_delete('dist_id');
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $distname(keys %$data) {
      next unless $data->{$distname};
      $sth->execute($data->{$distname}) or do {
          $self->db_error($sth);
          return;
      };
  }
  $sth->finish();
  
  my @fields = qw(dist_id mod_id req_vers);
  $sql = $self->sql_insert(\@fields);
  $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $dist (keys %$data) {
    my $values = $dists->{$dist};
    next unless defined $values->{requires};
    foreach my $module (keys %{$values->{requires}}) {
      next unless ($dist_ids->{$dist} and $mod_ids->{$module});
      $sth->execute($dist_ids->{$dist}, $mod_ids->{$module}, 
                    $values->{requires}->{$module})
        or do {
          $self->db_error($sth);
          return;
        };
    }
  }
  $dbh->commit or do {
    $self->db_error($sth);
    return;
  };
  $sth->finish();
  return 1;
}

sub delete {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $data = $dist_obj->{delete};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No req data to delete};
    return;
  }
  
  my $sql = $self->sql_delete('dist_id');
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $distname(keys %$data) {
    $sth->execute($data->{$distname}) or do {
      $self->db_error($sth);
      return;
    };
  }
  $sth->finish();
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

package CPAN::Search::Lite::Populate::ppms;
use base qw(CPAN::Search::Lite::Populate);

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
              obj => {},
              error_msg => '',
              info_msg => '',
             };
  bless $self, $class;
}

sub insert {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  return unless my $dist_obj = $self->{obj}->{dists};
  my $dist_ids = $dist_obj->{ids};
  my $ppms = $self->{info};
  my $data = $setup ? $ppms : $self->{insert};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No ppm data to insert};
    return;
  }
  unless ($ppms and $dist_ids) {
      $self->{error_msg} = q{No ppm index data available};
      return;
  }
  
  my @fields = qw(dist_id rep_id ppm_vers);
  my $sql = $self->sql_insert(\@fields);
  my $sth = $dbh->prepare($sql) or do {
    $self->db_error();
    return;
  };
  foreach my $rep_id (keys %$data) {
      my $values = $data->{$rep_id};
      next unless $self->has_data($values);
      foreach my $package (keys %{$values}) {
          $sth->execute($dist_ids->{$package}, 
                        $rep_id, 
                        $values->{$package}->{version})
              or do {
                  $self->db_error($sth);
                  return;
              };
      }
  }
  $dbh->commit or do {
    $self->db_error($sth);
    return;
  };
  $sth->finish();
  return 1;
}

sub update {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  my $data = $self->{update};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No ppm data to update};
    return;
  }
  
  foreach my $rep_id (keys %$data) {
    my $values = $data->{$rep_id};
    next unless $self->has_data($values);
    foreach my $package (keys %{$values}) {
      print "Updating $package for rep_id=$rep_id\n";
      my $dist_id = $values->{$package}->{dist_id};
      my $ppm_vers = $values->{$package}->{ppm_vers};
      next unless ($dist_id and $rep_id);
      my $sql = q{UPDATE LOW_PRIORITY } .
        q{ ppms SET ppm_vers = ? } .
          qq{ WHERE dist_id = $dist_id } .
            qq { AND rep_id = $rep_id };
      my $sth = $dbh->prepare($sql) or do {
        $self->db_error();
        return;
      };
      $sth->execute($ppm_vers) or do {
        $self->db_error($sth);
        return;
      };
      $sth->finish;
    }
  }
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

sub delete {
  my $self = shift;
  unless ($dbh) {
    $self->{error_msg} = q{No db handle available};
    return;
  }
  my $data = $self->{delete};
  unless ($self->has_data($data)) {
    $self->{info_msg} = q{No ppm data to delete};
    return;
  }
  foreach my $id (keys %$data) {
      next unless $id;
      my $values = $data->{$id};
      my $sql = $self->sql_delete('dist_id', $id);
      my $sth = $dbh->prepare($sql) or do {
          $self->db_error();
          return;
      };
      foreach my $package (keys %{$values}) {
          print "Deleting $package from rep_id=$id\n";
          $sth->execute($values->{$package}) or do {
              $self->db_error($sth);
              return;
          };
      }
      $sth->finish();
  }
  $dbh->commit or do {
    $self->db_error();
    return;
  };
  return 1;
}

package CPAN::Search::Lite::Populate;

sub sql_insert {
    my ($self, $fields) = @_;
    my $flds = join ',', @$fields;
    my $vals = join ',', map '?', @$fields; 
    my $sql = q{INSERT LOW_PRIORITY INTO } . $obj2tbl{ref($self)} .
        qq{ ($flds) VALUES ($vals) };
    return $sql;
}

sub sql_update {
    my ($self, $fields, $id, $rep_id) = @_;
    my $table = $obj2tbl{ref($self)};
    my $set = join ',', map "$_=?", @$fields;
    my $sql = q{UPDATE LOW_PRIORITY } .
        qq{ $table SET $set } .
        qq{ WHERE $table_id->{$table} = $id };
    $sql .= qq { AND rep_id = $rep_id } if ($rep_id);
    return $sql;
}

sub sql_delete {
    my ($self, $id, $rep_id) = @_;
    my $sql = q{DELETE LOW_PRIORITY } .
        q {FROM } . $obj2tbl{ref($self)} .
            qq { WHERE $id = ? };
    $sql .= qq { AND rep_id = $rep_id } if ($rep_id);
    return $sql;
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

sub DESTROY {
    $dbh->disconnect;
}

1;

__END__

=head1 NAME

CPAN::Search::Lite::Populate - create and populate database tables

=head1 DESCRIPTION

This module is responsible for creating the tables
(if C<setup> is passed as an option) and then for 
inserting, updating, or deleting (as appropriate) the
relevant information from the indices of
I<CPAN::Search::Lite::Info> and I<CPAN::Search::Lite::PPM> and the
state information from I<CPAN::Search::Lite::State>. It does
this through the C<insert>, C<update>, and C<delete>
methods associated with each table.

Note that the tables are created with the C<setup> argument
passed into the C<new> method when creating the
C<CPAN::Search::Lite::Index> object; existing tables will be
dropped.

=head1 TABLES

The tables used are described below.

=head2 mods

This table contains module information, and is created as

  mod_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT
  dist_id SMALLINT UNSIGNED NOT NULL
  mod_name VARCHAR(50) NOT NULL
  mod_abs TINYTEXT
  doc bool
  mod_vers VARCHAR(10)
  dslip CHAR(5)
  chapterid TINYINT(2) UNSIGNED
  PRIMARY KEY (mod_id)
  FULLTEXT (mod_abs)
  KEY (dist_id)
  KEY (mod_name(50))

=over 3

=item * mod_id

This is the primary (unique) key of the table.

=item * dist_id

This key corresponds to the id of the associated distribution
in the C<dists> table.

=item * mod_name

This is the module's name.

=item * mod_abs

This is a description, if available, of the module.

=item * doc

This value, if true, signifies that documentation for the
module exists, and is located, eg, in F<dist_name/Foo/Bar.pm>
for a module C<Foo::Bar> in the C<dist_name> distribution.

=item * mod_vers

This value, if present, gives the version of the module.

=item * dslip

This is a 5 character string expressing the dslip
(development, support, language, interface, public
license) information.

=item * chapterid

This number corresponds to the chapter id of the module,
if present.

=back

=head2 dists

This table contains distribution information, and is created as

  dist_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT
  stamp TIMESTAMP(8)
  auth_id SMALLINT UNSIGNED NOT NULL
  dist_name VARCHAR(60) NOT NULL
  dist_file VARCHAR(90) NOT NULL
  dist_vers VARCHAR(20)
  dist_abs TINYTEXT
  size MEDIUMINT UNSIGNED NOT NULL
  birth DATE NOT NULL
  readme bool
  changes bool
  meta bool
  install bool
  PRIMARY KEY (dist_id)
  FULLTEXT (dist_abs)
  KEY (auth_id)
  KEY (dist_name(60))

=over 3

=item * dist_id

This is the primary (unique) key of the table.

=item * stamp

This is a timestamp for the table indicating when the
entry was either inserted or last updated.

=item * auth_id

This corresponds to the CPAN author id of the distribution
in the C<auths> table.

=item * dist_name

This corresponds to the distribution name (eg, for
F<My-Distname-0.22.tar.gz>, C<dist_name> will be C<My-Distname>).

=item * dist_file

This corresponds to the CPAN file name.

=item * dist_vers

This is the version of the CPAN file (eg, for
F<My-Distname-0.22.tar.gz>, C<dist_vers> will be C<0.22>).

=item * dist_abs

This is a description of the distribtion. If not directly
supplied, the description for, eg, C<Foo::Bar>, if present, will 
be used for the C<Foo-Bar> distribution.

=item * size

This corresponds to the size of the distribution, in bytes.

=item * birth

This corresponds to the last modified time
of the distribution, in the form I<YYYY/MM/DD>.

=item * readme

This value, if true, indicates that a F<README> file for
the distribution is available.

=item * changes

This value, if true, indicates that a F<Changes> file for
the distribution is available.

=item * meta

This value, if true, indicates that a F<META.yml> file for
the distribution is available.

=item * install

This value, if true, indicates that an F<INSTALL> file for
the distribution is available.

=back

=head2 auths

This table contains CPAN author information, and is created as

  auth_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT
  cpanid VARCHAR(20) NOT NULL
  fullname VARCHAR(40) NOT NULL
  email TINYTEXT
  PRIMARY KEY (auth_id)
  FULLTEXT (fullname)
  KEY (cpanid(20))

=over 3

=item * auth_id

This is the primary (unique) key of the table.

=item * cpanid

This gives the CPAN author id.

=item * fullname

This is the full name of the author.

=item * email

This is the supplied email address of the author.

=back

=head2 chaps

This table contains chapter information associated with
distributions. PAUSE allows one, when registering modules,
to associate a chapter id with each module (see the C<mods>
table). This information is used here to associate chapters
(and subchapters) with distributions in the following manner.
Suppose a distribution C<Quantum-Theory> contains a module
C<Beta::Decay> with chapter id C<55>, and
another module C<Laser> with chapter id C<87>. The
C<Quantum-Theory> distribution will then have two
entries in this table - C<chapterid> of I<55> and
C<subchapter> of I<Beta>, and C<chapterid> of I<87> and
C<subchapter> of I<Laser>.

The table is created as follows.

  chapterid TINYINT UNSIGNED NOT NULL
  dist_id SMALLINT UNSIGNED NOT NULL
  subchapter TINYTEXT
  KEY (dist_id)

=over 3

=item * chapterid

This number corresponds to the chapter id.

=item * dist_id

This is the id corresponding to the distribution in the
C<dists> table.

=item * subchapter

This is the subchapter.

=back

=head2 reqs

This table lists the prerequisites of the distribution,
as found in the F<META.yml> file (if supplied - note that
only relatively recent versions of C<ExtUtils::MakeMaker>
or C<Module::Build> generate this file when making a
distribution). The table is created as

  dist_id SMALLINT UNSIGNED NOT NULL
  mod_id SMALLINT UNSIGNED NOT NULL
  req_vers VARCHAR(10)
  KEY (dist_id)

=over 3

=item * dist_id

This corresponds to the id of the distribution in the
C<dists> table.

=item * mod_id

This corresponds to the id of the prerequisite module
in the C<mods> table.

=item * req_vers

This is the version of the prerequisite module, if specified.

=back

=head2 ppms

This table contains information on Win32 ppm
packages available in the repositories specified
in C<$repositories> of L<CPAN::Search::Lite::Util>.
The table is created as

  dist_id SMALLINT UNSIGNED NOT NULL
  rep_id TINYINT(2) UNSIGNED NOT NULL
  ppm_vers VARCHAR(20)
  KEY (dist_id)

=over 3

=item * dist_id

This is the id of the distribution appearing in the
C<dists> table.

=item * rep_id

This is the id of the repository appearing in the
C<$repositories> data structure.

=item * ppm_vers

This is the version of the ppm package found.

=back

=head1 SEE ALSO

L<CPAN::Search::Lite::Index>

=cut
