#!/usr/bin/env python
import cgi, os, sys, time
import cgitb; cgitb.enable(display=0,logdir="output/")

form = cgi.FieldStorage()
compilerdir = '/home/vagrant/Bodylight.js-FMU-Compiler/input/'

# Generator to buffer file chunks
def fbuffer(f, chunk_size=10000):
    while True:
        chunk = f.read(chunk_size)
        if not chunk: break
        yield chunk

def waitfor(filename,timeout):
    stopcheck = false
    timer = 0
    while (not stopcheck):
        time.sleep(5)
        timer+=5
        stopcheck = os.path.exists(compilerdir+filename) || (timer > timeout)
        print('... '+timer)
    if (os.path.exists(compilerdir+filename):
        print(filename+' detected.')
    else:
        print('After timeout no '+filename+' appeared. Check configuration,logs.');


# A nested FieldStorage instance holds the file
fileitem = form['file']


# Test if the file was uploaded
if fileitem.filename:

    # strip leading path from file name to avoid directory traversal attacks
    fn = os.path.basename(fileitem.filename)
    f = open(compilerdir + fn, 'wb', 10000)

    # Read the file in chunks
    for chunk in fbuffer(fileitem.file):
      f.write(chunk)
    f.close()
    message = 'The file "' + fn + '" was uploaded successfully'

    print("Content-type: text/plain\r\n\r\n")
    print(message)
    sys.stdout.flush()

    time.sleep(3)
    print("converting FMU -> JS")
    sys.stdout.flush()

    fnname,fnext = os.path.splitext(fn)

    fnnamelog = fnname + '.log'
    fnnamezip = fnname + '.zip'

    waitfor(fnamelog,30)
    waitfor(fnamezip,60)
    if (os.path.exists(compilerdir+fnamezip)):
        print('FMU Compiler successfull, download result from http://localhost:8080/compiler/output')
    else:
        print('failed. See logs')

else:
    message = 'No file was uploaded'

