#!perl
package CPAN::Search::Lite::Extract;
use strict;
use warnings;
use Archive::Zip;
use Archive::Tar;
use Pod::Select;
use File::Temp qw(tempfile);
use File::Basename;
use File::Path;
use File::Spec::Functions qw(splitdir catfile catdir splitpath);
use YAML qw(LoadFile);
use File::Copy;
use Pod::Html;
use HTML::TextToHTML;

my $ext = qr/\.(tar\.gz|tar\.Z|tgz|zip)$/;
my $DEBUG = 1;
my $setup;

sub new {
    my ($class, %args) = @_;
    foreach (qw(CPAN pod_root html_root) ) {
        die "Must supply a '$_' argument" unless $args{$_};
    }

    $setup = $args{setup};
    my $index = $args{index};
    my %info;
    foreach my $table (qw(dists mods auths)) {
        my $obj = $index->{$table};
        die "Please supply a CPAN::Search::Lite::Index::$table object"
            unless ($obj and ref($obj) eq "CPAN::Search::Lite::Index::$table");
        $info{$table} = $obj->{info};
    }    
    my $state = $args{state};
    unless ($setup) {
        die "Please supply a CPAN::Search::Lite::State object"
            unless ($state and ref($state) eq 'CPAN::Search::Lite::State');
    }

    my $self = {pod_root => $args{pod_root},
                html_root => $args{html_root},
                CPAN => $args{CPAN},
                props => {},
                %info,
                state => $state,
                css => $args{css},
                up_img => $args{up_img},
            };
    bless $self, $class;
}

sub extract {
    my $self = shift;
    my $props = $self->{props};
    my $dists = $self->{dists};
    my $mods = $self->{mods};
    my $CPAN = $self->{CPAN};
    my $pod_root = $self->{pod_root};
    my $pat = qr!^[^/]+/change|^[^/]+/install|\.pod$|\.pm$!i;
    my @dist_names = ();
    if ($setup) {
         @dist_names = keys %$dists;
    }
    else {
        my $dist_obj = $self->{state}->{obj}->{dists};
        for my $type (qw(insert update)) {
            my $data = $dist_obj->{$type};
            next unless $self->has_data($data);
            push @dist_names, keys %{$data};
        }
    }
    foreach my $dist (@dist_names) {
        my $docs;
        my $values = $dists->{$dist};
        my $version = $values->{version};
        my $cpanid = $values->{cpanid};
        my $filename = $values->{filename};
        unless ($filename and $version and $cpanid) {
            warn "No distribution/version/cpanid info for $dist";
            next;
        }
        my ($archive, @files);
        my $download = $self->download($cpanid, $filename);
        print "Extracting files within $download ...\n";

        my $fulldist = catfile $CPAN, $download;

        (my $yaml = $fulldist) =~ s/$ext/.meta/;
        if (-f $yaml) {
            eval {$props->{$dist} = LoadFile($yaml);};
            warn $@ if $@;
        }
        if ($props->{$dist} and $props->{$dist}->{requires}) {
            $dists->{$dist}->{requires} = $props->{$dist}->{requires};
        }
        if ($props->{$dist} and $props->{$dist}->{abstract}) {
            $dists->{$dist}->{description} = $props->{$dist}->{abstract};
        }

        my $dist_root = catdir $pod_root, $dist;
        $docs->{dist_root} = $dist_root;
        if (-d $dist_root) {
            rmtree($dist_root, $DEBUG, 1) or do {
                warn "Cannot rmtree $dist_root: $!";
                next;
            };
        }
        mkpath($dist_root, $DEBUG, 0755) or do {
            warn "Cannot mkdir $dist_root: $!";
            next;
        };

        (my $cpan_readme = $fulldist) =~ s/$ext/.readme/;
        if (-f $cpan_readme) {
            my $readme = catfile $dist_root, 'README';
            copy($cpan_readme, $readme) or do {
                warn "Cannot copy $cpan_readme to $readme: $!";
                next;
            };
            my $contains_pod;
            open(my $fh, $readme) or do {
                warn "Cannot open $cpan_readme: $!";
                next;
            };
            while (<$fh>) {
                if (/^head1/) {
                    $contains_pod = 1;
                    last;
                }
            }
            close $fh;
            if ($contains_pod) {
                rename ($readme, $readme . '.pod') or do {
                    warn "Cannot rename $readme: $!";
                    next;
                };
                $docs->{files}->{'README.pod'} = {name => "$dist README"};
            }
            else {
                $docs->{files}->{'README'} = {name => "$dist README"};
            }
            $dists->{$dist}->{readme} = 1;
        }
        
        if (-f $yaml) {
            my $meta = catfile $dist_root, 'META.yml';
            copy($yaml, $meta) or do {
                warn "Cannot copy $yaml to $meta: $!";
                next;
            };
            $dists->{$dist}->{meta} = 1;
            $docs->{files}->{'META.yml'} = {name => "$dist META"};
       }
            
        my $is_zip = ($filename =~ /\.zip$/);
        if ($is_zip) {
            $archive = Archive::Zip->new($fulldist) or do {
                warn "Cannot open $fulldist: $!";
                next;
            };
            @files = grep {m!$pat!} $archive->memberNames() or do { 
                warn "Cannot list files for $fulldist: $!";
                next;
            };
        }
        else {
            $archive = Archive::Tar->new($fulldist, 1) or do {
                warn "Cannot open $fulldist: $!";
                next;
            };
            @files = grep {m!$pat!} $archive->list_files() or do { 
                warn "Cannot list files for $fulldist: $!";
                next;
            };
        }
        
        unless ($files[0] =~ /\Q$dist/) {
            warn "Strange unpacked directory structure for $dist";
            # next;
        }

        foreach my $file (@files) {
            print "Extracting $file ...\n";
            my $content = ($is_zip ? 
                           $archive->contents($file) : 
                           $archive->get_content($file) ) or do {
                               warn "Cannot get content of $file: $!";
                               next;
                           };
            $content =~ s!\r!!g;
            my $is_pod = ($file =~ /\.(pod|pm)$/);
            next if ($is_pod and $content !~ /^=head/m);
            my ($module, $description);
            ($module, $description) = $self->abstract($content) if $is_pod;
            my $rel_root;
            if ($module and $dists->{$dist}->{modules}->{$module}) {
                my @dirs = split /::/, $module;
                pop @dirs if @dirs >= 1;
                $rel_root = catdir(@dirs);
            }
            my $abs_root = $rel_root ?
                catdir $dist_root, $rel_root : $dist_root;
            unless (-d $abs_root) {
                mkpath($abs_root, $DEBUG, 0755) or do {
                    warn "Cannot mkdir $abs_root: $!";
                    next;
                };
            }
            
            my $doc = basename($file);
            if ($doc =~ /change/i and $doc !~ /\.pm$/) {
                $doc = $is_pod ? 'Changes.pod' : 'Changes';
                $description = "$dist Changes";
                $docs->{files}->{$doc} = {name => $description};
                $dists->{$dist}->{changes} = 1;
            }
            if ($doc =~ /install/i and $doc !~ /\.pm$/) {
                $doc = $is_pod ? 'INSTALL.pod' : 'INSTALL';
                $description = "$dist INSTALL";
                $docs->{files}->{$doc} = {name => $description};
                $dists->{$dist}->{install} = 1;
            }
            my $rel_file = $rel_root ?
                catfile $rel_root, $doc : $doc; 
            my $abs_file = catfile $abs_root, $doc;
            if ($is_pod) {
                my ($tmpfh, $tmpfn) = tempfile(UNLINK => 1) or do {
                    warn "Cannot create tempfile: $!";
                    next;
                };
                print $tmpfh $content;
                seek($tmpfh,0,1);
                my $parser = Pod::Select->new();
                $parser->parse_from_file($tmpfn, $abs_file);
                close $tmpfh;
                my $name;
                if ($module) {
                    $name = $module;
                }
                else {
                    ($name = $doc) =~ s/\.(pm|pod)$//;
                }
                $docs->{files}->{$rel_file} = {name => $name, 
                                               desc => $description};
            }
            else {
                open(my $fh, '>', $abs_file) or do {
                    warn "Cannot write to $abs_file: $!";
                    next;
                };
                print $fh $content;
                close $fh;
            }
            if ($is_pod and $module) {
                if ($dists->{$dist}->{modules}->{$module}) {
                    $mods->{$module}->{description} = $description
                        if ($description and !$mods->{$module}->{description});
                    $mods->{$module}->{doc} = 1;
                }
                unless ($dists->{$dist}->{description} or ! $description) {
                    (my $trial_dist = $module) =~ s/::/-/g;
                    if ($trial_dist eq $dist) {
                        $dists->{$dist}->{description} = $description;
                    }
                    else {
                        foreach my $key ( qw(abstract_from version_from) ) {
                            next unless (my $key_file = $props->{$key});
                            if ($key_file =~ /\Q$rel_file/) {
                                $dists->{$dist}->{description} = $description;
                                last;
                            }
                        }
                    }
                }
            }
        }
        $self->make_html($dist, $docs);
    }
    $self->cleanup() unless $setup;
    return 1;
}

sub cleanup {
    my $self = shift;
    my $dist_obj = $self->{state}->{obj}->{'CPAN::Search::Lite::State::dists'};
    my $data = $dist_obj->{delete};
    return unless $self->has_data($data);
    my $dists = $self->{dists};
    my $pod_root = $self->{pod_root};
    my $html_root = $self->{html_root};
    foreach my $dist (keys %$data) {
        next unless defined $dist;
        my $values = $dists->{$dist};
        my $cpanid = $values->{cpanid};
        my $filename = $values->{filename};
        my $download = $self->download($cpanid, $filename);
        my $pod_dir = catdir $pod_root, $dist;
        my $html_dir = catdir $html_root, $dist;
        foreach my $dir ($pod_dir, $html_dir) {
            if (-d $dir) {
                rmtree($dir, $DEBUG, 1) or do {
                    warn "Cannot rmtree $dir: $!";
                    next;
                };
            }
        }
    }
    return 1;
}

sub abstract {
    my ($self, $content) = @_;
    my @lines = split /\n/, $content;
    my ($description, $module);
    my $inpod = 0;
    foreach (@lines) {
        $inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
        next if !$inpod;
        chomp;
        next unless /^\s*(\S+)\s+--?\s+(.*?)\s*$/;
        $module = $1;
        $description = $2;
        last;
    }
    
    my $has_mod = ($module and $module =~ /\w/);
    my $has_desc = ($description and $description =~ /\w/);
    $module =~ s/-/::/g if $has_mod;
    if ($has_mod and $has_desc) {
        return ($module, $description);
    }
    elsif ($has_mod) {
        return ($module, undef);
    }
    else {
        return;
    }
}

sub make_html {
    my ($self, $dist, $docs) = @_;
    my $in_root = $docs->{dist_root};
    my $out_root = catdir $self->{html_root}, $dist;
    my $css_file = $self->{css};
    my $back_link = '__top';
    my $up_img = $self->{up_img};
    if (-d $out_root) {
        rmtree($out_root, $DEBUG, 1) or do {
            warn "Cannot rmtree $out_root: $!";
            return;
        };
    }
    mkpath($out_root, $DEBUG, 0755) or do {
        warn "Cannot mkdir $out_root: $!";
        return;
    };
    open(my $fh, '>', "$out_root/index.html") or do {
        warn "Could not open $out_root/index.html: $!";
        return;
    };
    print $fh <<"END";
<HTML>
<HEAD>
<TITLE>$dist documentation</TITLE>
END
    if ($css_file) {
        print $fh <<"END";
<LINK rel="stylesheet" type="text/css" href="../$css_file"></LINK>
END
    }
    print $fh <<"END";
</HEAD>
<BODY>
<H2>$dist documentation</H2>
<UL>
END

    foreach my $file (sort keys %{$docs->{files}}) {
        my $infile = catfile $in_root, $file;
        next unless (-e $infile);
        my $is_text = ($file eq 'README' or $file eq 'Changes'
                      or $file eq 'INSTALL' or $file eq 'META.yml');
        my ($outfile, $html_file);
        if ($is_text) {
            $html_file = $file eq 'META.yml' ? 'META.html' : $file . '.html';
        }
        else {
            ($html_file = $file) =~ s!\.(pod|pm)$!.html!; 
        }
        $outfile = catfile $out_root, $html_file;
        my $abs_dir = dirname($outfile);
        unless (-d $abs_dir){
            mkpath($abs_dir, 1, 0755) or do {
                warn "Couldn't mkdir $abs_dir: $!";
                return;
            };
        }
        my $rel_dir = dirname($file);
        my $root = $rel_dir eq '.' ? '../' :
            ('../' x (1 + scalar splitdir($rel_dir)));
        my $css = $css_file ? $root . $css_file : '';
        print "Creating $outfile\n";
        my $title;
        if ($is_text) {
            my $c = HTML::TextToHTML->new();
            my %args;
            $title = "$dist - $file";
            $args{infile} = [$infile];
            $args{outfile} = $outfile;
            $args{title} = $title;
            $args{style_url} = $css if $css;
            eval{ $c->txt2html(%args); };
            warn $@ if $@;
        }
        else {
            my $html_root = $root . $dist;
            my $name = $docs->{files}->{$file}->{name};
            my $desc = $docs->{files}->{$file}->{desc};
            $title = $desc ? "$name - $desc" : $name;
            my @opts = (
                        '--header',
                        '--flush',
                        "--backlink=$back_link",
                        "--title=$title",
                        "--infile=$infile",
                        "--outfile=$outfile",
                        "--podroot=$in_root",
                        "--htmlroot=$html_root",
                        "--quiet",
                        );
            push @opts, "--css=$css" if $css;
            eval{ pod2html(@opts); };
            warn $@ if $@;
        }
        insert_up(file => $outfile, root => $root, 
                  dist => $dist, back_link => $back_link, up_img => $up_img);
        $html_file = unix_path($html_file);
        print $fh qq{<LI><A HREF="$html_file">$title</A></LI>\n};
    }
    my $up = qq{\n<hr />Back to <a href="../">home page</a>.<hr />\n};
    print $fh qq{</UL>$up</BODY></HTML>\n};
    close $fh;
}

sub insert_up {
    my (%args) = @_;
    my $file = $args{file};
    my $root = $args{root};
    my $dist = $args{dist};
    my $up_img = $args{up_img};
    my $back_link = $args{back_link};
    my $copy = $file . '.orig';
    rename ($file, $copy) or do {
        warn "Could not rename $file to $copy: $!";
        return;
    };
    open(my $old, $copy) or do {
        warn "Could not open $copy for reading: $!";
        return;
    };
    open(my $new, '>', $file) or do {
        warn "Could not open $file for writing: $!";
        return;
    };
    my $up = qq{\n<hr />Back to <a href="$root$dist/">$dist documentation</a>.<hr />\n};
    my $up_link = $up_img ? 
        qq{<img src="$root$up_img" alt="$back_link" border="0" />} : '';
    while (<$old>) {
        s!^(<body.*)!$1$up!;
        s!^(</body.*)!$up$1!;
        s!<small>$back_link</small>!$up_link!i if $up_link;
        print $new $_;
    }
    close $old;
    close $new;
    unlink $copy or do {
        warn "Could not unlink $copy: $!";
        return;
    };
    return 1;
}

sub unix_path {
    my $file = shift;
    return $file unless $^O =~ /Win32/;
    my @d = splitpath($file);
    return File::Spec::Unix->catfile( splitdir($d[1]), $d[2]);
}

sub has_data {
  my ($self, $data) = @_;
  return unless (defined $data and ref($data) eq 'HASH');
  return (scalar keys %$data > 0) ? 1 : 0;
}

sub download {
    my ($self, $cpanid, $dist_file) = @_;
    (my $fullid = $cpanid) =~ s!^(\w)(\w)(.*)!$1/$1$2/$1$2$3!;
    my $download = catfile 'authors/id', $fullid, $dist_file;
    return $download;
}

1;

__END__

=head1 NAME

CPAN::Search::Lite::Extract - extract files from CPAN distributions

=head1 DESCRIPTION

This module extracts the pod sections from various files in a
CPAN distribution, and places them in the location specified by
C<pod_root> in the main configuration file, underneath a
subdirectory denoting the distribution's name. Additionally,
it copies to this subdirectory the F<README> and F<META.yml>
files of the distribution, if they exist. Information on the
prerequisites of the package, as well as the abstract, if not
known at this point and if available, is extracted from
F<META.yml> and stored for future use. It also runs
C<pod2html> on all the pod files, placing the results underneath
C<html_root>.

It is assumed here that a local CPAN mirror exists; the C<no_mirror>
configuration option will cause this extraction to be skipped.

=head1 SEE ALSO

L<CPAN::Search::Lite::Index>

=cut

