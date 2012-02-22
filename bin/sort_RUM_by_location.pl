#!/usr/bin/perl

$|=1;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use Carp;

use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(merge_iterators cmpChrs by_chromosome by_location);
use RUM::FileIterator qw(file_iterator pop_it peek_it);
use File::Copy qw(mv cp);

use strict;
use warnings;

my $timestart = time();
if(@ARGV < 2) {
    die "
Usage: sort_RUM_by_location.pl <rum file> <sorted file> [options]

Where: <rum file> is the RUM_Unique or RUM_NU file output from
       the RUM pipeline.

       <sorted file> is the name of the sorted output file

Options: -separate : Do not (necessarily) keep forward and reverse
                     together.  By default they are kept together.

         -maxchunksize n : is the max number of reads that the program tries to
         read into memory all at once.  Default = 10,000,000

         -ram n    : the number of GB of RAM if less than 8, otherwise
                     will assume you have 8, give or take, and pray...
                     If you have some millions of reads and not at
                     least 4Gb then this is probably not going to work.

         -allowsmallchunks : Allow -maxchunksize to be less than 500,000.
                             This may be useful for testing purposes.
";
}

my $allowsmallchunks = 0;

my $separate = 0;
my $ram = 6;
my $infile = $ARGV[0];
my $outfile = $ARGV[1];
my $running_indicator_file = $ARGV[1];
$running_indicator_file =~ s![^/]+$!!;
$running_indicator_file = $running_indicator_file . ".running";
open(OUTFILE, ">$running_indicator_file") or die "ERROR: in script sort_RUM_by_location.pl: cannot open file '$running_indicator_file' for writing.\n\n";
print OUTFILE "0";
close(OUTFILE);

my $maxchunksize = 9000000;
my $maxchunksize_specified = "false";
my $name;

for(my $i=2; $i<@ARGV; $i++) {
    my $optionrecognized = 0;
    if($ARGV[$i] eq "-separate") {
	$separate = 1;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-ram") {
	$ram = $ARGV[$i+1];
	if(!($ram =~ /^\d+$/)) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -ram must be an integer greater than zero, you gave '$ram'.\n\n";
	} elsif($ram==0) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -ram must be an integer greater than zero, you gave '$ram'.\n\n";
	}
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-maxchunksize") {
	$maxchunksize = $ARGV[$i+1];
	if(!($maxchunksize =~ /^\d+$/)) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -maxchunksize must be an integer greater than zero, you gave '$maxchunksize'.\n\n";
	} elsif($maxchunksize==0) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -maxchunksize must be an integer greater than zero, you gave '$maxchunksize'.\n\n";
	}
	$i++;
	$optionrecognized = 1;
	$maxchunksize_specified = "true";
    }
    if($ARGV[$i] eq "-name") {
	$name = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if ($ARGV[$i] eq "-allowsmallchunks") {
        $allowsmallchunks = 1;
        $optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: in script sort_RUM_by_location.pl: option '$ARGV[$i]' not recognized\n";
    }
}
# We have a test that exercises the ability to merge chunks together,
# so allow max chunk sizes smaller than 500000 if that flag is set.
if ($maxchunksize < 500000 && !$allowsmallchunks) {
    die "ERROR: in script sort_RUM_by_location.pl: <max chunk size> must at least 500,000.\n\n";
}

my $max_count_at_once;
if($maxchunksize_specified eq "false") {
    if($ram >= 7) {
	$max_count_at_once = 10000000;
    } elsif($ram >=6) {
	$max_count_at_once = 8500000;
    } elsif($ram >=5) {
	$max_count_at_once = 7500000;
    } elsif($ram >=4) {
	$max_count_at_once = 6000000;
    } elsif($ram >=3) {
	$max_count_at_once = 4500000;
    } elsif($ram >=2) {
	$max_count_at_once = 3000000;
    } else {
	$max_count_at_once = 1500000;
    }
} else {
    $max_count_at_once = $maxchunksize;
}
my %chr_counts;
&doEverything();

my $size_input = -s $infile;
my $size_output = -s $outfile;

my $clean = "false";
for(my $i=0; $i<2; $i++) {
    if($size_input != $size_output) {
	print STDERR "Warning: from script sort_RUM_by_location.pl on \"$infile\": sorting failed, trying again.\n";
	&doEverything();
	$size_output = -s $outfile;
    } else {
	$i = 2;
	$clean = "true";
	print "\n$infile reads per chromosome:\n\nchr_name\tnum_reads\n";
	foreach my $chr (sort by_chromosome keys %chr_counts) {
	    print "$chr\t$chr_counts{$chr}\n";
	}
    }
}

if($clean eq "false") {
    print STDERR "ERROR: from script sort_RUM_by_location.pl on \"$infile\": the size of the unsorted input ($size_input) and sorted output\nfiles ($size_output) are not equal.  I tried three times and it failed every\ntime.  Must be something strange about the input file...\n\n";
}

sub get_chromosome_counts {
    use strict;
    my ($infile) = @_;
    open my $in, "<", $infile;

    my %counts;

    my $num_prev = "0";
    my $type_prev = "";
    while(my $line = <$in>) {
	chomp($line);
	my @a = split(/\t/,$line);
	$line =~ /^seq.(\d+)([^\d])/;
	my $num = $1;
	my $type = $2;
	if($num eq $num_prev && $type_prev eq "a" && $type eq "b") {
	    $type_prev = $type;
	    next;
	}
	if($a[1] =~ /\S/) {
	    $counts{$a[1]}++;
	}
	$num_prev = $num;
	$type_prev = $type;
    }
    return %counts;
}

sub doEverything () {

    open(FINALOUT, ">$outfile");
    %chr_counts = get_chromosome_counts($infile);


    my (@CHR, %CHUNK);

    my $cnt=0;
    foreach my $chr (sort by_chromosome keys %chr_counts) {
	$CHR[$cnt] = $chr;
	$cnt++;
    }
    my $chunk = 0;
    $cnt=0;
    while($cnt < @CHR) {
	my $running_count = $chr_counts{$CHR[$cnt]};
	$CHUNK{$CHR[$cnt]} = $chunk;
	if($chr_counts{$CHR[$cnt]} > $max_count_at_once) { 
            # it's bigger than $max_count_at_once all by itself..
	    $CHUNK{$CHR[$cnt]} = $chunk;
	    $cnt++;
	    $chunk++;
	    next;
	}
	$cnt++;
	while($cnt < @CHR &&
                  $running_count+$chr_counts{$CHR[$cnt]} < $max_count_at_once) {
            my $chr = $CHR[$cnt];
	    $running_count = $running_count + $chr_counts{$chr};
	    $CHUNK{$chr} = $chunk;
	    $cnt++;
	}
	$chunk++;
    }
    
# DEBUG
#foreach $chr (sort {cmpChrs($a,$b)} keys %CHUNK) {
#    print STDERR "$chr\t$CHUNK{$chr}\n";
#}
# DEBUG
    my %F1;
    my $numchunks = $chunk;
    for(my $chunk=0;$chunk<$numchunks;$chunk++) {
	open $F1{$chunk}, ">" . $infile . "_sorting_tempfile." . $chunk;
    }
    open(INFILE, $infile);
    while(my $line = <INFILE>) {
	chomp($line);
	my @a = split(/\t/,$line);
	my $FF = $F1{$CHUNK{$a[1]}};
	if($line =~ /\S/) {
	    print $FF "$line\n";
	}
    }
    for($chunk=0;$chunk<$numchunks;$chunk++) {
	close $F1{$chunk};
    }
    
    $cnt=0;
    $chunk=0;
    
    while($cnt < @CHR) {

	my %chrs_current;
	my $running_count = $chr_counts{$CHR[$cnt]};
	$chrs_current{$CHR[$cnt]} = 1;
	if($chr_counts{$CHR[$cnt]} > $max_count_at_once) { # it's a monster chromosome, going to do it in
	    # pieces for fear of running out of RAM.
	    my $INFILE = $infile . "_sorting_tempfile." . $CHUNK{$CHR[$cnt]};
	    open my $sorting_chunk_in, "<", $INFILE;

            # Open an iterator over the records in $sorting_chunk_in
            my $it = file_iterator($sorting_chunk_in, separate => $separate);
	    my $FLAG = 0;
	    my $chunk_num = 0;

	    while($FLAG == 0) {
		$chunk_num++;
		my $number_so_far = 0;
		my $chunkFLAG = 0;
                my @recs;


		while($chunkFLAG == 0) {
                    my $rec = pop_it($it);
		    unless ($rec) {
			$chunkFLAG = 1;
			$FLAG = 1;
			next;
		    }
                    push @recs, $rec;

		    $number_so_far++;
		    if($number_so_far>$max_count_at_once) {
			$chunkFLAG=1;
		    }
		}
		# write out this chunk sorted:
                my $suffix = $chunk_num == 1 ? 0 : 1;
                my $tempfilename = $CHR[$cnt] . "_temp.$suffix";
		
		open(OUTFILE,">$tempfilename");
		foreach my $rec (sort by_location @recs) {
		    print OUTFILE "$rec->{entry}\n";
		}
		close(OUTFILE);
		
		# merge with previous chunk (if necessary):
#	    print "chunk_num = $chunk_num\n";
		if($chunk_num > 1) {

                    my @tempfiles = map "$CHR[$cnt]_temp.$_", (0,1,2);

                    open my $in1, "<", $tempfiles[0]
                        or croak "Can't open $tempfiles[0] for reading: $!";
                    open my $in2, "<", $tempfiles[1]
                        or croak "Can't open $tempfiles[1] for reading: $!";
                    open my $temp_merged_out, ">", $tempfiles[2]
                        or croak "Can't open $tempfiles[2] for writing: $!";

                    my @iters = (
                        file_iterator($in1, separate => $separate),
                        file_iterator($in2, separate => $separate));
		    merge_iterators($temp_merged_out, @iters);
                    close($temp_merged_out);
                    
                    mv $tempfiles[2], $tempfiles[0]
                        or croak "Couldn't move $tempfiles[2] to $tempfiles[0]: $!";
                    unlink($tempfiles[1]);
		}
	    }
	    my $tempfilename = $CHR[$cnt] . "_temp.0";
	    close(FINALOUT);
	    `cat $tempfilename >> $outfile`;
	    open(FINALOUT, ">>$outfile");
	    unlink($tempfilename);
	    $tempfilename = $CHR[$cnt] . "_temp.1";
	    unlink($tempfilename);
	    $tempfilename = $CHR[$cnt] . "_temp.2";
	    unlink($tempfilename);
	    $cnt++;
	    $chunk++;
	    next;
	}
	
	# START NORMAL CASE (SO NOT DEALING WITH A MONSTER CHROMOSOME)
	
	$cnt++;
	while ($cnt < @CHR && 
              $running_count+$chr_counts{$CHR[$cnt]} < $max_count_at_once) {
	    $running_count = $running_count + $chr_counts{$CHR[$cnt]};
	    $chrs_current{$CHR[$cnt]} = 1;
	    $cnt++;
	}
	my $INFILE = $infile . "_sorting_tempfile." . $chunk;
	open(my $sorting_file_in, $INFILE);
        sort_one_file($sorting_file_in, *FINALOUT, $separate);
	$chunk++;
    }
    close(FINALOUT);
    
    for($chunk=0;$chunk<$numchunks;$chunk++) {
	unlink($infile . "_sorting_tempfile." . $chunk);
    }
#$timeend = time();
#$timelapse = $timeend - $timestart;
#if($timelapse < 60) {
#    if($timelapse == 1) {
#	print "\nIt took one second to sort '$infile'.\n\n";
#    } else {
#	print "\nIt took $timelapse seconds to sort '$infile'.\n\n";
#    }
#}
#else {
#    $sec = $timelapse % 60;
#    $min = int($timelapse / 60);
#    if($min > 1 && $sec > 1) {
#	print "\nIt took $min minutes, $sec seconds to sort '$infile'.\n\n";
#    }
#    if($min == 1 && $sec > 1) {
#	print "\nIt took $min minute, $sec seconds to sort '$infile'.\n\n";
#    }
#    if($min > 1 && $sec == 1) {
#	print "\nIt took $min minutes, $sec second to sort '$infile'.\n\n";
#    }
#    if($min == 1 && $sec == 1) {
#	print "\nIt took $min minute, $sec second to sort '$infile'.\n\n";
#    }
#}

    unlink($running_indicator_file);
}

sub sort_one_file {
    my ($in, $out, $separate) = @_;

    # Open an iterator over the input file.
    my $it = file_iterator($in, separate => $separate);

    # Fill up @recs by repeatedly popping the iterator until it is
    # empty. See RUM::FileIterator.
    my @recs;
    while (my $rec = pop_it($it)) {
        push @recs, $rec;
    }

    # Sort the records by location (See RUM::Sort for by_location) and
    # print them.
    for my $rec (sort by_location @recs) {
        print $out "$rec->{entry}\n";
    }
}

