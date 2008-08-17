#!/usr/bin/perl

# htmltotxt.pl
# quick and dirty script to munge an html file containing a table
# to a tab delimited text file

require 5.004;
#use strict;

if (!defined($ARGV[0])){
	die "no input specified\n";
} else {
	$file = $ARGV[0];
	die "could not open $file" unless open(HTMLFILE, $file);
	local $/ =undef;	
	$htmldata = <HTMLFILE>;
	close(HTMLFILE);
	# remove the head of the file
	$htmldata=~s/^.*<table[^>]*>//;
	# remove anything up to the first table entry
	# don't be greedy
	$htmldata=~s/^.*?<t/<t/;	
	
	
	# remove the tail of the file
	$htmldata=~s/<\/table.*//;	
	
	# remove all newlines or tabs
	$htmldata=~s/\n//g;	
	$htmldata=~s/\r//g;	
	$htmldata=~s/\t//g;	
	
	# remove all consecutive whitespace that isn't between
	# open and close html tags
	$htmldata=~s/>\s+(<[^\/])/>$1/g;	

	# replace all <td></td> pairs with tab
	$htmldata=~s/<\/td>\s*<td[^>]*>/\"\t\"/g;
	# replace all remaining td things with ""
	$htmldata=~s/<[\/]*td[^>]*>/\"/g;	
	# replace all </tr> with newlines
	$htmldata=~s/<\/tr>/\n/g;	

	# replace everything else that looks html ish 
	$htmldata=~s/<[^>]+>//g;
	

	print $htmldata;	
}
