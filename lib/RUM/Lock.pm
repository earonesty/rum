package RUM::Lock;

=head1 NAME

RUM::Lock - Prevents two rum jobs from running on the same output dir.

=head1 SYNOPSIS

=head1 DESCRIPTION

When the user runs C<rum run>, we should attempt to acquire a lock
file by doing RUM::Lock->acquire("$output_dir/.rum/lock"). Then when
the pipeline is done, we should release the lock by doing
RUM::Lock->release. Note that we use only one global lock file at a
time; this class is not instantiable. Calling release when you do not
actually have the lock does nothing. In cases where the process that
the user ran kicks off other jobs and exits, it is necessary for the
top-most process to pass the lock down to a child process. This is
done by passing the filename as a parameter with the B<--lock> option
to C<rum run>.

=head1 CLASS METHODS

=over 4

=cut

use strict;
use warnings;

use Carp;

our $FILE;

=item acquire($filename)

If $filename exists, return undef, otherwise create it and return a
true value. The presence if the file indicates that the lock is held
by "someone".

=cut

sub acquire {
    my ($self, $file) = @_;
    return if -e $file;
    $FILE = $file;
    open my $out, ">", $file or croak "Can't open lock file $file: $!";
    print $out $$;
    close $out;
    return 1;
}

=item release

Release the lock by removing the file, if I own the lock. If I don't,
do nothing.

=cut

sub release {
    if ($FILE) {
        unlink $FILE if $FILE;
        undef $FILE;
    }
}

sub DESTROY {
    release();
}

1;

=back
