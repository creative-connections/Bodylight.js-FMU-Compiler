#!/usr/bin/env python
import sys
import cgi, os, sys, time
import cgitb; cgitb.enable(display=0,logdir="home/vagrant/Bodylight.js-FMU-Compiler/output/")

form = cgi.FieldStorage()
compilerdir = '/home/vagrant/Bodylight.js-FMU-Compiler/input/'
outputdir = '/home/vagrant/Bodylight.js-FMU-Compiler/output/'

def emsdkRunning():
    '''
    Check if there is any running process that contains the given name processName.
    '''
    import os
    stream = os.popen('ps -axf|grep emsdk|wc -l') #counts processes with emsdk in command line should be 1 or more (1 including grep)
    output = stream.read()
    num_emsdk_process = int(output);

    return num_emsdk_process > 1

# Generator to buffer file chunks
def fbuffer(f, chunk_size=10000):
    while True:
        chunk = f.read(chunk_size)
        if not chunk: break
        yield chunk

def waitfor(filename,timeout=600):
    stop_check = False
    timer = 0
    step = 30
    #waits until ZIP appeared or timeout is reached
    while not stop_check:
        time.sleep(step)
        timer+=step
        stop_check = os.path.exists(outputdir+filename) or (timer > timeout) or (not emsdkRunning())
        #TODO check process names whether it is still running
        #or (not(checkIfProcessRunning('openmodelica.sh')) or not(checkIfProcessRunning('dymola.sh')))
        print('... '+str(timer)+' <br/>')
        sys.stdout.flush()

    if (os.path.exists(outputdir+filename)):
        print(filename + ' detected. <br/>')

    else:
        if (emsdkRunning()):
            print('After timeout no '+filename+' appeared. EMSCRIPTEN still running. Check logs. <br/>')
        else:
            print('After timeout no '+filename+' appeared. EMSCRIPTEN stopped. Check logs to see reason. <br/>')
    sys.stdout.flush()


# A nested FieldStorage instance holds the file
fileitem = form['file']
# Test if the file was uploaded
if fileitem.filename:
    # strip leading path from file name to avoid directory traversal attacks
    fn = os.path.basename(fileitem.filename)
    fnname,fnext = os.path.splitext(fn)
    fnamelog = fnname + '.log'
    fnamezip = fnname + '.zip'
    #remove zip file first
    if os.path.exists(outputdir+fnamezip):
        os.remove(outputdir+fnamezip)
    #open file for writing from upload request
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

    waitfor(fnamelog,30) #30 seconds for log to appear
    counter = 0
    while True:
        waitfor(fnamezip,1200) # 20 minutes wait for ZIP with JS
        counter = counter + 1
        if (os.path.exists(outputdir+fnamezip)):
            break
        if not (emsdkRunning()): # the translation is not running
            break
        if counter>=6:  #after 6 iteration = 120 minutes
            break
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

