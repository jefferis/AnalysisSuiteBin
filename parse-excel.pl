#!/usr/bin/perl -w

use strict;
use Spreadsheet::ParseExcel;

my $oExcel = new Spreadsheet::ParseExcel;

die "You must provide a filename to $0 to be parsed as an Excel file" unless @ARGV;

my $oBook = $oExcel->Parse($ARGV[0]);
my($iR, $iC, $oWkS, $oWkC);
print STDERR "FILE  :", $oBook->{File} , "\n";
print STDERR "COUNT :", $oBook->{SheetCount} , "\n";

print STDERR "AUTHOR:", $oBook->{Author} , "\n"
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
				print '"',$oWkC->Value,'"';
			} else {
				# empty cell
				print '""';				
			}
			if ($iC < $oWkS->{MaxCol}) {
				print "\t";				
			}
		}
		print "\n";		
	}
}
