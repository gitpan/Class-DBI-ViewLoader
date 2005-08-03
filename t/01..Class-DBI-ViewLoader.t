use strict;
use warnings;

use Test::More tests => 38;

use lib qw( t/lib );

BEGIN {
    use_ok('Class::DBI::ViewLoader');
}

unless (exists $Class::DBI::ViewLoader::handlers{'Mock'}) {
    # Module::Pluggable doesn't look in non-blib dirs under -Mblib
    require Class::DBI::ViewLoader::Mock;
    $Class::DBI::ViewLoader::handlers{'Mock'} = 'Class::DBI::ViewLoader::Mock';
}

# simple args for new()
my %args = (
	dsn => 'dbi:Mock:whatever',
	username => 'me',
	password => 'mypass',
	namespace => 'MyClass',
    );

my $loader = new Class::DBI::ViewLoader (
	%args,
	include => '',
	exclude => '',
	options => {}
    );

isa_ok($loader, 'Class::DBI::ViewLoader', '$loader');
for my $field (keys %args) {
    my $meth = "get_$field";
    is($loader->$meth, $args{$field}, "\$loader->$meth");
}

$loader = new Class::DBI::ViewLoader;
for my $field (keys %args) {
    my $setter = "set_$field";
    my $getter = "get_$field";
    is($loader->$setter($args{$field}), $loader, "$setter returns the object");
    is($loader->$getter, $args{$field},          "$getter returns the value");
}

# non-simple fields:

my $current_opts = $loader->get_options;
$current_opts->{'RaiseError'} = 1;
is($loader->get_options->{'RaiseError'}, 1, 'get_options on new object returns active hashref');
my $opt = { RaiseError => 1 };
is($loader->set_options($opt), $loader, "set_options returns the object");
is($loader->set_options(%$opt), $loader, "set_options works with a raw hash");
my $ref = $loader->get_options;
is($ref->{RaiseError}, 1, "get_options returns a reference");
$ref->{AutoCommit} = 1;
is($loader->get_options->{AutoCommit}, 1, "Changing the reference changes the object");

# regex field tests
for my $regex_type qw(include exclude) {
    my $setter = "set_$regex_type";
    my $getter = "get_$regex_type";
    my $re = '^te(?:st|mp)_';
    is($loader->$setter($re), $loader, "$setter returns the object");
    is($loader->$getter, qr($re), "$getter returns a regex"); 
    is($loader->$setter(), $loader, "$setter with no args succeeds");
    is($loader->$getter, undef, "now $getter returns undef");
}

my @ns;
$loader = new Class::DBI::ViewLoader;
@ns = $loader->get_namespace;
is(@ns, 0, 'get_namespace without a namespace returns empty list');
$loader->set_namespace('');
@ns = $loader->get_namespace;
is(@ns, 0, 'get_namespace with a \'\' namespace returns empty list');

$loader = new Class::DBI::ViewLoader %args;

my(@views);
@views = $loader->load_views;
is(@views, 2, 'Loaded 2 views');
is($views[0], 'MyClass::TestView', 'created class MyClass::TestView');
is($views[1], 'MyClass::ViewTwo',  'created class MyClass::TestView');

# isa_ok doesn't work on non-refs
ok($views[0]->isa('Class::DBI::Mock'), "$views[0] isa Class::DBI::Mock");
ok($views[1]->isa('Class::DBI::Mock'), "$views[1] isa Class::DBI::Mock");

$loader->set_exclude(qr(^test_));
@views = $loader->load_views;
is(@views, 1, 'load_views with exclude rule');
is($views[0], 'MyClass::ViewTwo', '  returns as expected');
$loader->set_exclude();


$loader->set_include(qr(^test_));
@views = $loader->load_views;
is(@views, 1, 'load_views with include rule');
is($views[0], 'MyClass::TestView', '  returns as expected');
$loader->set_include();

__END__

vim: ft=perl
