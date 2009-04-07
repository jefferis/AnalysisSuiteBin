#!/usr/bin/perl -w
# callmunger.pl
# script to call one of the average programs from Platypus app

#use strict;
use File::Spec;
use File::Basename;
use Cwd;

# Autoflush stdout
$|=1;

$BundleDir=$ARGV[0];

$RsrcDir="$BundleDir/Contents/Resources";
$CD="\"$BundleDir/../CocoaDialog.app/Contents/MacOS/CocoaDialog\"";

$app="average_grey";
$fullapp="\"$RsrcDir/$app\"";

$ADM_MAINARGS="\"--verbose --cubic \"";
$GREY_MAINARGS="\" --normalize --verbose --cubic \"";
$MAINARGS="";
$EXTRAARGS="";
		
die `$CD ok-msgbox --float --text  "Please Drag and Drop the files to average"\\
	--informative-text "Select the correct .list registration directories and drag them onto the Average.app icon.  Be careful not to move the registration files around." ` unless @ARGV>1;


my @images=@ARGV[1..$#ARGV];
my $imagelist="\"".join("\" \"",@images)."\"";
#print "$imagelist\n";

my $rootDir=findRootDir($images[0]);
chdir($rootDir) or die "Can't change directory: $!";
print "New working directory is: $rootDir \n";	

# 1) Select program to use (drop down)
my ($button, $item)=("",-1);
do{
	$rv=`$CD dropdown --string-output --title Program --text  "Please choose the averaging program"\\
	  --items "average_grey" "avg_adm" "average_images" --button1 "OK" --button2 "Help" --button3 "Cancel"`;  
	($button, $item) = split /\n/, $rv;

	if ($button eq "OK") {
		$app="$item";	
	} elsif ($button eq "Help") {
		`$CD ok-msgbox --float --text  "average_grey and avg_adm"\\
			--informative-text "average_grey averages the grey scale value of a set of registered brains.  avg_adm finds the average shape brain for a set of registrations; this is much more time-consuming but may give better registration success." `;
	} else {
		#print "User canceled\n";
		exit -1;				
	}
} while ($button ne "OK");

if($app eq "average_grey"){
	$MAINARGS=$GREY_MAINARGS;
} elsif ($app eq "avg_adm"){
	$MAINARGS=$ADM_MAINARGS;
} else {
	die "Unrecognised main application: $app !";
}

# 2) Choose Output file
my $outfile =`$CD filesave --title --no-newline "Output File" --text  "Please choose the name/location for the new average brain"`;
die "No outfile specified" if $outfile eq "";
$outfile=$outfile.".nrrd" unless($outfile =~m/[.]/);

# 3) Add additional options (also provide help screen)
my ($button2, $term)=(-1,-1);
$fullapp="\"$RsrcDir/$app\"";
do{
	$rv=`$CD inputbox --title "Add Command Line Options" --no-newline \\
		--informative-text "Add command line options such as: \n\t-v for verbose mode\nUse Help button to find out more" \\
		--text $MAINARGS \\
		--button1 "OK" --button2 "Help" --button3 "Cancel" `;	
		
	($button2, $MAINARGS) = split /\n/, $rv, 2;

	if ($button2 == 1) {
		#print "Flags are $MAINARGS\n";
	} elsif ($button2 == 3) {
		print "Cancelling'\n";
		exit -1;
	} else {
		$helptext = `$fullapp -h 2>&1`;	
		$fullcmd="$CD textbox --title \"Help\" --no-newline --informative-text \"Help for $app; use this to select additional command line options\" --text \"$helptext\" --button1 OK";
		$rv = `$fullcmd`;
	}
} while ($button2!=1);

# 4) Run, Test or Cancel
$cmd="$fullapp $MAINARGS $EXTRAARGS -o NRRD:\"$outfile\" $imagelist";
$button=-1;
do{
 	$fullcmd="$CD msgbox --title \"Run\" --no-newline --text \"Run munger.pl, see the Command line or Cancel\" --button1 \"Run\" --button2 \"Command\" --button3 \"Cancel\"";
	$button=`$fullcmd`;	
	
	if ($button == 1) {
		print "Running: $cmd\n";
		makeCommandFile($rootDir,$outfile);
		print `$cmd`;
		# print `gzip -f -9 \"$outfile/image.bin\"`;		
	} elsif ($button == 3) {
		print "Cancelling'\n";
		exit -1;
	} else {
		$fullcmd="$CD textbox --title \"Help\" --no-newline --informative-text \"The full command line that is about to be run - use this in your own shell scripts if you want\" --text \"$cmd\" --button1 OK";
		$rv = `$fullcmd`;
	}
	
} while ($button!=1);

sub makeCommandFile{
	# Make a .command file that can be used to rerun the average
	my ($rootDir,$outfile)=@_;
	use POSIX qw(strftime);
	my $mtime= strftime("%Y-%m-%d %H:%M:%S %Z",localtime );
	my $outdir=basename($outfile);
	mkdir "$outdir";
	open CMD, "> $outfile-average.command";	
	print CMD "#!/bin/sh\n# $mtime\n cd \"$rootDir\"\n $cmd";
	chmod 0755, "$outfile-average.command";	
}

sub findRootDir {
	# returns the root directory for a working tree
	# by looking for the dir which has an images subdirectory
	# or returning the original path if no luck
	my $fullpath=shift;	

	# nb it is necesary to convert the directory specification
	# to an absolute path to ensure that the open in &readheader
	# works properly during multi directory traversal
	# since vesalius doesn't have an up to date File::Spec module
	# have to make my own
	if(!File::Spec->file_name_is_absolute($fullpath)){
		my $curDir=cwd();
		$rootDir=File::Spec->catdir($curDir,File::Spec->canonpath($fullpath));
	} else {
		$rootDir=File::Spec->canonpath($fullpath);
	}

	my $partialpath=$rootDir;
	
	while ($partialpath ne "/"){
		# Chop off the last directory in the path we are checking
		$partialpath=dirname($partialpath);
		# check if we have a dir called images
		last if (-d File::Spec->catdir($partialpath,"images"));
	}
	# if we have a valid partial path, return that, else return what we were given
	return ($partialpath eq "/"?$fullpath:$partialpath);	
}
