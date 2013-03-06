#!/usr/bin/python

import os
import datetime
import subprocess
import shlex
import glob
import operator
import sys
from optparse import OptionParser

volumeInfo = [
#  { 'host':'bender',  'name':'root',    'src':'sheeva@bender::rootfs/',  'pw': 'eb306223e413cdaa377548e8742a1cd6', },  # 2G
#  { 'host':'bender',  'name':'test',    'src':'/etc',                  'minAge':86400*2,  "disabled":True   },  # small
#  { 'host':'digit',   'name':'test',    'src':'/Users/alan/iphone',    'minAge':86400*2,  "disabled":True   },  # 1G
   { 'host':'aspire',  'name':'etc',     'src':'root@aspire:/etc/',     'minAge':86400*2,  "disabled":False  },  # small
   { 'host':'aspire',  'name':'home',    'src':'root@aspire:/home/',    'minAge':86400*2,  "disabled":False  },  # 46G
   { 'host':'aspire',  'name':'boot',    'src':'root@aspire:/boot/',    'minAge':86400*2,  "disabled":False  },  # small
   { 'host':'bender',  'name':'root',    'src':'root@bender:/',         'minAge':86400*2,  "disabled":False  },  # small
   { 'host':'bender',  'name':'boot',    'src':'root@bender:/boot/',    'minAge':86400*2,  "disabled":False  },  # small
   { 'host':'bender',  'name':'home',    'src':'root@bender:/home/',    'minAge':86400*2,  "disabled":False  },  # 13G
   { 'host':'bender',  'name':'backup',  'src':'root@bender:/backup/',  'minAge':86400*2,  "disabled":False  },  # 44G
   { 'host':'bender',  'name':'pub',     'src':'root@bender:/pub/',     'minAge':86400*2,  "disabled":False  },  # small
#  { 'host':'bender',  'name':'copy',    'src':'root@bender:/copy/',    'minAge':86400*2,  "disabled":True   },  # 124G      evaluate
   { 'host':'enigma',  'name':'home',    'src':'root@enigma:/home/',    'minAge':86400*7,  "disabled":False  },  # small
   { 'host':'digit',   'name':'users',   'src':'root@digit:/Users/',    'minAge':86400*2,  "disabled":False  },  # 95G
#  { 'host':'digit',   'name':'x',       'src':'root@digit:/x/',        'minAge':86400*2,  "disabled":True   },  # 203G      evaluate
   { 'host':'mini',    'name':'users',   'src':'root@mini:/Users/',     'minAge':86400*2,  "disabled":False  },  # 2G
   { 'host':'sheeva',  'name':'root',    'src':'/',                     'minAge':86400*7,  "disabled":False  },  # 2G
   { 'host':'sheeva',  'name':'boot',    'src':'/boot/',                'minAge':86400*7,  "disabled":False  },  # small
   { 'host':'xps',     'name':'home',    'src':'root@xps:/home/',       'minAge':86400*2,  "disabled":False  },  # 35G
   { 'host':'xps',     'name':'etc',     'src':'root@xps:/etc/',        'minAge':86400*2,  "disabled":False  },  # small
   { 'host':'xps',     'name':'boot',    'src':'root@xps:/boot/',       'minAge':86400*2,  "disabled":False  },  # small
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
defaultMinAge = 86400
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
   rc = subprocess.call(cmdargs, stdout=g_logFD, stderr=g_logFD)
   log_debug("shell_do rc = "+("%d"%rc))
   return rc

#-----------------------------------------------------------

def do_backup(v):

   cfgfilename = '/tmp/rsback.conf'
   f1 = open(cfgfilename, 'w+')

   pwopt=''
   if 'pw' in v :
      pwfilename = '/tmp/rsback.pw'
      f2 = open(pwfilename, 'w+')
      f2.write(v['pw'])
      f2.close()
      pwopt='--password-file '+pwfilename

   # rsync_options = -v
   # rsync_options = -E on a Mac means copy extended attributes (necessary), on Linux it means preserve exe status (innocuous)
   # exclude_file = /etc/rsback/global.exclude
   f1.write('[global]\n')
   f1.write('rsync_cmd = /usr/bin/rsync\n')
   f1.write('cp_cmd = /bin/cp\n')
   f1.write('mv_cmd = /bin/mv\n')
   f1.write('rm_cmd = /bin/rm\n')
   f1.write('mkdir_cmd = /bin/mkdir\n')
   f1.write('lock_dir = /var/lock\n')
   f1.write('rsync_options = -al -E --delete --delete-excluded --stats --numeric-ids --one-file-system '+pwopt+'\n')
   f1.write('if_locked_retry = 3 10m\n')
   f1.write('if_error_continue = yes\n')

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
   f1.write('ignore_rsync_errors = 10 12 24\n')
   f1.write('use_link_dest = yes\n')
   f1.write('\n')

   f1.write('tasks = %s-%s-daily %s-%s-weekly\n' % ( v['host'], v['name'], v['host'], v['name'] ) )
   f1.write('\n')
   f1.write('[%s-%s-daily]\n' % (v['host'], v['name']) )
   f1.write('source = %s\n' % (v['src']) )
   f1.write('destination = %s/%s/%s\n' % (top, v['host'], v['name']) )
   f1.write('rotate = daily 9\n')
   f1.write('mode = rsync\n')
   f1.write('exclude_file = %s/%s/%s/excludes\n' % (top, v['host'], v['name']) )
   f1.write('\n')

   f1.write('[%s-%s-weekly]\n' % (v['host'], v['name']) )
   f1.write('source = %s/%s/%s/daily.1/\n' % (top, v['host'], v['name']) )
   f1.write('destination = %s/%s/%s/\n' % (top, v['host'], v['name']) )
   f1.write('rotate = weekly 9\n' % () )
   f1.write('mode = link\n' % () )
   f1.write('\n')

   f1.close()

   rc = shell_do(['./rsback-0.6.4.pl', '-v', '-c', cfgfilename, '%s-%s-daily' % (v['host'], v['name']) ])

   os.remove(cfgfilename)
   if 'pw' in v : os.remove(pwfilename)

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
      if 'minAge' not in volume : volume['minAge'] = defaultMinAge
      if 'disabled' not in volume : volume['disabled'] = False

   # LOOK AT RECENT BACKUPS

   cmd = ['grep', '^1\\b']
   cmd.extend(glob.glob(top+'/*/*/history.daily'))
   rc, stdout, stderr = shell_capture(cmd)
   for line in stdout.split('\n'):
      if line == '' : continue
      junk1, junk2, right = line.partition(top)
      pathpieces = right.split('/')
      host = pathpieces[1]
      name = pathpieces[2]
      junk1, junk2, lastBackup = right.partition('\t')
      #log_debug('LINE <<'+line+'>>')
      # find the volumeInfo line that contains key='host-name'
      try:
         idx = map(operator.itemgetter('key'), volumeInfo).index(host+'-'+name)
         log_debug('host='+host+', name='+name+', lastBackup='+lastBackup+', '+host+'-'+name+' is in slot %d'%idx)
         volumeInfo[idx]['lastBackup'] = lastBackup
      except ValueError:
         log_debug('host='+host+', name='+name+', lastBackup='+lastBackup+', '+host+'-'+name+' is not in the list of volumes')
         pass

   # SORT RECENT BACKUPS BY AGE

   sortedVolumes = sorted(volumeInfo, key=operator.itemgetter('lastBackup'))

   # GO THROUGH THE LIST IN ORDER, DETERMINE THEIR AGES

   log_info('volumes:')
   now = datetime.datetime.now()
   for volume in sortedVolumes:
      lastBackup = datetime.datetime.strptime(volume['lastBackup'],'%Y-%m-%d %H:%M:%S')
      ageDelta = now - lastBackup
      currentAge = ageDelta.seconds + (ageDelta.days * 86400)
      volume['currentAge'] = currentAge
      log_info('   '+volume['key']+' -> '+volume['lastBackup']+' = '+('%d'%currentAge)+('  DISABLED' if volume['disabled'] else '') )
   log_info('')

   # GO THROUGH THE LIST IN ORDER, BACKING UP EACH ONE IF NEEDED

   for volume in sortedVolumes:
      if volume['currentAge'] < volume['minAge'] : continue
      if volume['disabled'] : continue
      do_backup(volume)

   log_info('finished')

   # CLEAN UP

   os.unlink(pidfile)

#-----------------------------------------------------------

if __name__ == "__main__":
    main()


