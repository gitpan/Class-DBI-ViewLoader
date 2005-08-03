
# API tests for Class::DBI::ViewLoader 0.01

# Driver writers may want to copy this file into their distribution

use strict;
use warnings;

use Test::More;

use lib qw( t/lib );

our($class, @api_methods);

BEGIN {
    # Change this to the name of your driver
    my $plugin_name = 'Mock';


    $class = "Class::DBI::ViewLoader::$plugin_name";
    @api_methods = qw(
	    base_class
	    get_views
	    get_view_cols
	);

    plan tests => @api_methods + 2;

    use_ok($class);
}

ok($class->isa('Class::DBI::ViewLoader'));
for my $method (@api_methods) {
    can_ok($class, $method);
}

__END__

vim: ft=perl
