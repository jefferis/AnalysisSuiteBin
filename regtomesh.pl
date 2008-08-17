#!/usr/bin/perl

# regtomesh.pl
# script to convert Torsten's registration files to Amira Mesh Data Objects
#
# Greg Jefferis 
# 040827

require 5.004;
use File::Find;
use File::Basename;
use File::Spec;
use strict;

use vars qw/ %opt /;  # for command line options - see init()

my $file;
my @regdata;
my @coords;
my @activeset;

if (!defined($ARGV[0])){
	die "no input specified\n";
} else {
	$file = $ARGV[0];
	die "could not open $file" unless open(REGFILE, $file);
	@regdata = <REGFILE>;
	close(REGFILE);
}
print "There are ",scalar(@regdata)," lines\n";


if(!extractCoords(\@regdata,\@coords,\@activeset)) {
	die "no coordinates in .reg file\n";
}
writeFile(@coords, @activeset);

# subroutine: extractCoords(\@regdata,\@coords,\@indicess)
# ----------------------------------------------------------------
# this subroutine takes the input from the .reg file and extracts
# the coordinates into the @coords array and the 
 
sub extractCoords{
	# get the co-ords out of the file we are processing
	# expects references to two arrays
	my ($regdata,$coords,$activeset)=@_;
	my ($i,$l)=(0,0);
	my $inCoords=0;
	my $inActiveset=0;	
	
	for ($l=0;$l<@regdata;$l++){
		$_=$regdata[$l];		
		
		s/\)\s*;.*$/\)/;
		s/\r\n//;
		# remove any comments and then
		# remove any remaining carriage returns or newlines
		s/\)\s*;.*$/\)/;
		s/\r\n//;
		
		$inCoords = 1 if (/coefficients/);		
		if (/active/){
			$inActiveset = 1;			
			$inCoords = 0;			
		}
		
		if($inActiveset && /}/) {
			$inActiveset=0;			
		}
		
		if($inCoords && /\s*([\-+.0-9]+)\s*([\-+.0-9]+)\s*([\-+.0-9]+)/) {
			my $x=$1; my $y=$2; my $z=$3;
			
			push @coords, join " ", ($x, $y, $z);			
			$i++;			
			
		}
		
		if($inActiveset) {
			# remove anything other than 0s and 1s
			tr/[01]//cd;			
			s/000/0 /g;			
			s/111/1 /g;
			push @activeset, $_;			
		}		
	} # end for
	print "Found $i coords\n";	
	

	# to let the caller know how many coords we found
	return $i;	
}

# subroutine: writeFile(@coords, @indices)
# -------------------------------------------------
# this subroutine outputs the gathered coordinates to a .am file
# in the correct AmiraMesh line segements format
sub writeFile{
	#my ($coords, $activeset)=@_;
	my $temp;
	my $numcoords = $#coords+1;
	my $filename = $ARGV[0];
	# append Amira .am extension
	$filename .".am";
	die "could not create output file $filename" unless open(OUTFILE, ">$filename");
	print OUTFILE "# AmiraMesh ASCII 1.0\n";
	print OUTFILE "\n";
	print OUTFILE "define Points $numcoords\n";

	print OUTFILE "\n";
	print OUTFILE "Parameters \{\n";
	print OUTFILE "    ContentType \"HxCluster\"\n";
	print OUTFILE "\}\n";
	print OUTFILE "\n";
	print OUTFILE "Points \{ float\[3\] Coordinates \} = \@1\n";
	print OUTFILE "Points \{ byte Id \} = \@2\n";

	print OUTFILE "\n";
	print OUTFILE "\@1 # $numcoords xyz coordinates\n";
	# writes to file all coordinates on separate lines
	foreach $temp (@coords) {
		print OUTFILE "$temp\n";
	}
	print OUTFILE "\n";
	print OUTFILE "\@2 # $numcoords activeset values\n";
	# writes to file all activeset flags on a single line
	foreach $temp (@activeset) {
		print OUTFILE "$temp\n";
	}
	print OUTFILE "\n\n";
}