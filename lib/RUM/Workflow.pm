package RUM::Workflow;

use strict;
use warnings;

use File::Path qw(mkpath);
use Carp;
use Exporter qw(import);

our @EXPORT_OK = qw(is_dry_run shell make_paths report with_dry_run with_settings);

our $DRY_RUN;

=item report ARGS

Print ARGS as a message prefixed with a "#" character.

=cut

sub report {
    my @args = @_;
    print "# @args\n";
}

sub with_settings {
    my ($settings, $code) = @_;
    my $old = $DRY_RUN;
    $DRY_RUN = $settings->{dry_run};
    my $result = $code->();
    $DRY_RUN = $old;
    return $result;
}

sub is_dry_run {
    return $DRY_RUN;
}

=item shell CMD, ARGS

Execute "$CMD @ARGS" using system unless $DRY_RUN is set. Check the
output status and croak if it fails.

=cut

sub shell {
    my @cmd = @_;
    if (is_dry_run) {
        print "@cmd";
    }
    else {
        system(@cmd) == 0 or croak "Error running @cmd: $!";
    }
}

=item make_paths RUN_NAME

Recursively make all the paths required for the given test run name,
unless $DRY_RUN is set.

=cut

sub make_paths {
    my (@paths) = @_;

    for my $path (@paths) {
        
        if (-e $path) {
            report "$path exists; not creating it";
        }
        else {
            print "mkdir -p $path\n";
            mkpath($path) or die "Can't make path $path: $!" unless is_dry_run;
        }

    }
}
1;
