#!/usr/bin/perl
# TraceQualityControl.pl

# script designed to do simple quality control on tracings
# 

require 5.005; #for compiled regex
use strict;
use POSIX qw(strftime);


#use vars qw/ %opt /;  # for command line options - see init()
my $verbose = 0;
my $width=168.78;  # width & height
my $skipToTree = 1;  # In NL files skip all the way to the tree section
                     # rather than checking contour info.

@ARGV = glob("*") unless @ARGV;
for(my $i=0;$i<@ARGV;$i++){
	if(-d $ARGV[$i]) {
		print STDERR "Expanding to contents of directory $ARGV[$i]\n" if $verbose;	
		@ARGV =(@ARGV, glob("$ARGV[$i]/*") ) ;
	}
}

local $/=undef;
while (<>) {
	# skip if this isn't a file we want
	next unless $ARGV=~/a(m|sc)$/i;
	print "Checking $ARGV\n" if $verbose;	
	my $statResult=(stat $ARGV)[9];	
	my $mtime= strftime("%Y-%m-%d %H:%M:%S %Z",(localtime $statResult)[0..5]),"\n";
	
	# get rid of any carriage returns and then split
	# nb will work for DOS and UNIX files but not mac
	s/\r//;	
	my @lines=split(/\n/);
	
	my $suspectCoords=0;
	my $ERRCount=0;
	my ($positiveZ,$negativeZ)=(0,0);
	my $treeCount=0; # count the number of discrete tree objects
	if($lines[0]=~/amiramesh/i){
		# amira format
		my $point1Count=0;		
		my ($nLines,$nEdges,$nVertices) = (0,0,0);		
		my $dataBlock=0; # counter for which datablock we're in
		
		foreach (@lines){
			if(/amiramesh.+binary/i){
				print "$ARGV : AmiraMesh file in BINARY Format (unsupported as yet - please resave as ASCII)\n";				
				last;				
			}
			# increment data block for each data block we encounter
			if(/^\s*\@\d+/) {
				$dataBlock++;
			}
			if(/^\s*0\.1\s*$/) {
				# 0.1 seems to be default Radius
				$point1Count++;				
			}
			
			# get number of lines
			# note I'm countin on \d+ being greedy
			if(!($dataBlock) &&
					( /define\s+Lines\s+(\d+)$/ || /define\s+Lines\s+(\d+)/ )) {
				$nLines=$1;
			}
			if ( $dataBlock && /^[^#]*(ERR|NA)/ ) {
			   # we're in a data block and we've come across an ERR or NA
			   $ERRCount++;
		   }
		}
		if ($point1Count>5) {
			print "$ARGV : $point1Count instances of points with radius = 0.1 - probably an error\n"
		}		
	} else {
		# assume asc format
		my $numRegex=qr/([\-+.0-9]+)/;		
		my $coordRegex=qr/^\s*\(\s*$numRegex\s+$numRegex\s+$numRegex/;
		
		foreach (@lines){
			# nb note the use of ^[^;]* to ensure this is not a comment
			# line
			if (/\(Dendrite\)/ || /\(Axon\)/ ) {
				$treeCount++;
			}
			next if ($skipToTree && !$treeCount);			
			
			if( /^[^;]*\)\s*\;\s*Root/ ){
				# this is the root line
				if ( /\s+[.0]+\s+[.0-9]+\s*\)/ ){
					#	if (/\s+[.0]+\s+[.0-9]+\s*\)\s*\;\s*Root/) {
					# print "zero root\n";		
#				} else {
#					/\s+([\-+.0-9]+)\s+[.0-9]+\s*\)\s*;\s*Root/;
#					print "$ARGV ($mtime) : root starts at Z pos $1\n";
				} elsif ( /\s+([+.0-9]+)\s+[.0-9]+\s*\)\s*;\s*Root/ ) {
#					print "$ARGV ($mtime) : root starts at positive Z pos $1\n";
				}
			} elsif (/$coordRegex/){
			   #just a plain old line with some numbers
			   $positiveZ++ if ($3>0);			   
			   $negativeZ++ if ($3<0);	   
			   
			   if (abs($1)>$width || abs($2)>$width){
				   $suspectCoords++;
				   print "$ARGV (Suspect Coord):",$_,"\n" if ($verbose);
			   }
		   } elsif ( /^[^;]*(ERR|NA)/ ) {
			   $ERRCount++;   
		   }
		   
		   	
	   } # end of processing lines of this file
   } # end of if amira / else 

   print "$ARGV ($mtime) : $treeCount separate tree objects\n" if($treeCount>1);   
   
   if($suspectCoords){
	   print "$ARGV ($mtime) : $suspectCoords suspect coords\n";   
   }
   if($ERRCount){
	   print "$ARGV ($mtime) : $ERRCount ERR or NA coords\n";   
   }
   #print "$ARGV ($mtime) : $negativeZ -ve coords!\n";   

   if($positiveZ && $negativeZ) {
	   print "$ARGV ($mtime) : BOTH $positiveZ +ve coords AND $negativeZ -ve coords!\n";   
   }
}
