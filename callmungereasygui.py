#!/usr/bin/env python

# This script provides a very simple cross-platform GUI for the munger.pl
# script which coordinates registration and reformatting of images using CMTK
# it should run on pretty much any OS including linux/mac/windows

# The prerequisites are:
#   python >= 2.5 
#   easygui.py >= 0.95

# easygui can be downloaded from
# http://easygui.sourceforge.net/
# and installation should be as simple as 
# cd easy_gui        # or whatever the download dir is called
# setup.py install   # you may need sudo setup.py install if root permissions are required

import os, sys, time
import easygui
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
    if not os.path.exists: os.mkdir(outdir)
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
        if msg == '' :
            msg="Locate the program "+execname
        newpath = easygui.fileopenbox(msg=msg)
        return newpath
    else : return execpath

# # the script !
# # --------------------

scriptPath = os.path.join(sys.path[0], sys.argv[0])
print scriptPath

# 0.1) Identify path to CMTK binaries
# see if warp is in path
findExecutable('warp')
bindir=os.path.dirname(findExecutable('warp'))

# 0.1) Identify path to munger.pl script
munger=findExecutable('munger.pl')

# 1) Select input directory/files
image=easygui.diropenbox("Choose the source images directory", 
    "Select Input Directory")
if image == None:
    sys.exit("No image chosen\n")
# if os.path.basename(image) != "images":
#     sys.exit("Images directory must be called images\n")

rootDir=os.path.dirname(image)
print "New working directory is: "+rootDir    
os.chdir(rootDir)

# 2) Choose the reference brain
refBrain = easygui.fileopenbox("Choose the reference brain: this can be a PIC or a nrrd file","Select Reference Brain")
print refBrain
refBrain=relpath(refBrain,rootDir)
print refBrain

# 3) Select additional flags
mungeropts=easygui.enterbox(msg='Please enter the options to be passed to munger', default='-a -w -r 01 -v', strip=True)

# multchoicebox(msg='What actions do you want', title=' ', choices=('affine','warp','reformat'))
# 4) Action
action=easygui.buttonbox(msg='Choose an action', choices=('Test', 'Run', 'Write script','Cancel'))
if action == 'Cancel': sys.exit('script cancelled!')
if action == 'Test': mungeropts+=' -t'
# build munger command line
cmd='"%s" -b "%s" %s -s "%s" .' % (munger,bindir, mungeropts,refBrain)
print cmd
# always make a script
script=makescript(cmd,rootDir,outdir=os.path.join(rootDir,'commands'))

if action != 'Write script':
    # Actually run the script    
    subprocess.call(script,shell=True)

print ("Successfully completed!")
