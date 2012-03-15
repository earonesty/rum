#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;
use_ok "RUM::Script::QuantifyExons";

my $exons = "$INPUT_DIR/inferred_internal_exons.txt";
our $unique = "$SHARED_INPUT_DIR/RUM_Unique.sorted.1";
our $non_unique = "$SHARED_INPUT_DIR/RUM_NU.sorted.1";
my $out = temp_filename(TEMPLATE => "quantify-exons.XXXXXX");


my @tests = (
    { name => "quant", 
      options => [] },
    { name => "quant-novel-countsonly", 
      options => ["-novel", "-countsonly"] },
    { name => "quant-novel-countsonly-strand-p", 
      options => ["-novel", "-countsonly", "-strand", "p"] },
    { name => "quant-novel-countsonly-strand-m", 
      options => ["-novel", "-countsonly", "-strand", "m"] },
    { name => "quant-novel-countsonly-strand-p-anti", 
      options => ["-novel", "-countsonly", "-strand", "p", "-anti"] },
    { name => "quant-novel-countsonly-strand-m-anti", 
      options => ["-novel", "-countsonly", "-strand", "m", "-anti"] },
);

plan tests => 1 + @tests;



for my $test (@tests) {
    my %test = %{ $test };

    my $name = $test->{name};
    my @options = @{ $test->{options} };
    my $out = temp_filename(TEMPLATE => "$name.XXXXXX");

    @ARGV = ("--exons-in", $exons,
             "--unique-in", $unique, 
             "--non-unique-in", $non_unique, 
             "--output", $out,
             @options);
    my @cmd = ("perl", "bin/quantifyexons.pl", @ARGV);

    RUM::Script::QuantifyExons->main();
#    system(@cmd) == 0 or die;
    no_diffs($out,  "$EXPECTED_DIR/$name", $name);
}
