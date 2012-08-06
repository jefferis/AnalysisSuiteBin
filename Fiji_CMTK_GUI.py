import fiji.util.gui.GenericDialogPlus
from java.awt.event import TextListener

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
    Make a shell script file that can be used to rerun the warp action
    
    Because the file is executable and ends in .command it can be 
    double clicked on MacOS X
    '''
    if not os.path.exists(outdir): os.mkdir(outdir)
    mtime = time.strftime('%Y-%m-%d_%H.%M.%S')
    filename= "munger_%s.command" %(mtime)
    filepath=os.path.join(outdir,filename)
    f = open(filepath, 'w')
    f.write('#!/bin/sh\n# %s\ncd \"%s"\n%s' % (mtime, rootdir, cmd))
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
		if os.path.exists(imgdir):
			imgdirf.setText(imgdir)
			imgdirf.setForeground(Color.black)
			return
		imgdirf.setForeground(Color.red)

class ImageDirListener(TextListener):
	def textValueChanged(self, tvc):
		regroot = regrootf.getText()
		if len(regroot)>0 & os.path.exists(regroot):
			#print "regroot:"+regroot+ " exists!" 
			return
		imgdir = imgdirf.getText()
		if os.path.exists(imgdir):
			regrootf.setText(os.path.dirname(imgdir))
			return

class OuputSuffixListener(TextListener):
	def textValueChanged(self, tvc):
		updateOuputFolders()


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
munger=findExecutable('munger.pl')

# path to munger.pl script
gd.addHelp("http://flybrain.mrc-lmb.cam.ac.uk/dokuwiki/doku.php?id=warping_manual:registration_gui")
gd.addDirectoryField("Registration Folder:",None)
regrootf = gd.getStringFields().get(0)
# reference brain
gd.addFileField("Reference Brain", "")
# input directory/image
gd.addDirectoryOrFileField("Input Image or Image Directory:",None)
imgdirf = gd.getStringFields().get(2)

# what to do: affine/warp/reformat
gd.addCheckboxGroup(3,2,["affine","01","warp","02","reformat","03"],[True,True,True,True,True,True],["Registration Actions","Reformat Channels"])
#gd.addCheckboxGroup(1,3,["01","02","03"],[True,True,True],["Reformat Channels"])

gd.addStringField("Output folder suffix","")
outsuffixf = gd.getStringFields().get(3)
gd.addMessage("Output folders:")
outputf=gd.getMessage()

# Registration options 
# Jefferis,Potter 2007, Cachero,Ostrovsky 2010, Manual
gd.addChoice("Registration Params:",["Jefferis, Potter 2007","Cachero, Ostrovsky 2010","Full Manual"],"Cachero, Ostrovsky 2010")
gd.addStringField("(Further) Registration Params: ","");
gd.addStringField("(Further) Arguments to Munger: ","");

# final Action (Test, Run, Write Script)
gd.addChoice("Action:",["Test","Run","Write Script"],"Test")

regrootf.addTextListener(RegRootListener())
imgdirf.addTextListener(ImageDirListener())
outsuffixf.addTextListener(OuputSuffixListener())
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

outsuffix=gd.getNextString()
regparams=gd.getNextChoice()
print regparams
regparams=gd.getNextString()
mungeropts=gd.getNextString()
action=gd.getNextChoice()

if action == 'Test': mungeropts+=' -t'

cmd='"%s" -b "%s" %s %s %s -s "%s" %s' % (munger,bindir,munger_actions,regparams,mungeropts,refBrain,image)
print cmd
# always make a script
script=makescript(cmd,rootDir,outdir=os.path.join(rootDir,'commands'))

if action != 'Write Script':
	# Actually run the script    
	subprocess.call(script,shell=True)
