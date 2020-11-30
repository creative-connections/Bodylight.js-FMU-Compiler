#!/usr/bin/env python
import sys
import cgi, os, sys, time
import cgitb; cgitb.enable(display=0,logdir="/output/")

form = cgi.FieldStorage()
compilerdir = '/home/vagrant/Bodylight.js-FMU-Compiler/input/'
outputdir = '/home/vagrant/Bodylight.js-FMU-Compiler/output/'
# Generator to buffer file chunks
def fbuffer(f, chunk_size=10000):
    while True:
        chunk = f.read(chunk_size)
        if not chunk: break
        yield chunk

def waitfor(filename,timeout=60):
    stop_check = False
    timer = 0
    while not stop_check:
        time.sleep(5)
        timer+=5
        stop_check = os.path.exists(outputdir+filename) or (timer > timeout)
        print('... '+str(timer)+' <br/>')
        sys.stdout.flush()

    if (os.path.exists(outputdir+filename)):
        print(filename + ' detected. <br/>')

    else:
        print('After timeout no '+filename+' appeared. Check configuration,logs. <br/>');
    sys.stdout.flush()


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

    print("Content-type: text/html\r\n\r\n")
    print(message)
    print('<br/>')
    sys.stdout.flush()

    time.sleep(3)
    print("<html><body>converting FMU -> JS ... <br/>")
    sys.stdout.flush()
    print(sys.version)


    fnname,fnext = os.path.splitext(fn)

    fnamelog = fnname + '.log'
    fnamezip = fnname + '.zip'

    waitfor(fnamelog,30)
    waitfor(fnamezip,120)
    if (os.path.exists(outputdir+fnamezip)):
        print('FMU Compiler successfull<br/ >Download result: <a href="/compiler/output/'+fnamezip+'">/compiler/output/'+fnamezip+'</a>')
    else:
        print('failed. See logs')
    print('<br/>All results and logs:<a href="/compiler/output/">/compiler/output/</a>')

else:
    message = 'No file was uploaded'
    print("Content-type: text/html\r\n\r\n")
    print(message)
    print('<br/>')
    sys.stdout.flush()

