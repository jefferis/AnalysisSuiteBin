#!/usr/bin/perl -w
# callmunger.pl
# script to call the munger perl script from Platypus app

#use strict;
use File::Spec;
use File::Basename;
use Cwd;

$BundleDir=$ARGV[0];
print STDERR "BundleDir is $BundleDir\n";
$RsrcDir="$BundleDir/Contents/Resources";
$munger="\"$RsrcDir/munger.pl\"";
$CD="\"$BundleDir/../CocoaDialog.app/Contents/MacOS/CocoaDialog\"";

$MAINARGS="-awr 01 -v ";
$EXTRAARGS="";

$image=exists($ARGV[1])?$ARGV[1]:"";

if($image ne ""){
	my $rootDir=findRootDir($image);
	chdir($rootDir) or die "Can't change directory: $!";
	print "New working directory is: $rootDir \n";	
	$image=File::Spec->abs2rel( $image, $rootDir );	

	$cmd="$munger -b \"$RsrcDir\" $MAINARGS $EXTRAARGS \"$image\"";
	print "Using supplied path to start munger with default parameters\n$cmd\n";	
	print `$cmd`;	
	exit 0;		
}


# else, no files drag and dropped, so use Cocoa Dialog to fetch them
# print "Starting Cocoa Dialog!\n";

# 1) Select input directory/files
$image=`$CD fileselect \\
	--title "Select Input Directory"\\
	--text "Choose the source image or images directory" \\
	--select-directories --no-newline`;	
# This a belt and braces chomp because apparently CocoaDialog
# sometimes fails to chomp enough
$image =~ s/(\r|\n)//g;
die "Image file or directory $image does not exist\n" unless -e $image;

my $rootDir=findRootDir($image);
chdir($rootDir) or die "Can't change directory: $!";
print "New working directory is: $rootDir \n";	
$image=File::Spec->abs2rel( $image, $rootDir );	

# 2 Do you want to use the default reference brain?
$rv=`$CD yesno-msgbox --no-cancel --string-output \\
	--text "Reference Brain" \\
	--informative-text "Do you want to use the default reference brain?" \\
		--no-newline --float`;		
exit -1 if $rv eq "Cancel";
if($rv eq "No")	{
	# choose the ref brain
	$refBrain=`$CD fileselect \\
	--title "Select Reference Brain"\\
	--text "Choose the reference brain.  This can be a plain image file (eg PIC) or the .study directory containing an image in IGS format " \\
	--select-directories --no-newline`;	
	die "Chosen reference brain $refBrain does not exist\n" unless -e $refBrain;	
	print "Ref Brain is $refBrain\n";	
	$refBrain=File::Spec->abs2rel( $refBrain, $rootDir );	
	$EXTRAARGS.="-s \"$refBrain\"";
}


# 3) Ask for additional flags (OK or Help)

my ($button_rv, $term)=(-1,-1);

do{
	$rv=`$CD inputbox --title "Add Command Line Options" --no-newline \\
		--informative-text "Add command line options such as: \n\t-a for affine\n\t-w for warp\n\t-r 01 to reformat channel 1\n\t-v for verbose mode\n\t-t for test mode" \\
		--text "-awr 01 -v -t" \\
		--button1 "OK" --button2 "Help" --button3 "Cancel" `;	

	($button_rv, $MAINARGS) = split /\n/, $rv, 2;

	if ($button_rv == 1) {
		#print "Flags are $MAINARGS\n";
	} elsif ($button_rv == 3) {
		print "Cancelling'\n";
		exit -1;
	} else {
		$helptext = `$munger -h`;	
		$fullcmd="$CD textbox --title \"Help\" --no-newline --informative-text \"Help for munger.pl; use this to select additional command line options\" --text \"$helptext\" --button1 OK";
		$rv = `$fullcmd`;
	}
} while ($button_rv!=1);

# 3) Run, Test or Cancel
$cmd="$munger -b \"$RsrcDir\" $MAINARGS $EXTRAARGS \"$image\"";
$button_rv=-1;
do{
 	$fullcmd="$CD msgbox --title \"Run\" --no-newline --text \"Run munger.pl, see the Command line or Cancel\" --button1 \"Run\" --button2 \"Command\" --button3 \"Cancel\"";
	$button_rv=`$fullcmd`;	
	#print "button_rv=$button_rv\n";	
	
	if ($button_rv == 1) {
		print "Running: $cmd\n";
		makeCommandFile($rootDir,"$rootDir/commands");
		print `$cmd`;
	} elsif ($button_rv == 3) {
		print "Cancelling'\n";
		exit -1;
	} else {
		$fullcmd="$CD textbox --title \"Help\" --no-newline --informative-text \"The full command line that is about to be run - use this in your own shell scripts if you want\" --text \"$cmd\" --button1 OK --button2 Save";
		$rv = `$fullcmd`;
		if($rv==2){
			# save the command
			my $cmdfile =`$CD fileselect --title --no-newline "Command File" --text  "Please choose the directory in which the command file will be saved" --select-only-directories`;
			makeCommandFile($rootDir,$cmdfile) if $cmdfile ne "";
		}
	}
	
} while ($button_rv!=1);


sub makeCommandFile{
	# Make a .command file that can be used to rerun the average
	my ($rootDir,$outdir)=@_;	
	use POSIX qw(strftime);
	my $mtime= strftime("%Y-%m-%d %H:%M:%S %Z",localtime );		
	my $mtime2= strftime("%Y-%m-%d_%H.%M.%S",localtime );		

	mkdir "$outdir";
	my $filename="munger_${mtime2}.command";	
	open CMD, "> $outdir/$filename";	
	print CMD "#!/bin/sh\n# $mtime\n cd \"$rootDir\"\n $cmd";
	chmod 0755, "$outdir/$filename";	
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
