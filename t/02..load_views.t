use strict;
use warnings;

use Test::More tests => 13;

use lib qw( t/lib );

require Class::DBI::NullPlugin;
require Class::DBI::MockPlugin;
require Class::DBI::NullBase;

BEGIN {
    use_ok('Class::DBI::ViewLoader');
}

unless (exists $Class::DBI::ViewLoader::handlers{'Mock'}) {
    # Module::Pluggable doesn't look in non-blib dirs under -Mblib
    require Class::DBI::ViewLoader::Mock;
    $Class::DBI::ViewLoader::handlers{'Mock'} = 'Class::DBI::ViewLoader::Mock';
}

my(@views, $loader);
my %args = (
	dsn => 'dbi:Mock:whatever',
	username => 'me',
	password => 'mypass',
    );

$loader = new Class::DBI::ViewLoader (
	%args,
	namespace => 'MyClass',
    );

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

$loader = new Class::DBI::ViewLoader (
	%args,
	namespace => 'ImportTest',
	import_classes => [qw/
	    Class::DBI::NullPlugin
	    Class::DBI::MockPlugin
	/]
    );

@views = $loader->load_views;
can_ok($views[0], 'null');
{
    no strict 'refs';
    ok(${$views[0].'::MockPluginLoaded'}, "non-Exporter import worked");
}

$loader->set_base_classes(qw(Class::DBI::NullBase))->set_namespace('BaseTest');

@views = $loader->load_views;
ok($views[0]->isa('Class::DBI::NullBase'), "$views[0] isa Class::DBI::NullBase");

__END__

vim: ft=perl
