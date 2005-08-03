use Module::Build;

=head1 NAME

Build.PL - Build script generator for Class::DBI::ViewLoader

=head1 SYNOPSIS

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

=cut

Module::Build->new(
	    module_name => "Class::DBI::ViewLoader",
	    requires => {
		'Class::DBI' => 0,
		'Module::Pluggable' => 0,
	    },
	    build_requires => {
		'Test::More' => 0,
	    },
	    license => 'perl',
	    create_readme => 1,
	    create_makefile_pl => 'passthrough',
	)->create_build_script;
