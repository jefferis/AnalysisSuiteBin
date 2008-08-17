#!/usr/bin/perl 

# program to find the linked files inside an Adobe Illustrator file
require 5.004;
use File::Basename;   # to extract a filename from a full path
use File::Find;       # to build a list of files
use File::Spec;       # Platform independent way to build paths
use vars qw/ %opt /;  # for command line options - see init()
use strict;


init(); # process command line options

# Autoflush stdout
$|=1;

if ($opt{p}){
	die "Did you really mean to call your script ".$opt{p}."!\n" if($opt{p} =~ /\.ai$/i);	
	print "Generating script file $opt{p}\n" if $opt{v};
	open SCRIPT, "> $opt{p}";	
}

die "No input specified; use ".basename($0)." -h for help\n" if(@ARGV==0);
my $arg; foreach $arg (@ARGV){
	if(-d $arg){
		# nb it is necesary to convert the directory specification
		# to an absolute path to ensure that the open in &findLinkedFiles
		# works properly during multi directory traversal
		my $InDir=File::Spec->rel2abs($arg);	
		find(\&handleFind,$InDir);	
	} elsif (-f $arg) {
	my $InDir=File::Spec->rel2abs(dirname($ARGV[0]));	
	 	&findLinkedFiles(File::Spec->rel2abs($ARGV[0]),$InDir) ;
#			&findLinkedFiles(File::Spec->rel2abs($arg)) ;
	}
}

sub init()
# copied from: http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/getopts
{
	use Getopt::Std;      # to handle command line options
	my $opt_string = 'hvlzdsftnp:ux:';
	getopts( "$opt_string", \%opt ) or usage();
	usage() if $opt{h};
}

# Print out usage information
sub usage()
{
	print STDERR << "EOF"; 
Usage: $0 [OPTIONS] <AIFILE/DIR>

Parse an Adobe Illustrator file or (recursively) parse a directory of ai files
and print a list of the linked files to STDOUT.  These could be piped to xargs eg:
$0 aifile.ai | xargs -I {} ln -vs

	-h print this help
	-v verbose ouput
	-s print file names with short path
	-d print current directory on each line
	-n no-print (suppresses printing of linked file names)
	-x <regex> exclude files whose full path matches regex 
		
	-l symlink in current directory if file linked from Illustrator file exists somewhere else
	-f force symlink to overwrite existing target file
	-t test run
	-p <file> write commands to a script file

	-u status of src and target
		- doesn't exist
		F plain file
		L symbolic link
		E exists (unknown file type)
		
	Note that src is the link contained in the Illustrator file and
	target is a file of the same name in the same directory as the Illustrator file
		
	If the status is -- you will have problems in Illustrator
	If the status is -F Illustrator will substitute the local file for the unavailable linked file
	If the status is F- you can run this script with the -s option to make a symlink 
	If the status is FF then Illustrator will be happy	
		
EOF
	exit();  
}

sub mysymlink{
	my ($src,$targetdir)=@_;
	my $target=File::Spec->catdir($targetdir,basename($src));	

	if(File::Spec->rel2abs($src) eq File::Spec->rel2abs($target)){
		print "src and target identical for src=$src\n" if $opt{v};		
		return;		
	}
	
	if(-e $src){
		my $opts=$opt{f}?"-fsv":"-sv";		
		my $cmd="ln $opts \"$src\" \"$target\"";			
		myexec("$cmd");
	} else {
		print "No link made: $src doesn't exist\n" if $opt{v};
	}
}
sub myexec {
	my ($cmd) = @_;	
	if ($opt{t}){
		print STDERR "test: $cmd\n";
	} 	elsif ($opt{p}){
		print SCRIPT $cmd,"\n";
	} 	else {
		# should get to see output with system
		print STDERR "run: $cmd\n" if $opt{v};	
		return system $cmd;		
	}
}

sub mystatus{
	my ($src,$targetdir)=@_;
	my $target=File::Spec->catdir($targetdir,basename($src));	
	
	my ($ss,$ts)=("-","-");	
	
	$ss = "E" if(-e $src);
	$ss = "F" if(-f $src);	
	$ss = "L" if(-l $src);
	$ts = "E" if(-e $target);
	$ts = "F" if(-f $target);	
	$ts = "L" if(-l $target);
	return ($ss.$ts);
}

# This extracts the file info from the header
sub handleFind{
	# get the file name
	my $FullFoundFile = $File::Find::name;
	#print $FullFoundFile,"\n";
	
	return if ($opt{x} and $FullFoundFile =~ /$opt{x}/i);	
	
	# parse if it ends in ai
	findLinkedFiles($FullFoundFile, $File::Find::dir) if ($FullFoundFile =~ /\.ai$/i);
}


# This does the actual parsing of the Illustrator Files
sub findLinkedFiles{
	my ($InFile,$InDir)=@_; 
	
	# protect with escaped quotes for shell if non-empty
	my $ProtectedInDir=$InDir?"\"$InDir\"":$InDir;	
	
	die "Can't open $InFile \: $!\n"  unless open(AIFILE, "<$InFile");
	binmode(AIFILE);

	# %%DocumentFiles is the starting point	
	$/="%%";	
	my @lines = readline<AIFILE>;	
	
	if(@lines==0){
		print STDERR "can't read header of $InFile\n" if $opt{v} ; # the header length
		return;			
	}
	
	print "################\n";	
	
	if ($opt{s}){
		print "# FILE = ",basename($InFile),"\n";		
	} else {
		print "# FILE = ",$InFile,"\n";	
	}
	for my $i ( 0 .. $#lines ){		
#		if ( $lines[$i]=~/^DocumentFiles\:(.*?)\W+%%/){
# not sure why we need two % signs here
		if ( $lines[$i]=~/^DocumentFiles\:(.*?)\W+%/){
			print mystatus($1,$InDir)," " if $opt{u} and not $opt{n};
			print "\"$1\" ",$opt{d}?$ProtectedInDir:"","\n" unless $opt{n};
			$i++;
			mysymlink($1,$InDir) if $opt{l};
			while($lines[$i]=~/^[+](.*?)\W\%.*$/){
#				print "\"$1\" $InDir\n"; $i++;			
				print mystatus($1,$InDir)," " if $opt{u} and not $opt{n};
				print "\"$1\" ",$opt{d}?$ProtectedInDir:"","\n"unless $opt{n};
				$i++;
				mysymlink($1,$InDir) if $opt{l};					
			}
			
		}
	}	
}
