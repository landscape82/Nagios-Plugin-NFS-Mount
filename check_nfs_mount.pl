#!/usr/bin/env perl

# For testing if the nfs mount is not only mounted but also writable
# (not stale), the script needs rw-access for the nagios user in the 
# directory called "monitor" in the root of the tested mount-point.

# Claudio Ramirez <nxadm@cpan.org>, GPLv3 or later.

use warnings;
use strict;
#use v5.10;
use File::Temp ();
use Nagios::Plugin;

# Plugin interface
#   --verbose, --help, --usage, --timeout and --host are defined automatically.
my $plugin = Nagios::Plugin->new(
	usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>] ",
);
$plugin->add_arg(
	spec => 'hello=s',
	help => 'NFS Mounting works or not, so the possible states are OK and critical.',
);
$plugin->getopts;

# Internal Vars
my @errors;
chomp( my $os        = `uname -s` );
my %osinfo = (
        SunOS => [ '/etc/vfstab', '/usr/sbin/mount'],
        Linux => [ '/etc/fstab', '/bin/mount' ],
);
chomp( my @mountinfo = `$osinfo{$os}[1]` );
my @mountpoints = parse_fstab();
my $msg;

# Check if filesystem are mounted
if (!@mountpoints) {
	$msg = 'No NFS mounts defined.';
} else {
	for my $mnt (@mountpoints) {
		if ( !grep {/^$mnt/} @mountinfo ) {
			push @errors, "$mnt is not mounted.\n";
		} else { # write a test file if mounted
			my $tmp = eval { File::Temp->new( UNLINK => 1, DIR => "$mnt/monitor" ) };
			if ( !defined $tmp ) {
				push @errors, "$mnt is not writable.\n";
			}
		}
	}
} 

# Plugin status
if ( !@errors ) { $plugin->nagios_exit( OK, ($msg) ? $msg : "All NFS mounts are OK." ); }
else {
	for my $error (@errors) { $plugin->add_message( CRITICAL, $error ); }
	my ( $code, $message ) = $plugin->check_messages();
	$plugin->nagios_exit( $code, $message );
}

# Subroutines
sub parse_fstab {
	my @mnts;
	open( my $fstab_fh, '<', $osinfo{$os}[0] );
	while (<$fstab_fh>) {
		next if ( !/\s+nfs\s+/ );
		my ( undef, undef, $mnt ) = split /\s+/;
		push @mnts, $mnt;
	}
	return @mnts;
}

1; # to facilitate unit testing
