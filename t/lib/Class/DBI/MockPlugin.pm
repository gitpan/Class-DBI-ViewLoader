package Class::DBI::MockPlugin;

use strict;
use warnings;

sub import {
    my $caller = caller();

    no strict 'refs';
    ${$caller.'::MockPluginLoaded'} = 1;
}

1;

__END__
