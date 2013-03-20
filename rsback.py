#!/usr/bin/python

import os
import datetime
import subprocess
import shlex
import glob
import operator
import sys
from optparse import OptionParser
import time
import shutil

volumeInfo = [
#   { 'host':'bender',  'name':'root',    'src':'sheeva@bender::rootfs/',  'pw': 'eb306223e413cdaa377548e8742a1cd6', },  # 2G
#   { 'host':'bender',  'name':'test',    'src':'/etc',                  'minAge':86400*2,  },  # small
#   { 'host':'digit',   'name':'test',    'src':'/Users/alan/iphone',    'minAge':86400*2,  },  # 1G
    { 'host':'aspire',  'name':'etc',     'src':'root@aspire:/etc/',     'minAge':86400*1,  },  # small
    { 'host':'aspire',  'name':'home',    'src':'root@aspire:/home/',    'minAge':86400*1,  },  # 46G
    { 'host':'aspire',  'name':'boot',    'src':'root@aspire:/boot/',    'minAge':86400*1,  },  # small
    { 'host':'bender',  'name':'root',    'src':'root@bender:/',         'minAge':86400*1,  },  # small
    { 'host':'bender',  'name':'boot',    'src':'root@bender:/boot/',    'minAge':86400*1,  },  # small
    { 'host':'bender',  'name':'home',    'src':'root@bender:/home/',    'minAge':86400*1,  },  # 13G
    { 'host':'bender',  'name':'backup',  'src':'root@bender:/backup/',  'minAge':86400*1,  },  # 44G
    { 'host':'bender',  'name':'pub',     'src':'root@bender:/pub/',     'minAge':86400*1,  },  # small
#   { 'host':'bender',  'name':'copy',    'src':'root@bender:/copy/',    'minAge':86400*2,  },  # 124G      evaluate
    { 'host':'enigma',  'name':'home',    'src':'root@enigma:/home/',    'minAge':86400*7,  },  # small
    { 'host':'digit',   'name':'users',   'src':'root@digit:/Users/',    'minAge':86400*1,  },  # 95G
#   { 'host':'digit',   'name':'x',       'src':'root@digit:/x/',        'minAge':86400*2,  },  # 203G      evaluate
    { 'host':'mini',    'name':'users',   'src':'root@mini:/Users/',     'minAge':86400*1,  },  # 2G
    { 'host':'sheeva',  'name':'root',    'src':'/',                     'minAge':86400*7,  },  # 2G
    { 'host':'sheeva',  'name':'boot',    'src':'/boot/',                'minAge':86400*7,  },  # small
    { 'host':'xps',     'name':'home',    'src':'root@xps:/home/',       'minAge':86400*3,  },  # 35G
    { 'host':'xps',     'name':'etc',     'src':'root@xps:/etc/',        'minAge':86400*3,  },  # small
    { 'host':'xps',     'name':'boot',    'src':'root@xps:/boot/',       'minAge':86400*3,  },  # small
# XPS /dev/mapper/vg1-home         128G     35G     87G   29%  /home
# XPS /dev/mapper/vg1-vm           109G     62G     41G   61%  /mnt/vm
# XPS /dev/mapper/vg1-public        15G     11G    3.4G   77%  /mnt/public
# XPS /dev/mapper/vg1-tekelec       30G     24G    4.1G   86%  /mnt/tekelec
# XPS /dev/mapper/vg1-itunes        16G    6.7G    9.4G   42%  /mnt/itunes
# XPS /dev/mapper/vg1-music         50G     47G    3.0G   94%  /mnt/music
# XPS /dev/mapper/vg1-movies        50G     46G    3.6G   93%  /mnt/movies
# d505.pl:$Conf{RsyncShareName} = ['/home','/root','/etc','/var/log'];
]

top = '/rsback'
maxAge = 10000000
defaultMinAge = 86400
keepCount = 9
daily = 'daily'
options = ()

# globals
g_logFD = None
debugMode = False

#-----------------------------------------------------------

def log_init():
    # we're writing these globals
    global g_logFD
    # log file
    #  logdir = os.environ['HOME']+"/var/log"
    #  if not os.path.exists(logdir):
    #     os.makedirs(logdir)
    #  logfile = logdir+"/garage.log"
    #  logfile = 'rsback.log'
    logfile = '/dev/stdout'
    g_logFD = open(logfile,'a')

#-----------------------------------------------------------

def log_debug(string):
    if options.debug: log_info(string)

#-----------------------------------------------------------

def log_info(string):
    global g_logFD
    timeStamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    g_logFD.write(timeStamp+" "+string+"\n")
    g_logFD.flush()
    ##os.fsync(g_logFD)

#-----------------------------------------------------------

def shell_capture(cmdargs):
    global g_logFD
    log_debug('shell_capture command >> '+(' '.join(cmdargs)))
    p = subprocess.Popen(cmdargs, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    rc = p.returncode
    log_debug("shell_capture done, rc="+('%d'%rc))
    return rc, stdout, stderr

#-----------------------------------------------------------

def shell_do(cmdargs):
    global g_logFD
    log_debug('shell_do command >> '+(' '.join(cmdargs)))
    rc = subprocess.call(cmdargs)
    #rc = subprocess.call(cmdargs, stdout=g_logFD, stderr=g_logFD)
    log_debug("shell_do rc = "+("%d"%rc))
    return rc

#-----------------------------------------------------------

def sec2dhms(s):
    days = s // 86400  ; s = s - (days * 86400)
    hours = s // 3600  ; s = s - (hours * 3600)
    mins = s // 60     ; s = s - (mins * 60)
    secs = s
    return (days, hours, mins, secs)

#-----------------------------------------------------------

def do_backup(v):

    args = [
        '-al',
        '-E',
        '--delete',
        '--delete-excluded',
#       '--stats',
        '--numeric-ids',
        '--one-file-system',
#       '-v',
        '--link-dest='+top+'/'+v['host']+'/'+v['name']+'/'+daily+'.1',
    ]

    src = v['src']
    dest = top+'/'+v['host']+'/'+v['name']+'/'+daily+'.0'

    # optional - "excludes" file
    excludes = top+'/'+v['host']+'/'+v['name']+'/excludes'
    log_debug('testing for ['+excludes+']')
    if os.path.isfile(excludes):
        log_debug('"excludes" file found, adding argument')
        args.append('--exclude-from='+excludes)

    rc = shell_do(['/usr/bin/rsync'] + args + [src, dest])

    #   0      Success
    #   1      Syntax or usage error
    #   2      Protocol incompatibility
    #   3      Errors selecting input/output files, dirs
    #   4      Requested action not supported
    #   5      Error starting client-server protocol
    #   6      Daemon unable to append to log-file
    #   10     Error in socket I/O
    #   11     Error in file I/O
    #   12     Error in rsync protocol data stream
    #   13     Errors with program diagnostics
    #   14     Error in IPC code
    #   20     Received SIGUSR1 or SIGINT
    #   21     Some error returned by waitpid()
    #   22     Error allocating core memory buffers
    #   23     Partial transfer due to error
    #   24     Partial transfer due to vanished source files
    #   25     The --max-delete limit stopped deletions
    #   30     Timeout in data send/receive
    #   35     Timeout waiting for daemon connection
    complete = True if rc in (0, 24) else False
    log_debug('rc = %d, '%rc)

    prefix = top+'/'+v['host']+'/'+v['name']+'/'+daily+'.'
    if os.path.isdir(prefix+'0') == False:
        log_debug(prefix+'0 directory was not found, marking incomplete')
        complete = False


    if complete:
        log_debug('backup of '+v['host']+'/'+v['name']+' is complete')
        # "touch" the timestamp
        os.utime(prefix+'0',None)
        # rotate the numbered backups
        if os.path.isdir(prefix+str(keepCount)):
            log_debug('removing '+str(keepCount))
            shutil.rmtree(prefix+str(keepCount))
        for i in range(keepCount,0,-1):
            if os.path.isdir(prefix+str(i-1)):
                log_debug('renaming '+str(i-1)+' -> '+str(i))
                os.rename(prefix+str(i-1),prefix+str(i))
    else: # not complete
        log_debug('backup of '+v['host']+'/'+v['name']+' is complete')
        if os.path.isdir(prefix+'0'):
            log_debug('removing 0')
            shutil.rmtree(prefix+'0')

    log_debug('done')

#-----------------------------------------------------------

def do_single_pass():

    # LOOK AT RECENT BACKUPS

    recentBackups = glob.glob(top+'/*/*/'+daily+'.1')
    for recentBackup in recentBackups:
        # break the wildcard (glob) into parts
        junk1, junk2, right = recentBackup.partition(top)
        pathpieces = right.split('/')
        host = pathpieces[1]
        name = pathpieces[2]
        # Get the creation time of the daily.1 directory.
        # Note: ctime() does not refer to creation time on *nix systems,
        # but rather the last time the inode data changed.
        lastBackup = time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(os.path.getmtime(recentBackup)))
        # find the volumeInfo line that contains key='host-name'
        try:
            idx = map(operator.itemgetter('key'), volumeInfo).index(host+'-'+name)
            log_debug('host='+host+', name='+name+', lastBackup='+lastBackup+', '+host+'-'+name+' is in slot %d'%idx)
            volumeInfo[idx]['lastBackup'] = lastBackup
        except ValueError:
            log_debug('host='+host+', name='+name+', lastBackup='+lastBackup+', '+host+'-'+name+' is not in the list of volumes')
            pass

    # GO THROUGH THE LIST IN ORDER, DETERMINE THEIR AGES AND NEXT BACKUP TIME

    now = datetime.datetime.now()
    for volume in volumeInfo:
        lastBackup = datetime.datetime.strptime(volume['lastBackup'],'%Y-%m-%d %H:%M:%S')
        ageDelta = now - lastBackup
        currentAge = ageDelta.seconds + (ageDelta.days * 86400)
        volume['currentAge'] = currentAge
        nextBackup = volume['minAge'] - volume['currentAge']
        if volume['disabled']: nextBackup = maxAge
        volume['nextBackup'] = nextBackup

    sortedVolumes = sorted(volumeInfo, key=operator.itemgetter('nextBackup'))

    # SHOW THE SORTED LIST IN THE LOG

    maxKeyWidth = 0
    for volume in volumeInfo:
        maxKeyWidth = max(maxKeyWidth,len(volume['key']))

    log_info('volumes:')
    now = datetime.datetime.now()
    for volume in sortedVolumes:
        (d,h,m,s) = sec2dhms( volume['nextBackup'] )
        status='READY'
        if volume['currentAge'] < volume['minAge']:
            status = 'NEXT RUN %dd+%d:%02d:%02d' % (d,h,m,s)
        if volume['disabled']: status='DISABLED'
        log_info('   '+volume['key']+(' '*(maxKeyWidth-len(volume['key'])))
             +' -> '+volume['lastBackup']
             +' = '+('%d'%volume['currentAge'])+'/'+('%d'%volume['minAge'])
             +'   '+status)
    log_info('')

    # GO THROUGH THE LIST IN ORDER, BACKING UP EACH ONE IF NEEDED

    log_info('start of single pass')
    for volume in sortedVolumes:
        if volume['currentAge'] < volume['minAge']: continue
        if volume['disabled']: continue
        do_backup(volume)
    log_info('end of single pass')

#-----------------------------------------------------------

# START
def main():

    # FIRST -- PARSE COMMAND LINE
    usage = "usage: %prog [options]"
    parser = OptionParser(usage)
    parser.add_option("-d", "--debug", action="store_true", dest="debug")
    global options
    (options, args) = parser.parse_args()
    if len(args) != 0:
        parser.error("incorrect number of arguments")

    # SET UP SERVICES

    log_init()

    # LOOK FOR PID FILE, EXIT IF FOUND

    pidfile='/var/run/rsback-py.pid'
    try:
        with open(pidfile) as f:
            log_info("pidfile '%s' found... better look for a running process" % pidfile)
            pid = int(f.readline())
            # Check For the existence of a unix pid, send signal 0 to it.
            try:
                os.kill(pid, 0)
            except OSError:
                log_info("pid %d not found, continuing" % pid)
            else:
                log_info("pid %d is still running, exiting" % pid)
                sys.exit()
    except IOError as e:
        pass
    file(pidfile,'w').write(str(os.getpid())+'\n')

    # ADD SOME DEFAULTS TO 'volumeInfo' DICTIONARY

    for volume in volumeInfo:
        key = volume['host']+'-'+volume['name']
        volume['key'] = key
        volume['lastBackup'] = '2000-01-01 00:00:00'
        if 'minAge' not in volume: volume['minAge'] = defaultMinAge
        if 'disabled' not in volume: volume['disabled'] = False

    while True:
        do_single_pass()
        time.sleep(10*60)

    # CLEAN UP

    log_info('cleaning up')
    os.unlink(pidfile)

#-----------------------------------------------------------

if __name__ == "__main__":
     main()


