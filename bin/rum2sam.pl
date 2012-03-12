#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::RumToSam");

=head1 NAME

rum2sam.pl - Convert RUM files into a sam file

=head1 SYNOPSIS

rum2sam.pl [OPTIONS] --unique-in <rum_unique_file> --non-unique-in
<rum_nu_file> --reads-in <reads_file> --quals-in <quals_file>
--sam-out <sam_outfile>

=head1 OPTIONS

=item B<--unique-in> I<rum_unique_file>

The file of unique mappers.

=item B<--non-unique-in> I<rum_nu_file>

The file of non-unique mappers.

=item B<--reads-in> I<reads_file>

The fasta file of reads, from parse2fasta.pl.

=item B<--quals-in> I<quals_file>

The fasta file of qualities from fastq2qualities.pl

=item B<-o>, B<--sam-out> I<sam_outfile>

The output file.

=item B<--suppress1>

Don't report records if neither forward nor reverse map.

=item B<--suppress2>

Don't report records of non-mapper, even if their pair mapped.

=item B<--suppress3>

Don't report records unless both forward and reverse mapped.

=item B<--name-mapping> I<name_mapping_file>

If set, will use F<name_mapping_file> to map names in the rum file to
names in the sam file.

=cut
