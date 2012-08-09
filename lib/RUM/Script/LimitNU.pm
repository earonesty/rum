package RUM::Script::LimitNU;

use strict;
use warnings;
use autodie;

use File::Copy;
use RUM::Usage;
use RUM::RUMIO;

use base 'RUM::Script::Base';

sub main {
    
    my $self = __PACKAGE__->new;

    $self->get_options(
        "output|o=s" => \(my $outfile_name),
        "cutoff|n=s" => \(my $cutoff));

    $outfile_name or RUM::Usage->bad(
        "Please specify an output file with --output or -o");
    my $infile_name = $ARGV[0] or RUM::Usage->bad(
        "Please provide an input file");

    if (!int($cutoff)) {
        $self->logger->info("Not filtering out mappers");
        copy($infile_name, $outfile_name);
        return 0;
    }

    $self->logger->info("Filtering out mappers that appear $cutoff times or more");
   
    my (%fwd, %rev);

    open my $infile,  "<", $infile_name;
    open my $outfile, ">", $outfile_name;

    my $in = RUM::RUMIO->new(-fh => $infile);
    my $out = RUM::RUMIO->new(-fh => $outfile);

    while (my $aln = $in->next_aln) {
        my $readid = $aln->readid_directionless;
        $fwd{$readid}++ if $aln->contains_forward;
        $rev{$readid}++ if $aln->contains_reverse;
    }

    seek($infile, 0, 0);
    while(my $aln = $in->next_aln) {
        my $readid = $aln->readid_directionless;
        my $fwd = $fwd{$readid} || 0;
        my $rev = $rev{$readid} || 0;

        if ($fwd <= $cutoff && $rev <= $cutoff) {
            $out->write_aln($aln);
        }
    }
}

1;

__END__

=head1 NAME

RUM::Script::LimitNU - Remove some non-unique mappers.

=head1 METHODS

=over 4

=item main

The main program.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


