package TestCSL::lang;
use strict;
use warnings;
use Apache2;
use mod_perl 1.99_11;     # sanity check for a recent version
use Apache::Const -compile => qw(OK);
use CPAN::Search::Lite::Query;
our $chaps_desc = {};
our $pages = {};
use CPAN::Search::Lite::Lang qw(%langs load);
use TestCSL qw(lang_wanted);
use Apache::RequestRec;
use Apache::RequestIO;
use Apache::Log ();
use Apache::Request;

sub handler {
    my $r = shift;
    my $req = Apache::Request->new($r);
    my $data = $req->param('data');
    my $hash_element = $req->param('hash_element');
    my $wanted = $req->param('wanted');
    my $lang = lang_wanted($r);
    $CPAN::Search::Lite::Query::lang = $lang;
    unless ($pages->{$lang}) {
      my $rc = load(lang => $lang, pages => $pages,
                    chaps_desc => $chaps_desc);
      unless ($rc == 1) {
        $r->log_error($rc);
        return;
      }
    }
    if ($data eq 'chaps_desc') {
        $r->print($chaps_desc->{$lang}->{$wanted});
    }
    else {
        if ($hash_element) {
            $r->print($pages->{$lang}->{$hash_element}->{$wanted});
        }
        else {
            $r->print($pages->{$lang}->{$wanted});
        }
    }
    return Apache::OK;
}

1;
