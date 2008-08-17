#!/usr/bin/perl

# asctomesh.pl
# script to convert Neurolucida .asc tracings to Amira Mesh Data Objects
# merged from version on LuoPC2 and a version dated Alex Chan 08/13/2004
# the 08/13/2004 definitely didn't work since it produced the wrong
# definiton of lines.  This Winter version does seem to work but will
# need modification re eg ERR.

require 5.005;
use File::Find;
use File::Basename;
use File::Spec;
use strict;

#use vars qw/ %opt /;  # for command line options - see init()

my $verbose = 0;
# define regex
my $numReg=qr/([\-+.0-9]+|ERR|NA)/;	


my $numcoords=0;
my $filename;
my @ascdata;
my @coords;
my @indices;
my @widths;

if (!defined($ARGV[0])){
	die "no input specified\n";
} else {
	$filename = $ARGV[0];
	die "could not open $filename" unless open(ASCFILE, $filename);
	@ascdata = <ASCFILE>;
	close(ASCFILE);
}

$numcoords = extractCoords(\@ascdata,\@coords,\@widths,\@indices);

if($numcoords){
	writeFile(\@coords,\@widths, \@indices);	
} else {
	die "unable to find any co-ordinates in asc file $filename\n";
}

# subroutine: extractCoords(\@ascdata,\@coords,\@indices,\@widths)
# ----------------------------------------------------------------
# this subroutine takes the input from the .asc file and extracts
# the coordinates into the @coords array, the widths into the @ widths
# array and creates line segements from each headpoint to an endpoint
# or beginning of a new branch in the array @indices
sub extractCoords{
	# get the co-ords out of the file we are processing
	# expects references to two arrays
	my ($ascdata,$coords,$widths,$indices)=@_;
	
	print "Entering extractCoords\n" if $verbose;
	print "There are ",scalar(@{$ascdata})," lines of text to parse\n";	
	
	my $axonFoundFlag=0; # when we find the start of the axon we will set this flag
	
	my ($i,$l)=(0,0);	
	my $top;
	my $nodesinseg = 0;
	my $segment=0;
	my @headpoint;
	my @endpoint;	
	
	push(@headpoint, -1);
	foreach(@{$ascdata}){
		# remove any remaining carriage returns or newlines
		s/[\r\n]//;
		# GJ: trim any comments etc from the end of line
		s/;.*$//;  s/\s*$//; # trim any remaining white space
		
		if(!$axonFoundFlag){
			$axonFoundFlag=1 if /\((Axon|Dendrite)\)/i;			
		}
		# skip if we haven't got to the axon or this is an empty line
		next if not $axonFoundFlag;
		next if /^\s*$/; 
		
		print STDERR $_,"\n" if $verbose;	
		print STDERR "Stack: ",join(",",@headpoint),"\n" if $verbose;		
		print STDERR "Num indices in seg ",${$indices}[$segment],"\n" if $verbose;		
		
		# add explicit match to start of line followed by optional
		# whitespace.  This should prevent parsing of spines etc.
		# it will also of course fail to match if there is a comment (;)
		# have also added option to match ERR
		if(/^\s*\(\s*$numReg\s+$numReg\s+$numReg\s+$numReg\)/) {
			my $x=$1; my $y=$2; my $z=$3; my $w=$4;
			# note ref $coords is dereferenced as an array by the use of @{}
			${$coords}[$i]="$x $y $z";
			# I think NA is more likely to be supported
			${$coords}[$i]=~s/ERR/NA/g;
			
			# NB Neurolucida and SWC use diameters I think
			${$widths}[$i]=$w/2;
			${$indices}[$segment] = ${$indices}[$segment].$i." ";

			$i++; $nodesinseg++;
		} elsif (/\($/) {
			print STDERR "opening segment of branch\n" if $verbose;			
			# deals with the beginning of a line segment
			# by adding terminating last segment with -1
			# and starting new segment with headpoint

			# GJ: only put a terminal -1 if there were nodes
			${$indices}[$segment++] .= "-1" if($nodesinseg>1);
			# GJ: headpoint should be last point of previous segment
			${$indices}[$segment] .= ($i-1)." ";
			push(@headpoint, $i-1);
			$nodesinseg = 1;
		} elsif(/\|$/) {
			print STDERR "second (or more) segment of branch\n" if $verbose;

			# deals with a branch after the first by terminating
			# last segment and starting new segment with headpoint
			# GJ: only put a terminal -1 if there were nodes
			${$indices}[$segment++].="-1" if($nodesinseg>1);
			${$indices}[$segment].=$headpoint[$#headpoint]." ";
			$nodesinseg = 1;
		} elsif(/\)$/) {
			# deals with end of a branch by terminating segment
			# GJ: NB need to pop this regardless of whether there are any nodes
			print STDERR "terminating segment\n" if $verbose;			
			pop(@headpoint); 
			# GJ: ACH 2004-08-13 version had >=1
			if($nodesinseg>1) {
				${$indices}[$segment++].="-1";
				$nodesinseg = 0;
			}
		}
	}
	# to let the caller know how many coords we found
	return $i;	
}

sub writeFile{
	my ($coords,$widths, $indices)=@_;
	
	print "Entering writeFile\n" if $verbose;	

	# GJ: need to get the total number of indices, not number of lines
	my $numindices=0;	
	foreach (@{$indices}){
		my @idxs=split(/ /);		
		$numindices+=scalar(@idxs);		
	}
	
	my $numcoords = $#{$coords}+1;
	#my $filename = $ARGV[0];
	# replace .asc extension with Amira .am extension
	# just append if ends in something funny
	my $outfile=$filename;
	$outfile.=".am" if not ($outfile =~ s/asc$/am/);	

	print "Opening $outfile for writing" if $verbose;
	die "could not create output file $outfile" unless open(OUTFILE, ">$outfile");

	print OUTFILE "# AmiraMesh ASCII 1.0\n\n";
	print OUTFILE "define Lines $numindices\n";
	print OUTFILE "define Vertices $numcoords\n\n";
	print OUTFILE 'Parameters {',"\n";
	print OUTFILE '    ContentType "HxLineSet"',"\n";
	print OUTFILE '}',"\n\n";
	print OUTFILE 'Vertices { float[3] Coordinates } = @1',"\n";
	print OUTFILE 'Vertices { float Data } = @2',"\n";
	print OUTFILE 'Lines { int LineIdx } = @3',"\n\n";

	print OUTFILE "\@1 # $numcoords xyz coordinates\n";
	print OUTFILE join("\n",@{$coords}),"\n";

	# writes to file all widths on a single line	
	print OUTFILE "\n\@2 # $numcoords radius values\n";
	print OUTFILE join(" ",@{$widths}),"\n\n";	
	
	print OUTFILE "\n\@3 # $numindices indices describe lines\n";	
	print OUTFILE join("\n",@{$indices});   	
	
	close(OUTFILE);	
	
}
