package CPAN::Search::Lite::Populate;
use strict;
use warnings;
no warnings qw(redefine);
use DBI;
use CPAN::Search::Lite::Util qw($table_id);
use File::Find;
use File::Basename;
use File::Spec::Functions;
use File::Path;
use AI::Categorizer;
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Document;
use AI::Categorizer::KnowledgeSet;
use Lingua::StopWords;

our ($dbh);

my ($setup, $no_ppm);
my $DEBUG = 1;

my %tbl2obj;
$tbl2obj{$_} = __PACKAGE__ . '::' . $_ 
    for (qw(dists mods auths ppms chaps reqs));
my %obj2tbl  = reverse %tbl2obj;

sub new {
  my ($class, %args) = @_;
  
  foreach (qw(db user passwd) ) {
    die "Must supply a '$_' argument" unless defined $args{$_};
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
  my $pod_root = $args{pod_root};
  my $cat_threshold = $args{cat_threshold} || 0.998;
  my $no_cat = $args{no_cat};

  unless ($no_mirror) {
      die "Please supply the html root" unless $html_root;
      die "Please supply the pod root" unless $pod_root;
  }
  my $self = {index => $index,
              state => $state,
              obj => {},
              no_mirror => $no_mirror,
              html_root => $html_root,
              pod_root => $pod_root,
              cat_threshold => $cat_threshold,
              no_cat => $no_cat,
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

    my $pack = __PACKAGE__ . '::cat';
    my $obj = $pack->new(cat_threshold => $self->{cat_threshold});
    foreach (qw(dists auths mods)) {
        $obj->{obj}->{$_} = $self->{obj}->{$_};
    }
    $self->{obj}->{cat} = $obj;

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

    unless ($self->{no_cat}) {
        my $cat = $self->{obj}->{cat};
        unless ($cat->categorize()) {
            if (my $error = $cat->{error_msg}) {
                print "Fatal error from ", ref($cat), ": ", $error, $/;
                return;
            }
            else {
                my $info = $cat->{info_msg};
                print "Info from ", ref($cat), ": ", $info, $/;
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
                                mod_name VARCHAR(70) NOT NULL,
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
    my $pod_root = $self->{pod_root};

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
    my (@dist_roots, @goners, $data);
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
        $data = $dist_obj->{delete};
        if ($self->has_data($data)) {
            push @goners, keys %$data;
        }
    }

    if (@goners) {
        foreach my $dist_root (@goners) {
            my $html_path = catdir $html_root, $dist_root;
            if (-d $html_path) {
                print "Removing $html_path\n";
                rmtree($html_path, $DEBUG, 1)
                    or warn "Cannot rmtree $html_path: $!";
            }
            my $pod_path = catdir $pod_root, $dist_root;
            if (-d $pod_path) {
                print "Removing $pod_path\n";
                rmtree($pod_path, $DEBUG, 1)
                    or warn "Cannot rmtree $pod_path: $!";
            }
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

package CPAN::Search::Lite::Populate::cat;
use base qw(CPAN::Search::Lite::Populate);

my %features = (content_weights => {
                                    subject => 2,
                                    body => 1,
                                   },
                stopwords => Lingua::StopWords::getStopWords('en'),
                stemming => 'porter',
               );

my $chaps = {
  2 => {subject => q{Perl Core Modules},
        body => q{Perl Core Modules},
       },
  3 => {subject => q{Development Support},
        body => q{Development Support},
       },
  4 => {subject => q{Operating System Interfaces},
        body => q{Operating System Interfaces},
       },
  5 => {subject => q{Networking Devices IPC},
        body => q{Network Devices IPC FTP Socket},
       },
  6 => {subject => q{Data Type Utilities},
        body => q{Data Type Utilities Date Time Math Tie List Tree Class Algorithm Sort Statistics},
       },
  7 => {subject => q{Database Interfaces},
        body => q{Database Interfaces DBD DBI SQL},
       },
  8 => {subject => q{User Interfaces},
        body => q{User Interfaces Tk Term Curses Dialogue Log},
       },
  9 => {subject => q{Language Interfaces},
        body => q{Language Interfaces},
       },
  10 => {subject => q{File Names Systems Locking},
         body => q{File Name System Locking Directory Dir Stat cwd},
        },
  11 => {subject => q{String Lang Text Proc},
         body => q{String Language Text Processing XML Parse},
        },
  12 => {subject => q{Opt Arg Param Proc},
         body => q{Option Argument Parameters Processing Argv Config Getopt},
        },
  13 => {subject => q{Internationalization Locale},
         body => q{Internationalization Locale Unicode I18N},
        },
  14 => {subject => q{Security and Encryption},
         body => q{Security Encryption Authentication Authen Crypt Digest PGP Des},
        },
  15 => {subject => q{World Wide Web HTML HTTP CGI},
         body => q{World Wide Web HTML HTTP CGI WWW Apache MIME Kwiki URI URL},
        },
  16 => {subject => q{Server and Daemon Utilities},
         body => q{Server Daemon Utilties Event},
        },
  17 => {subject => q{Archiving and Compression},
         body => q{Archive Compress File tar gzip gz zip bzip},
        },
  18 => {subject => q{Images Pixmaps Bitmaps},
         body => q{Image Pixmap Bitmap Chart Graph Graphic},
        },
  19 => {subject => q{Mail and Usenet News},
         body => q{Mail Usenet News Sendmail NNTP SMTP IMAP POP3 MIME},
        },
  20 => {subject => q{Control Flow Utilities},
         body => q{Control Flow Utilities callback exception hook},
        },
  21 => {subject => q{File Handle Input Output},
         body => q{File Handle Input Output Dir Directory Log IO},
        },
  22 => {subject => q{Microsoft Windows Modules},
         body => q{Microsoft Windows Modules Win32 Win32API},
        },
  23 => {subject => q{Miscellaneous Modules},
         body => q{Miscellaneous Modules},
        },
  24 => {subject => q{Commercial Software Interfaces},
         body => q{Commercial Software Interfaces},
        },
  99 => {subject => q{Not Yet In Modulelist},
         body => q{Not Yet In Modulelist},
        },
};

sub new {
  my ($class, %args) = @_;
  my $self = {
              obj => {},
              error_msg => '',
              info_msg => '',
              learner => {},
              missing => {},
              cat_threshold => $args{cat_threshold},
             };
  bless $self, $class;
}

sub categorize {
    my $self = shift;
    $self->train() or return;
    $self->missing() or return;
    $self->insert_and_update() or return;
    return 1;
}

sub train {
    my $self = shift;
    return unless my $mod_obj = $self->{obj}->{mods};
    my $mod_info = $mod_obj->{info};
    my ($docs);

    foreach my $mod_name (%$mod_info) {
        (my $subject = $mod_name) =~ s{::}{ }g;
        my $body = '';
        my $abs = $mod_info->{$mod_name}->{description};
        ($body = $abs) =~ s{::}{ }g if $abs;
        my $chapterid = $mod_info->{$mod_name}->{chapterid};
        if ($chapterid) {
            $docs->{$mod_name} = {categories => [$chapterid],
                                  content => {subject => $subject,
                                              body => $body,
                                             },
                                 };
        }
    }

    foreach my $cat(keys %$chaps) {
        $docs->{$cat} = {categories => [$cat],
                         content => {subject => $chaps->{$cat}->{subject},
                                     body => $chaps->{$cat}->{body},
                                    },
                        };
    }
    my $c = 
        AI::Categorizer->new(
                             knowledge_set => 
                             AI::Categorizer::KnowledgeSet->new( name => 'CSL',
                                                               ),
                             verbose => 1,
                            );
    while (my ($name, $data) = each %$docs) {
        $c->knowledge_set->make_document(name => $name, %$data, %features);
    }

    my $learner = $c->learner;
    $learner->train;
    $self->{learner} = $learner;
    return 1;
}

sub missing {
    my $self = shift;
    unless ($dbh) {
        $self->{error_msg} = q{No db handle available};
        return;
    }
    return unless my $dist_obj = $self->{obj}->{dists};
    my $dist_info = $dist_obj->{info};
    my $missing_mods;
    my $sql = 'SELECT mod_name,mod_id,mod_abs,dist_id ' .
        ' FROM mods WHERE chapterid IS NULL ';
    my $sth = $dbh->prepare($sql) or do {
        $self->db_error();
        return;
    };
    $sth->execute() or do {
        $self->db_error($sth);
        return;
    };
    while (my ($mod_name,$mod_id,$mod_abs,$dist_id,$dist_name) = 
           $sth->fetchrow_array) {
        (my $subject = $mod_name) =~ s{::}{ }g;
        my $body = '';
        ($body = $mod_abs) =~ s{::}{ }g if $mod_abs;
        $missing_mods->{$mod_name} = {content => {subject => $subject,
                                                  body => $body,
                                                 },
                                      dist_id => $dist_id,
                                      mod_id => $mod_id,
                                 };
    }
    $sth->finish;

    my $cat_dists;
    $sql = 'SELECT chapterid,dist_id,subchapter FROM chaps';
    $sth = $dbh->prepare($sql) or do {
        $self->db_error();
        return;
    };
    $sth->execute() or do {
        $self->db_error($sth);
        return;
    };
    while (my ($chapterid, $dist_id, $subchapter) = $sth->fetchrow_array) {
        $cat_dists->{$dist_id}->{$chapterid}->{$subchapter}++;
    }
    $sth->finish;

    my $learner = $self->{learner};
    my $insert_mods;
    my $cat_threshold = $self->{cat_threshold};
    while (my ($name, $data) = each %$missing_mods) {
        my $doc = AI::Categorizer::Document->new( name => $name,
                                                  content => $data->{content},
                                                  %features);
        my $r = $learner->categorize($doc);
        my $b = $r->best_category;
        next unless ($b and $r->scores($b) > $cat_threshold);
        $insert_mods->{$name} = {chapterid => $b,
                                 dist_id => $data->{dist_id},
                                 mod_id => $data->{mod_id},
                                };
    }

    my $insert_dists;
    foreach my $dist (keys %$dist_info) {
        my $dist_id;
        foreach my $module (keys %{$dist_info->{$dist}->{modules}}) {
            my $chapterid = $insert_mods->{$module}->{chapterid};
            next unless defined $chapterid;
            $dist_id = $insert_mods->{$module}->{dist_id};
            next unless defined $dist_id;
            (my $subchapter = $module) =~ s!^([^:]+).*!$1!;
            next unless $subchapter;
            next if $cat_dists->{$dist_id}->{$chapterid}->{$subchapter};
            $insert_dists->{$dist_id}->{$chapterid}->{$subchapter}++;
        }
    }
    $self->{missing} = {mods => $insert_mods, dists => $insert_dists};
    return 1;
}

sub insert_and_update {
    my $self = shift;
    unless ($dbh) {
        $self->{error_msg} = q{No db handle available};
        return;
    }
    return unless my $mod_obj = $self->{obj}->{mods};
    my $mod_ids = $mod_obj->{ids};
    return unless my $dist_obj = $self->{obj}->{dists};
    my $dist_ids = $dist_obj->{ids};
    my %dist_names = reverse %$dist_ids;

    my $update = $self->{missing}->{mods};
    foreach my $module (keys %$update) {
        next unless $update->{$module};
        next unless (my $chapterid = $update->{$module}->{chapterid});
        next unless (my $mod_id = $update->{$module}->{mod_id});
        my $sql = q{UPDATE LOW_PRIORITY } .
            qq{ mods SET chapterid = $chapterid } .
                qq{ WHERE mod_id = $mod_id };
        my $sth = $dbh->prepare($sql) or do {
            $self->db_error();
            return;
        };
        $sth->execute() or do {
            $self->db_error($sth);
            return;
        };
        print "Inserting chapterid = $chapterid for $module\n";
        $sth->finish;
    }
    $dbh->commit or do {
        $self->db_error();
        return;
    };

    my $insert = $self->{missing}->{dists};
    my @fields = qw(chapterid dist_id subchapter);
    my $flds = join ',', @fields;
    my $vals = join ',', map '?', @fields;
    my $sql = q{INSERT LOW_PRIORITY INTO chaps } .
        qq{ ($flds) VALUES ($vals) };
    my $sth = $dbh->prepare($sql) or do {
        $self->db_error();
        return;
    };
    foreach my $dist_id (keys %$insert) {
        foreach my $chapterid (keys %{$insert->{$dist_id}} ) {
            foreach my $subchapter (keys %{$insert->{$dist_id}->{$chapterid}}) {
                $sth->execute($chapterid, $dist_id, $subchapter)
                    or do {
                        $self->db_error($sth);
                        return;
                    };
                print "Inserting chapter info: $chapterid/$subchapter for $dist_names{$dist_id}\n";
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

=head1 CATEGORIES

When uploading a module to PAUSE, there exists an option
to assign it to one of 24 broad categories. However, many
modules have not been assigned such a category, for one
reason or another. When populating the tables, the
I<AI::Categorizer> module is used to guess a possible
category for those modules that haven't been assigned one,
based on a training set based on the modules that have been
assigned a category (see <AI::Categorizer> for general
details). If this guess is above a configurable
threshold (see L<CPAN::Search::Lite::Index>, the guess is
accepted and subsequently inserted into the database, as
well as updating the categories associated with the
module's distribution.

=head1 SEE ALSO

L<CPAN::Search::Lite::Index>

=cut
