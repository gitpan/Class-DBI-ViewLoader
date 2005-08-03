use strict;
use warnings;

use Test::More tests => 17;

use lib qw( t/lib );

BEGIN {
    use_ok("Class::DBI::ViewLoader");
}

# Module::Pluggable doesn't look in non-blib dirs under -Mblib
unless (exists $Class::DBI::ViewLoader::handlers{'Bad'}) {
    require Class::DBI::ViewLoader::Bad;
    $Class::DBI::ViewLoader::handlers{'Bad'} = 'Class::DBI::ViewLoader::Bad';
}
unless (exists $Class::DBI::ViewLoader::handlers{'Mock'}) {
    require Class::DBI::ViewLoader::Mock;
    $Class::DBI::ViewLoader::handlers{'Mock'} = 'Class::DBI::ViewLoader::Mock';
}

eval { new Class::DBI::ViewLoader ( foo => 'bar' ) };
like($@, qr(^Unrecognised arguments in new\b), 'new with bad args dies');

eval { new Class::DBI::ViewLoader ( dsn => 'dbi:Foo:whatever' ) };
like($@, qr(^No handler for driver\b), "new with bad dsn dies");

# abstract method tests
my $loader = new Class::DBI::ViewLoader;
my @abstract = qw( base_class get_views get_view_cols );
for my $method (@abstract) {
    eval { $loader->$method };
    like($@, qr(^No handler loaded\b), "$method on object with no driver");
}

$loader->set_dsn('dbi:Bad:badbad');
for my $method (@abstract) {
    eval { $loader->$method };
    like($@, qr(^$method not overridden\b), "$method on object with bad driver");
}


{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };

    # set up a view with no columns:

    $Class::DBI::ViewLoader::Mock::db{empty} = [];
    $loader->set_dsn('dbi:Mock:');
    is($loader->load_views, 2, "load_views skipped empty view");
    is(@warnings, 1, "1 warning generated");
    like($warnings[0], qr(^No columns found\b), "\"No columns found\"");
    delete $Class::DBI::ViewLoader::Mock::db{empty};
}

eval { $loader->set_include({}) };
like($@, qr(^Regexp or string required), "set_include with hashref");

$Class::DBI::ViewLoader::handlers{'ReallyBad'} = 'ReallyBad';
eval { new Class::DBI::ViewLoader ( dsn => 'dbi:ReallyBad:reallybad' ) };
like($@, qr(^ReallyBad is not a [\w:]+ subclass\b), 'attempt to rebless to non-subclass');

{ 
    my $can_connect = 1;
    my($dbh, $l);
    local *DBI::connect;
    local *DBI::disconnect;
    local $SIG{__WARN__} = sub {};
    {
	no strict 'refs';
	*DBI::connect = sub {
	    if ($can_connect) {
		return bless {}, 'DBI';
	    }
	    else {
		return;
	    }
	};
	*DBI::disconnect = sub { 1 };
    }

    $l = Class::DBI::ViewLoader->new->set_dsn('dbi:Mock:');
    $dbh =
    eval { $l->_get_dbi_handle } or diag $@;
    isa_ok($dbh, 'DBI', "_get_dbi_handle");

    is($l->_get_dbi_handle, $dbh, 'second call returns same object');

    $l = Class::DBI::ViewLoader->new->set_dsn('dbi:Mock:');
    $can_connect = 0;
    eval { $l->_get_dbi_handle };
    like($@, qr(^Couldn't connect to database\b), "Simulated dbi failure");
}



__END__

vim: ft=perl
