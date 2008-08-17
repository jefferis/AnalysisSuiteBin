#!/bin/sh
# callmunger.sh
# script to call the munger perl script from Platypus

BundleDir=$1
RsrcDir="$BundleDir/Contents/Resources"
munger="$RsrcDir/munger.pl"
CD="$RsrcDir/CocoaDialog.app/Contents/MacOS/CocoaDialog"


MAINARGS="-awr 01"
EXTRAARGS=""

if [ -n "$2" ]; then
	echo "Using supplied path to start munger with default parameters"
	cmd="$munger -b \"$RsrcDir\" $MAINARGS $EXTRAARGS $2"
	echo $cmd
	$cmd
	exit 0
fi

# else, no files drag and dropped, so use Cocoa Dialog to fetch them

# 1) Select input directory/files
image=`$CD fileselect \
	--title "Select Input Directory"\
	--text "Choose the source image or images directory" \
	--select-directories`
if [ -n "$image" ]; then  ### if $rv has a non-zero length
	echo "Main source: $image"
else
	echo "No source file selected"
	exit -1;
fi
# 2) Ask for additional flags (OK or Help)
rv=`$CD inputbox --title "Add Command Line Options" --no-newline \
	--informative-text "Add command line options such as -a for affine, -w for warp -r 01 to reformat channel 1 and -v for verbose mode" \
	--text "-a -w -r 01 -v" \
	--button1 "OK" --button2 "Cancel" --button3 "Help"`

if [ "$rv" == "1" ]; then
  echo "User likes Macs"
  elif [ "$rv" == "2" ]; then
  echo "User likes Linux"
  elif [ "$rv" == "3" ]; then
  echo "User doesn't care"
  fi

# 3) Run, Test or Cancel

cmd="$munger -b \"$RsrcDir\" $MAINARGS $EXTRAARGS $image"
echo $cmd
$cmd

