#!/usr/bin/perl
# findSubTrees.pl

# perl script to find the sub trees in a skeletonize 
# format neuron
# unfinished - was a bit of a time drain!


my $inFile=$ARGV[0];

die "Can't open $inFile \: $!\n"  unless open(INFILE, "<$inFile");
my @lines = <INFILE>;

close(INFILE);

my @VertexDefinitions=grep {/^\s*(Vertices|EdgeData)\s*{.*}\s*={0,1}\s*@\d+\s*$/} @lines;

my @NeighbourListDef=grep {/NeighbourList/} @VertexDefinitions;		
my $NeighbourListAtNum=0; # amira mesh defines each var by @1, @2 etc.
if($NeighbourListDef[0]=~/.*\@(\d+)\s*$/) {
	$NeighbourListAtNum=$1; 
	print STDERR "NeighbourListAtNum = $NeighbourListAtNum\n";	
}
my @NeighbourCount=grep {/NeighbourCount/} @VertexDefinitions;		
if($NeighbourCount[0]=~/.*\@(\d+)\s*$/) {
	$NeighbourCountAtNum=$1; 
	print STDERR "NeighbourCountAtNum = $NeighbourCountAtNum\n";	
}


my ($nVertices,$nEdges)=(0,0);
foreach (@lines[0..10]){
	$nVertices=$1 if(/nVertices\s+(\d+)/) ;	
	$nEdges=$1 if(/nEdges\s+(\d+)/) ;	
}

print "nVertices=$nVertices, nEdges=$nEdges\n";
#print join("",@lines[0..20]),"\n----\n";

my $i=0;
my ($NeighbourCountStart,$NeighbourListStart)=(0,0);

foreach (@lines){
	$i++;
	$NeighbourCountStart=$i if (/\@$NeighbourCountAtNum/) ;	
#	$NeighbourCountStart=$i if (/\@4/) ;	
	$NeighbourListStart=$i if (/\@$NeighbourListAtNum/) ;		
}

#my $NeighbourCountStart=${"@$NeighbourCountAtNum"};
#$NeighbourCountStart=${"hello"};

#my $NeighbourListStart=${"@$NeighbourListAtNum"};

print "$NeighbourCountStart, $NeighbourListStart \n";
#print join(@lines[0..20],"");
#print "Hello:",($NeighbourListStart+1),"..",($NeighbourListStart+1+$nEdges),"\n";


my @NeighbourCounts=@lines[($NeighbourCountStart+1)..($NeighbourCountStart+$nVertices)];
@NeighbourCounts=grep {chomp} @NeighbourCounts;
my @NeighbourList=@lines[($NeighbourListStart+1)..($NeighbourListStart+$nEdges)];
@NeighbourList=grep {chomp} @NeighbourList;

my %NeighboursFromPoint;
my $pos=0;

print "$#NeighbourCounts = ",$#NeighbourCounts,"\n"; 
$i=0;

for(;$i<($#NeighbourCounts);){
	$NeighboursFromPoint{"$i"}=@NeighbourList[$pos..($pos+$NeighbourCount[$i])];		
	$pos+=$NeighbourCount[$i++];
	print $NeighboursFromPoint{"$i"},",";
}

print "Finished!\n";


sub unique {
	my @list=shift;
	%seen = ();
	@uniqu = grep { ! $seen{$_} ++ } @list;
}

         

#print join(" ",@NeighbourList);
#print "\n","-"x5,"\n";

#print join(" ",@NeighbourCounts);

