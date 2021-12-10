#!/usr/bin/env python
import sys
import cgi, os, sys, time
#import cgitb; cgitb.enable(display=0,logdir="home/vagrant/Bodylight.js-FMU-Compiler/output/")

form = cgi.FieldStorage()
flags = form["optimization"].value + ' ' + form["closure"].value
flagsfile = '/home/vagrant/Bodylight.js-FMU-Compiler/output/flags'
if os.path.exists(flagsfile):
     os.remove(flagsfile)

f = open(flagsfile, 'wt')
f.write(flags)
f.write('\n')
f.close()

#it is cgi script so flush output
print("Content-type: text/html\r\n\r\n")
print('Flags set:')
print(flags)
sys.stdout.flush()



