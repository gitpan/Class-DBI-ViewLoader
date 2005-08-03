package Class::DBI::ViewLoader;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Class::DBI::ViewLoader - Load views from database tables as Class::DBI objects

=head1 SYNOPSIS

    use Class::DBI::ViewLoader;

    # set up loader object
    $loader = new Class::DBI::ViewLoader (
	    dsn => 'dbi:Pg:dbname=mydb',
	    username => 'me',
	    password => 'mypasswd',
	    options => {
		RaiseError => 1,
		AutoCommit => 1
	    },
	    namespace => 'MyClass::View',
	    exclude => qr(^te(?:st|mp)_)i,
	    include => qr(_foo$),
	);

    # create classes
    @classes = $loader->load_views;

    MyClass::View::LiveFoo->retrieve_all()

=head1 DESCRIPTION

This class loads views from databases as L<Class::DBI> classes. It follows
roughly the same interface employed by L<Class::DBI::Loader>.

This class behaves as a base class for the database-dependent driver classes,
which are loaded by L<Module::Pluggable>. Objects are reblessed into the
relevant subclass as soon as the driver is discovered, see set_dsn(). Driver
classes should always be named Class::DBI::ViewLoader::E<lt>driver_nameE<gt>.

=cut

use Module::Pluggable (
	search_path => __PACKAGE__,
	require => 1,
	inner => 0
    );

use Class::DBI;

use Carp qw( croak confess );

our %handlers = reverse map { /(.*::(.*))/ } __PACKAGE__->plugins();

=head1 CONSTRUCTOR

=head2 new

    $obj = $class->new(%args)

Instantiates a new object. The values of %args are passed to the relevant set_*
accessors, detailed below. The following 2 statements should be equivalent:

    new Class::DBI::ViewLoader ( dsn => $dsn, username => $user );

    new Class::DBI::ViewLoader->set_dsn($dsn)->set_username($user);

=cut

sub new {
    my($class, %args) = @_;

    my $self = bless {}, $class;

    # Do dsn first, as we may be reblessed
    if ($args{dsn}) {
	$self->set_dsn(delete $args{dsn});
    }

    for my $arg (keys %args) {
	if (my $sub = $self->can("set_$arg")) {
	    &$sub($self, delete $args{$arg});
	}
    }

    if (%args) {
	# All supported argumnets should have been deleted
	my $extra = join(', ', map {"'$_'"} sort keys %args);
	croak "Unrecognised arguments in new: $extra";
    }

    return $self;
}

=head1 ACCESSORS

=head2 set_dsn

    $obj = $obj->set_dsn($dsn_string)

Sets the datasource for the object. This should be in the form understood by
L<DBI> e.g. "dbi:Pg:dbname=mydb"

Calling this method will rebless the object into a handler class for the given
driver. If no handler is installed, "No handler for driver" will be raised via
croak().

=cut

sub set_dsn {
    my($self, $dsn) = @_;

    my($driver) = $dsn =~ /^dbi:(\w+)/;

    my $handler = $handlers{$driver};

    if ($handler) {
	if ($handler->isa(__PACKAGE__)) {
	    $self->{_dsn} = $dsn;

	    # rebless into handler class
	    bless $self, $handler;

	    return $self;
	}
	else {
	    confess "$handler is not a ".__PACKAGE__." subclass";
	}
    }
    else {
	croak "No handler for driver $driver, from dsn '$dsn'";
    }
}

=head2 get_dsn

    $dsn = $obj->get_dsn

Returns the dsn string, as passed in by set_dsn.

=cut

sub get_dsn { $_[0]->{_dsn} }

=head2 set_username

    $obj = $obj->set_username($username)

Sets the username to use when connecting to the database.

=cut

sub set_username { $_[0]->{_username} = "$_[1]"; $_[0] }

=head2 get_username

    $username = $obj->get_username

Returns the username.

=cut

sub get_username { $_[0]->{_username} }

=head2 set_password

    $obj = $obj->set_password

Sets the password to use when connecting to the database.

=cut

sub set_password { $_[0]->{_password} = "$_[1]"; $_[0] }

=head2 get_password

    $password = $obj->get_password

Returns the password

=cut

sub get_password { $_[0]->{_password} }

=head2 set_options

    $obj = $obj->set_dbi_options(%opts)

Accepts a hash or a hash reference.

Sets the additional configuration options to pass to L<DBI>.

The hash will be copied internally, to prevent against any accidental
modification after assignment.

=cut

sub set_options {
    my $self = shift;
    my $opts = { ref $_[0] ? %{ $_[0] } : @_ };

    $self->{_dbi_options} = $opts;

    return $self;
}

=head2 get_options

    \%opts = $obj->get_dbi_options

Returns the DBI options hash. The return value should always be a hash
reference, even if there are no dbi options set.

The reference returned by this function is live, so modification of it directly
affects the object.

=cut

sub get_options {
    my $self = shift;

    # set up an empty options hash if there is none available.
    $self->set_options unless $self->{_dbi_options};

    return $self->{_dbi_options};
}

# Return this object's complete arguments to send to DBI.
sub _get_dbi_args {
    my $self = shift;

    return @$self{qw( _dsn _username _password _dbi_options )};
}

# Return a new DBI handle
# Drivers should use this method to access the database
sub _get_dbi_handle {
    my $self = shift;

    return $self->{_dbh} if $self->{_dbh};

    $self->{_dbh} = DBI->connect( $self->_get_dbi_args )
	or croak "Couldn't connect to database, $DBI::errstr";

    return $self->{_dbh};
}

sub DESTROY {
    my $self = shift;

    if ($self->{_dbh}) {
	$self->{_dbh}->disconnect;
    }
}

=head2 set_namespace

    $obj = $obj->set_namespace($namespace)

Sets the namespace to load views into.

=cut

sub set_namespace {
    my($self, $namespace) = @_;

    $namespace =~ s/::$//;

    $self->{_namespace} = $namespace;

    return $self;
}

=head2 get_namespace

    $namespace = $obj->get_namespace

Returns the target namespace. If not set, returns an empty list.

=cut

sub get_namespace {
    my $self = shift;
    my $out = $self->{_namespace};

    if (defined $out and length $out) {
	return $out;
    }
    else {
	return;
    }
}

=head2 set_include

    $obj = $obj->set_include($regexp)

Sets a regexp that matches the views to load.

Accepts strings or Regexps, croaks if any other reference is passed.

The value is stored as a Regexp, even if a string was passed in.

=cut

sub set_include {
    my($self, $include) = @_;

    $self->{_include} = $self->_compile_regex($include);

    return $self;
}

=head2 get_include

    $regexp = $obj->get_include

Returns the include regular expression.

Note that this may not be identical to what was passed in.

=cut

sub get_include { $_[0]->{_include} }

=head2 set_exclude

    $obj = $obj->set_exclude($regexp)

Sets a regexp to use to rule out views. 

Accepts strings or Regexps, croaks if any other reference is passed.

The value is stored as a Regexp, even if a string was passed in.

=cut

sub set_exclude {
    my($self, $exclude) = @_;

    $self->{_exclude} = $self->_compile_regex($exclude);

    return $self;
}

=head2 get_exclude

Returns the exclude regular expression.

Note that this may not be identical to what was passed in.

=cut

sub get_exclude { $_[0]->{_exclude} }

# Return a compiled regex from a string or regex
sub _compile_regex {
    my($self, $regex) = @_;

    if (defined $regex) {
	if (ref $regex) {
	    croak "Regexp or string required"
		if ref $regex ne 'Regexp';
	}
	else {
	    $regex = qr($regex);
	}
    }

    return $regex;
}

# Apply include and exclude rules to a list of view names
sub _filter_views {
    my($self, @views) = @_;

    my $include = $self->get_include;
    my $exclude = $self->get_exclude;

    @views = grep { $_ =~ $include } @views if $include;
    @views = grep { $_ !~ $exclude } @views if $exclude;

    return @views;
}

=head2 load_views

    @classes = $obj->load_views

The main method for the class, loads all relevant views from the database and
generates classes for those views.

The generated classes will and be read-only, and have a multi-column primary key
containing every column. This is because it is unlikely that the view will have
a real primary key.

Returns class names for all created classes.

=cut

sub load_views {
    my $self = shift;

    my @views = $self->get_views;

    my @classes;

    for my $view ($self->_filter_views(@views)) {
	my @cols = $self->get_view_cols($view);

	if (@cols) {
	    push @classes, $self->_create_class($view, @cols);
	}
	else {
	    warn "No columns found in $view, skipping\n";
	}
    }

    return @classes;
}

# Set up the view class.
sub _create_class {
    my($self, $view, @columns) = @_;

    my $class = $self->_view_to_class($view);

    {
	no strict 'refs';
	my $base = $self->base_class;
	@{$class.'::ISA'} = $base;
    }

    # Don't redefine db_Main
    $class->set_db(Main => $self->_get_dbi_args)
	unless $class->can('db_Main');

    # Prevent attempts to write to views
    $class->make_read_only;

    $class->table($view);

    # We probably won't have a primary key,
    # use a multi-column primary key containing all rows
    $class->columns(Primary => @columns);

    return $class;
}

# Convert a view name to a class name
# cribbed from Class::DBI::Loader
sub _view_to_class {
    my($self, $view) = @_;

    $view = join('', map { ucfirst } split(/[\W_]+/, $view));

    return join('::', $self->get_namespace, $view);
}

=head1 DRIVER METHODS

The following methods are provided by the relevant driver classes. If they are
called on a native Class::DBI::ViewLoader object (one without a dsn set), they
will cause fatal errors. They are mostly documented here for the benefit of
driver writers but they may prove useful for users also.

=head2 base_class

    $class = $driver->base_class

Returns the name of the base class to be used by generated classes.

=cut

sub base_class {
    my $self = shift;

    $self->_refer_to_handler();
}

=head2 get_views

    @views = $driver->get_views;

Returns the names of all the views in the database.

=cut

sub get_views {
    my $self = shift;

    $self->_refer_to_handler()
}

=head2 get_view_cols

    @columnss = $driver->get_view_cols($view);

Returns the names of all the columns in the given view.

=cut

sub get_view_cols {
    my $self = shift;

    $self->_refer_to_handler();
}

sub _refer_to_handler {
    my $self = shift;
    my $handler = ref $self;

    if ($handler eq __PACKAGE__) {
	# We haven't reblessed into a subclass
	confess "No handler loaded, try calling set_dsn() first";
    }
    else {
	my $sub = (caller(1))[3];
	$sub =~ s/.*:://;
	confess "$sub not overridden by $handler";
    }
}

1;

__END__

=head1 DIAGNOSTICS

The following fatal errors are raised by this class:

=over 4

=item * No handler for driver %s, from dsn %s";

set_dsn couldn't find a driver handler for the given dsn. You may need to
install a plugin to handle your database.

=item * No handler loaded

load_views() or some other driver-dependent method was called on an object which
hadn't loaded a driver.

=item * %s not overridden

A driver did not override the given method.

=item * Couldn't connect to database

Self-explanatory. The DBI error string is appended to the error message.

=item * Regexp or string required

set_include or set_exclude called with a ref other than 'Regexp'.

=item * Unrecognised arguments in new

new() encountered unsupported arguments. The offending arguments are listed
after the error message.

=back

=head1 SEE ALSO

L<DBI>, L<Class::DBI>, L<Class::DBI::Loader>

=head1 AUTHOR

Matt Lawrence E<lt>mattlaw@cpan.orgE<gt>

=cut
