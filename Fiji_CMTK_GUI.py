import fiji.util.gui.GenericDialogPlus
from java.awt.event import TextListener
from java.awt.event import ItemListener
from java.awt import Font

import os, sys, time
import subprocess

# Function definitions
# --------------------
def relpath(path, basedir = os.curdir):
    ''' @return a relative path from basedir to (sub) path.
    
    basedir defaults to curdir
    Does not work with paths outside basedir
    This is superseded by a builtin in python >=2.6
    '''
    basedir = os.path.abspath(basedir)
    path = os.path.abspath(path)
    
    if basedir == path :
        return '.'
    if basedir in path :
        return path.replace(basedir+'/','')
    return (path)

def makescript(cmd,rootdir,outdir):
    '''
    Make a shell script file that can be used to rerun the warp action, using
    chmod to ensure that it is executable.
    
    On MacOS X the file suffix is command so that it can be double clicked in the Finder.
    '''
    if not os.path.exists(outdir): os.mkdir(outdir)
    mtime = time.strftime('%Y-%m-%d_%H.%M.%S')
    suffix='sh'
    osname=System.getProperty("os.name")
    if "OS X" in osname:
        suffix='command'
    filename= "munger_%s.%s" %(mtime,suffix)
    filepath=os.path.join(outdir,filename)
    f = open(filepath, 'w')
    f.write('#!/bin/sh\n# %s\ncd \"%s"\n%s' % (mtime, rootdir, cmd))
    f.close()
    os.chmod(filepath,0755)
    return filepath

def findExecutable(execname,msg=''):
    '''
    @return full path to a command using the shell's which function
    '''
    execpath=subprocess.Popen(["which", execname], stdout=subprocess.PIPE).communicate()[0].rstrip()
    if execpath == '' :
        gd = fiji.util.gui.GenericDialogPlus(msg)
        if msg == '' :
            msg="Locate the directory containing program "+execname
        gd.addDirectoryField(msg, "")
        gd.showDialog()
        execdir = gd.getNextString()
        execpath = os.path.join(execdir,execname)
        if os.path.exists(execpath) :
            return execpath
        else :
            sys.exit('Unable to locate '+execname+' in directory '+execdir)
    else : return execpath

# helper classes/functions for main generic dialog

class RegRootListener(TextListener):
	def textValueChanged(self, tvc):
		regroot = regrootf.getText()
		if os.path.exists(regroot):
			updateOuputFolders()
		imgdir = os.path.join(regroot,'images')
		if lenos.path.exists(imgdir):
			imgdirf.setText(imgdir)
			imgdirf.setForeground(Color.black)
			statusf.setText('')
			return
		imgdirf.setForeground(Color.red)
		statusf.setText('Please choose input image/directory')
		statusf.setForeground(Color.red)

class ImageDirListener(TextListener):
	def textValueChanged(self, tvc):
		regroot = regrootf.getText()
		if len(regroot)>0 and os.path.exists(regroot):
			#print "regroot:"+regroot+ " exists!" 
			return
		imgdir = imgdirf.getText()
		if os.path.exists(imgdir):
			regrootf.setText(os.path.dirname(imgdir))
			return

class OuputSuffixListener(TextListener):
	def textValueChanged(self, tvc):
		updateOuputFolders()

class RegParamListener(ItemListener):
	def itemStateChanged(self, isc):
		regparamc=choicef.getSelectedItem()
		regparams=''
		if regparamc == 'Cachero, Ostrovsky 2010':
			regparams = "-X 26 -C 8 -G 80 -R 4 -A '--accuracy 0.4' -W '--accuracy 0.4'"
		regparamf.setText(regparams)
		print "Chosen reg params: "+regparamc

def updateOuputFolders():
	outsuffix=outsuffixf.getText()
	if outsuffix:
		reg="Registration."+outsuffix
		ref="reformatted."+outsuffix
	else:
		reg="Registration"
		ref="reformatted"
	outputf.setText("Output Folders: "+reg+", "+ref)
	return

## START!

gd = fiji.util.gui.GenericDialogPlus('CMTK Registration GUI')

# 0.1) Identify path to CMTK binaries
bindir=os.path.dirname(findExecutable('warp'))
print 'bindir is ' + bindir
# 0.1) Identify path to munger.pl script
munger='/Users/jefferis/bin/munger.pl'
#munger=findExecutable('munger.pl')
gd.addHelp("http://flybrain.mrc-lmb.cam.ac.uk/dokuwiki/doku.php?id=warping_manual:registration_gui")

dirFieldWidth=50
gdMargin=130
gd.addDirectoryField("Registration Folder",None,dirFieldWidth)
regrootf = gd.getStringFields().get(0)
# reference brain
gd.addFileField("Reference Brain", "",dirFieldWidth)
# input directory/image
gd.addDirectoryOrFileField("Input Image or Image Directory",None,dirFieldWidth)
imgdirf = gd.getStringFields().get(2)

gd.setInsets(10,gdMargin,10)
gd.addMessage("Output folders:")
outputf=gd.getMessage()

# what to do: affine/warp/reformat
gd.setInsets(10,200,10)
gd.addCheckboxGroup(3,2,["affine","01","warp","02","reformat","03"],[True,True,True,True,True,True],["Registration Actions","Reformat Channels"])
#gd.addCheckboxGroup(1,3,["01","02","03"],[True,True,True],["Reformat Channels"])

# Registration options 
# Jefferis,Potter 2007, Cachero,Ostrovsky 2010, Manual
gd.addChoice("Registration Params",["Jefferis, Potter 2007","Cachero, Ostrovsky 2010"],"Jefferis, Potter 2007")
choicef=gd.getChoices().get(0)
print choicef.getSelectedItem()

# final Action (Test, Run, Write Script)
gd.addChoice("Action",["Test","Write Script","Run"],"Write Script")
font=Font("SansSerif",Font.BOLD,12)

# Advanced options
gd.setInsets(25,100,10)
gd.addMessage("Advanced Options:",font)
advancedoptionsf=gd.getMessage()

ncores=Runtime.getRuntime().availableProcessors()
defaultCores=1
if ncores >=8:
    defaultCores=4
elif ncores>=4:
    defaultCores=2
gd.addSlider("Number of cpu cores to use",1,ncores,defaultCores)

gd.setInsets(0,230,10)
gd.addCheckbox("Verbose log messages",False)

gd.addStringField("Output folder suffix","",20)
outsuffixf = gd.getStringFields().get(3)

gd.addStringField("(Further) Registration Params","",50);
regparamf = gd.getStringFields().get(4)
gd.addStringField("Additional Arguments to munger.pl","",50);

regrootf.addTextListener(RegRootListener())
imgdirf.addTextListener(ImageDirListener())
outsuffixf.addTextListener(OuputSuffixListener())
choicef.addItemListener(RegParamListener())
# used for errors etc
gd.addMessage("Start by choosing a registration directory or images directory!")
statusf=gd.getMessage()
gd.showDialog()
if gd.wasCanceled():
	sys.exit("User cancelled!")
# Process Dialog Choices
rootDir=gd.getNextString()
os.chdir(rootDir)
refBrain=gd.getNextString()
image=gd.getNextString()
image=relpath(image,rootDir)
print refBrain
refBrain=relpath(refBrain,rootDir)
print refBrain

affine=gd.getNextBoolean()
ch01=gd.getNextBoolean()
warp=gd.getNextBoolean()
ch02=gd.getNextBoolean()
reformat=gd.getNextBoolean()
ch03=gd.getNextBoolean()
munger_actions=""
if affine:
	munger_actions+="-a "
if warp:
	munger_actions+="-w "
if reformat:
	channels=''
	if ch01:
		channels+='01'
	if ch02:
		channels+='02'
	if ch03:
		channels+='03'
	if channels != '':
		munger_actions+="-r "+channels+" "

verbose=gd.getNextBoolean()
corestouse=gd.getNextNumber()
outsuffix=gd.getNextString()
regparams=gd.getNextChoice()
print regparams
regparams=gd.getNextString()
mungeropts=gd.getNextString()
action=gd.getNextChoice()

if action == 'Test': mungeropts+=' -t'
if verbose: mungeropts+=' -v'
mungeropts+=' -T %d' % (int(corestouse))

cmd='"%s" -b "%s" %s %s %s -s "%s" %s' % (munger,bindir,munger_actions,regparams,mungeropts,refBrain,image)
print cmd

if action !='Test':
	# make a script
	script=makescript(cmd,rootDir,outdir=os.path.join(rootDir,'commands'))
	print 'script is %s' % (script)
	
	if action != 'Write Script':
		# Actually run the script
		subprocess.call(script,shell=True)
