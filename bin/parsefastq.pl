#!/usr/bin/perl
use strict;

if(@ARGV<4) {
    die "
Usage: parsefastq.pl <infile> <num chunks> <reads out> <quals out> [option]

option:
          -name_mapping F  : If set will write a file <F> mapping modified names to
                             original names

";
}

my $infile = $ARGV[0];
my $numchunks = $ARGV[1];
my $reads_out = $ARGV[2];
my $quals_out = $ARGV[3];
my $name_mapping_file;
my $map_names = "false";
my $optionrecognized;
for(my $i=4; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-name_mapping") {
	$map_names = "true";
	$i++;
	$name_mapping_file = $ARGV[$i];
	open(NAMEMAPPINGALL, ">$name_mapping_file") or die "ERROR: in script parsefastq.pl, cannot open \"$name_mapping_file\" for writing.\n\n";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	print ERRORLOG "\nERROR: option $ARGV[$i] not recognized.\n\n";
	die "\nERROR: option $ARGV[$i] not recognized.\n\n";
    }
}

my $paired = "true";
my $infile1;
my $infile2;
my $line_hold;

if($infile =~ /,,,/) {
    $infile =~ /^(.*),,,(.*)$/;
    $infile1 = $1;
    $infile2 = $2
} else {
    $infile1 = $infile;
    $paired = "false";
}
open(INFILE1, $infile1) or die "\nERROR: in script parsefastq.pl: cannot open '$infile1' for reading\n";
if($paired eq "true") {
    open(INFILE2, $infile2) or die "\nERROR: in script parsefastq.pl: cannot open '$infile2' for reading\n";
}

my $filesize = -s $infile1;

# put something here for the case the file is less than 10,000 lines (or 2,500 entries)

my $FL = `head -10000 $infile1 | wc -l`;
chomp($FL);
$FL =~ s/[^\d]//gs;

my $s1 = `head -$FL $infile1`;
my $s2 = `tail -$FL $infile1`;
my $totalsize = length($s1) + length($s2);
my $recordsize = $totalsize / ($FL / 2);
my $numrecords = int($filesize / $recordsize);
my $numrecords_per_chunk = int($numrecords / $numchunks);

my $seq_counter = 0;
my $endflag = 0;
open(ROUTALL, ">$reads_out");
open(QOUTALL, ">$quals_out");
my $linecnt = 0;
my $readname;
my $name_mapping_chunk;
if($paired eq "false") {
    for(my $chunk=1; $chunk<=$numchunks; $chunk++) {
	my $reads_file = $reads_out . ".$chunk";
	my $quals_file = $quals_out . ".$chunk";
	if($endflag == 1) {
	    $chunk = $numchunks;
	    next;
	}
	open(ROUT, ">$reads_file");
	open(QOUT, ">$quals_file");
	if($map_names eq "true") {
	    $name_mapping_chunk = $name_mapping_file . ".$chunk";
	    open(NAMEMAPPING, ">$name_mapping_chunk");
	}
	if($chunk == $numchunks) {
	    # just to make sure we get everything in the last chunk
	    $numrecords_per_chunk = $numrecords_per_chunk * 100; 
	}
	for(my $i=0; $i<$numrecords_per_chunk; $i++) {
	    $seq_counter++;
	    my $readname = <INFILE1>;
	    $readname =~ s/^@//;
	    $linecnt++;
	    my $line = <INFILE1>;
	    $line_hold = $line;
	    $linecnt++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		$endflag = 1;
		next;
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "a\n";
	    print ROUTALL "a\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "a\t$readname";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "a\t$readname";
	    }
	    $line =~ s/\./N/g;
	    $line = uc $line;
	    if($line =~ /[^ACGTN.]/ || !($line =~ /\S/)) {
		print STDERR "\nERROR: in script parsefastq.pl: There's something wrong with line $linecnt in file \"$infile1\"\nIt should be a line of sequence but it is:\n$line_hold\n\n";
		exit();
	    }

	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    $line = <INFILE1>;
	    $linecnt++;
	    $line = <INFILE1>;
	    $linecnt++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    print QOUT ">seq.$seq_counter";
	    print QOUTALL ">seq.$seq_counter";
	    print QOUT "a\n";
	    print QOUTALL "a\n";
	    print QOUT "$line\n";
	    print QOUTALL "$line\n";
	}
	close(ROUT);
	close(QOUT);
	if($map_names eq "true") {
	    close(NAMEMAPPING);
	}
    }
}

my $linecnt1=0;
my $linecnt2=0;
if($paired eq "true") {
    for(my $chunk=1; $chunk<=$numchunks; $chunk++) {
	my $reads_file = $reads_out . ".$chunk";
	my $quals_file = $quals_out . ".$chunk";
	if($endflag == 1) {
	    $chunk = $numchunks;
	    next;
	}
	open(ROUT, ">$reads_file");
	open(QOUT, ">$quals_file");
	if($map_names eq "true") {
	    $name_mapping_chunk = $name_mapping_file . ".$chunk";
	    open(NAMEMAPPING, ">$name_mapping_chunk");
	}
	if($chunk == $numchunks) {
	    # just to make sure we get everything in the last chunk
	    $numrecords_per_chunk = $numrecords_per_chunk * 100; 
	}
	for(my $i=0; $i<$numrecords_per_chunk; $i++) {
	    $seq_counter++;
	    my $readname = <INFILE1>;
	    $readname =~ s/^@//;
	    $linecnt1++;
	    my $line = <INFILE1>;
	    $line_hold = $line;
	    $linecnt1++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		$endflag = 1;
		next;
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "a\n";
	    print ROUTALL "a\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "a\t$readname";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "a\t$readname";
	    }
	    $line =~ s/\./N/g;
	    $line = uc $line;
	    if($line =~ /[^ACGTN.]/ || !($line =~ /\S/)) {
		print STDERR "\nERROR: in script parsefastq.pl: There's something wrong with line $linecnt1 in file \"$infile1\"\nIt should be a line of sequence but it is:\n$line_hold\n\n";
		exit();
	    }
	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    $line = <INFILE1>;
	    $linecnt1++;
	    $line = <INFILE1>;
	    $linecnt1++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the forward file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    print QOUT ">seq.$seq_counter";
	    print QOUTALL ">seq.$seq_counter";
	    print QOUT "b\n";
	    print QOUTALL "b\n";
	    print QOUT "$line\n";
	    print QOUTALL "$line\n";

	    $readname = <INFILE2>;
	    $readname =~ s/^@//;
	    $linecnt2++;
	    $line = <INFILE2>;
	    $line_hold = $line;
	    $linecnt2++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the forward and reverse files are different sizes.\n";
		exit(0);
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "b\n";
	    print ROUTALL "b\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "b\t$readname";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "b\t$readname";
	    }
	    $line =~ s/\./N/g;
	    if($line =~ /[^ACGTN.]/ || !($line =~ /\S/)) {
		print STDERR "\nERROR: in script parsefastq.pl: There's something wrong with line $linecnt2 in file \"$infile2\"\nIt should be a line of sequence but it is:\n$line_hold\n\n";
		exit();
	    }
	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    $line = <INFILE2>;
	    $linecnt2++;
	    $line = <INFILE2>;
	    $linecnt2++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the reverse file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    print QOUT ">seq.$seq_counter";
	    print QOUTALL ">seq.$seq_counter";
	    print QOUT "a\n";
	    print QOUTALL "a\n";
	    print QOUT "$line\n";
	    print QOUTALL "$line\n";
	}
	close(ROUT);
	close(QOUT);
	if($map_names eq "true") {
	    close(NAMEMAPPING);
	}
    }
}

close(INFILE1);
if($paired eq "true") {
    close(INFILE2);
}
close(ROUTALL);
close(QOUTALL);