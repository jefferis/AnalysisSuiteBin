#!/usr/bin/perl

# meshtoasc.pl
# script to convert Amira Mesh Data Objects to Neurolucida .asc tracings
# 
# Begun by gsxej 2005-02-02
# First of all, consider if it is actually necessary and useful to
# do this!

# One thought - I think it would be nice if the output files
# had the same time stamp is the input.

require 5.004;
use File::Find;
use File::Basename;
use File::Spec;
use strict;

use vars qw/ %opt /;  # for command line options - see init()

my $file;
my @ascdata;
my @coords;
my @indices;
my @widths;

if (!defined($ARGV[0])){
	die "no input specified\n";
} else {
	$file = $ARGV[0];
	die "could not open $file" unless open(ASCFILE, $file);
	@ascdata = <ASCFILE>;
	close(ASCFILE);
}
if(!extractCoords(\@ascdata,\@coords,\@indices,\@widths)) {
	die "no coordinates in .asc file\n";
}
writeFile(@coords, @indices, @widths);

# subroutine: extractCoords(\@ascdata,\@coords,\@indices,\@widths)
# ----------------------------------------------------------------
# this subroutine takes the input from the .asc file and extracts
# the coordinates into the @coords array, the widths into the @ widths
# array and creates line segements from each headpoint to an endpoint
# or beginning of a new branch in the array @indices
sub extractCoords{
	# get the co-ords out of the file we are processing
	# expects references to two arrays
	my ($ascdata,$coords,$indices,$widths)=@_;
	my ($i,$l)=(0,0);
	my $top;
	my $nodesinseg = 0;
	my $segment=0;
	my @headpoint;
	push(@headpoint, -1);
	foreach(@{$ascdata}){
		# remove any comments and then
		# remove any remaining carriage returns or newlines
		s/\)\s*;.*$/\)/;
		s/\r\n//;
		
		if(/\(\s*([\-+.0-9]+)\s*([\-+.0-9]+)\s*([\-+.0-9]+)\s*([\-+.0-9]+)\)/) {
			my $x=$1; my $y=$2; my $z=$3; my $w=$4;
			# note the requirement for square brackets around the row x,y,z
			# and the dereferencing of the array ref $coords
			$coords[$i] = join " ", $x, $y, $z;
			$widths[$i] = $w;
			$indices[$segment] .= $i." ";
			# note how the reference $coords[i-1]
			# is dereferenced as an array by the use of
			# @{}
			#my @thisCoord=(@{$coords[$i-1]});						
			#print join(" ",@thisCoord)," $i\n";
			$i++;
			$nodesinseg++;
		} elsif (/\($/) {
			# deals with the beginning of a line segment
			# by adding terminating last segment with -1
			# and starting new segment with headpoint
			$indices[$segment++] .= "-1";
			$indices[$segment] .= ($i-1)." ";
			push(@headpoint, $i-1);
			$nodesinseg = 1;
		} elsif(/\|$/) {
			# deals with a branch after the first by terminating
			# last segment and started new segment with headpoint
			if($nodesinseg>=1) {
				$indices[$segment++].="-1";
			}
			$indices[$segment].=$headpoint[$#headpoint]." ";
			$nodesinseg = 1;
		} elsif(/\)$/) {
			# deals with end of a branch by terminating segment
			# and discarding last headpoint
			if($nodesinseg>=1) {
				$indices[$segment++].="-1";
				$nodesinseg = 0;
			}
			pop(@headpoint);
		}
	}
	# to let the caller know how many coords we found
	return $i;	
}

# subroutine: writeFile(@coords, @indices, @widths)
# -------------------------------------------------
# this subroutine outputs the gathered coordinates to a .am file
# in the correct AmiraMesh line segements format
sub writeFile{
	my ($coords, $indices, $widths)=@_;
	my $temp;
	my $numindices = $#indices+1;
	my $numcoords = $#coords+1;
	my $filename = $ARGV[0];
	# replace .asc extension with Amira .am extension
	$filename =~ s/\.asc$/\.am/;
	die "could not create output file $filename" unless open(OUTFILE, ">$filename");
	print OUTFILE "# AmiraMesh ASCII 1.0\n";
	print OUTFILE "\n";
	print OUTFILE "define Lines $numindices\n";
	print OUTFILE "define Vertices $numcoords\n";
	print OUTFILE "\n";
	print OUTFILE "Parameters \{\n";
	print OUTFILE "    ContentType \"HxLineSet\"\n";
	print OUTFILE "\}\n";
	print OUTFILE "\n";
	print OUTFILE "Vertices \{ float\[3\] Coordinates \} = \@1\n";
	print OUTFILE "Vertices \{ float Data \} = \@2\n";
	print OUTFILE "Lines \{ int LineIdx \} = \@3\n";
	print OUTFILE "\n";
	print OUTFILE "\@1 # $numcoords xyz coordinates\n";
	# writes to file all coordinates on separate lines
	foreach $temp (@coords) {
		print OUTFILE "$temp\n";
	}
	print OUTFILE "\n";
	print OUTFILE "\@2 # $numcoords width values\n";
	# writes to file all widths on a single line
	for(my $i=0; $i<$numcoords; $i++) {
		print OUTFILE $widths[$i];
		# this if statement to add a space to end of all widths
		# except the last
		if($i<($numcoords-1)) {
			print OUTFILE " ";
		}
	}
	print OUTFILE "\n\n";
	print OUTFILE "\@3 # $numindices line segements\n";
	# writes to file line segments
	foreach $temp (@indices) {
		print OUTFILE "$temp\n";
	}
}