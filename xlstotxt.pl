#!/usr/bin/perl -w

# xlstotxt.pl
# 2005-02-02
# Script to convert an excel spreadsheet to a tab delimited txt file
use strict;
use Spreadsheet::ParseExcel;

my $oExcel = new Spreadsheet::ParseExcel;

# 2005-02-07 turned off quotes
my $quote=""; # qw/"/;
my $delim = "\t";
my $suffix = ".txt";

die "You must provide a filename to $0 to be parsed as an Excel file" unless @ARGV;
my $fileStem=$ARGV[0];
# trim terminal . suffix
$fileStem=~s/\.[^\.]*$//;

my $oBook = $oExcel->Parse($ARGV[0]);
die "Cannot parse Excel file $ARGV[0]\n" if not ( $oBook->{File});

my $outFile=(defined $ARGV[1])?$ARGV[1]:$fileStem.$suffix;
if($outFile eq "-") {
	#OUTFILE=STDERR;	
} else {
	die "could not create output file $outFile" unless open(STDOUT, ">$outFile");	
}

my($iR, $iC, $oWkS, $oWkC);
print STDERR "FILE  :", $oBook->{File} , "\n";
print STDERR "SHEET COUNT :", $oBook->{SheetCount} , "\n";
print STDERR "AUTHOR :", $oBook->{Author} , "\n"
 if defined $oBook->{Author}; 

for(my $iSheet=0; $iSheet < $oBook->{SheetCount} ; $iSheet++)
{
	$oWkS = $oBook->{Worksheet}[$iSheet];
	# skip this sheet if it's not what we're after
	next if($oWkS->{Name} ne "AllWarpedImageNotes") ; 
 
	# note the sheet name to stderr
	print STDERR "--------- SHEET:", $oWkS->{Name}, "\n";
	
	for(my $iR = $oWkS->{MinRow} ; defined $oWkS->{MaxRow} && $iR <= $oWkS->{MaxRow} ; $iR++)
	{
		for(my $iC = $oWkS->{MinCol} ;
			defined $oWkS->{MaxCol} && $iC <= $oWkS->{MaxCol} ;
			$iC++)
		{
			$oWkC = $oWkS->{Cells}[$iR][$iC];
			#print "( $iR , $iC ) =>", $oWkC->Value, "\n" if($oWkC);
			if($oWkC) {
				# this cell contains something
				print STDOUT $quote,$oWkC->Value,$quote;
			} else {
				# empty cell
				print STDOUT $quote x 2;				
			}
			# if this isn't the last cell in the row print a tab
			if ($iC < $oWkS->{MaxCol}) {
				print STDOUT $delim;				
			}
		}
		print STDOUT "\n";		
	}
}
