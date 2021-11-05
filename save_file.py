#!/usr/bin/env python
import sys
import cgi, os, sys, time
import cgitb; cgitb.enable(display=0,logdir="home/vagrant/Bodylight.js-FMU-Compiler/output/")

form = cgi.FieldStorage()
compilerdir = '/home/vagrant/Bodylight.js-FMU-Compiler/input/'
outputdir = '/home/vagrant/Bodylight.js-FMU-Compiler/output/'

def checkIfProcessRunning(processName):
    '''
    Check if there is any running process that contains the given name processName.
    '''
    print('checking process'+processName)
    try:
        import psutil
        #Iterate over the all the running process
        for proc in psutil.process_iter():
            try:
                # Check if process name contains the given name string.
                print(proc.name)
                if processName in proc.name():
                    print ('match'+processName)
                    return True
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                print('some exception')
                pass
    except ImportError:
        print('import error')
        return True
    return False

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
        stop_check = os.path.exists(outputdir+filename) or (timer > timeout)
        #TODO check process names whether it is still running
        #or (not(checkIfProcessRunning('openmodelica.sh')) or not(checkIfProcessRunning('dymola.sh')))
        print('... '+str(timer)+' <br/>')
        sys.stdout.flush()

    if (os.path.exists(outputdir+filename)):
        print(filename + ' detected. <br/>')

    else:
        print('After timeout no '+filename+' appeared. Check logs to see reason. <br/>');
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
    waitfor(fnamezip,1200) # 20 minutes wait for ZIP with JS
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

