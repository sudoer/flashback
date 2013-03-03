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
#  { 'host':'bender',  'name':'root',    'src':'sheeva@bender::rootfs/',  'pw': 'eb3062a3e413cdaa377548e8742a1cd6', },  # 2G
#  { 'host':'bender',  'name':'test',    'src':'/etc',                  'minAge':86400    },  # small
#  { 'host':'kimono',  'name':'test',    'src':'/Users/alan/iphone',    'minAge':86400    },  # 1G
   { 'host':'aspire',  'name':'etc',     'src':'root@aspire:/etc/',     'minAge':86400    },  # small
   { 'host':'aspire',  'name':'home',    'src':'root@aspire:/home/',    'minAge':86400    },  # 46G
   { 'host':'aspire',  'name':'boot',    'src':'root@aspire:/boot/',    'minAge':86400    },  # small
   { 'host':'bender',  'name':'root',    'src':'root@bender:/',         'minAge':86400    },  # small
   { 'host':'bender',  'name':'boot',    'src':'root@bender:/boot/',    'minAge':86400    },  # small
   { 'host':'bender',  'name':'home',    'src':'root@bender:/home/',    'minAge':86400    },  # 13G
   { 'host':'bender',  'name':'backup',  'src':'root@bender:/backup/',  'minAge':86400    },  # 44G
   { 'host':'bender',  'name':'pub',     'src':'root@bender:/pub/',     'minAge':86400    },  # small
#  { 'host':'bender',  'name':'copy',    'src':'root@bender:/copy/',    'minAge':86400    },  # 124G      evaluate
   { 'host':'enigma',  'name':'home',    'src':'root@enigma:/home/',    'minAge':86400*7  },  # small
   { 'host':'kimono',  'name':'users',   'src':'root@kimono:/Users/',   'minAge':86400    },  # 95G
#  { 'host':'kimono',  'name':'x',       'src':'root@kimono:/x/',       'minAge':86400    },  # 203G      evaluate
#  { 'host':'mini',    'name':'users',   'src':'root@mini:/Users/',     'minAge':86400    },  # 46G       clean up and add
   { 'host':'sheeva',  'name':'root',    'src':'/',                     'minAge':86400*7  },  # 2G
   { 'host':'sheeva',  'name':'boot',    'src':'/boot/',                'minAge':86400*7  },  # small
   { 'host':'xps',     'name':'home',    'src':'root@xps:/home/',       'minAge':86400    },  # 35G
   { 'host':'xps',     'name':'etc',     'src':'root@xps:/etc/',        'minAge':86400    },  # small
   { 'host':'xps',     'name':'boot',    'src':'root@xps:/boot/',       'minAge':86400    },  # small
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
   f1.write('''
[global]
rsync_cmd = /usr/bin/rsync
cp_cmd = /bin/cp
mv_cmd = /bin/mv
rm_cmd = /bin/rm
mkdir_cmd = /bin/mkdir
lock_dir = /var/lock
rsync_options = -al -E --delete --delete-excluded --stats --numeric-ids --one-file-system '''+pwopt+'''
if_locked_retry = 3 10m
if_error_continue = yes
ignore_rsync_errors = 10 12 24
use_link_dest = yes
''')

   f1.write('tasks = %s-%s-daily %s-%s-weekly' % ( v['host'], v['name'], v['host'], v['name'] ) )

   f1.write('''
[%s-%s-daily]
source = %s
destination = %s/%s/%s/
rotate = daily 9
mode = rsync
''' % ( v['host'], v['name'], v['src'], top, v['host'], v['name'] ) )

   f1.write('''
[%s-%s-weekly]
source = %s/%s/%s/daily.1/
destination = %s/%s/%s/
rotate = weekly 9
mode = link
''' % ( v['host'], v['name'], top, v['host'], v['name'], top, v['host'], v['name'] ) )
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

   now = datetime.datetime.now()
   for volume in sortedVolumes:
      lastBackup = datetime.datetime.strptime(volume['lastBackup'],'%Y-%m-%d %H:%M:%S')
      ageDelta = now - lastBackup
      currentAge = ageDelta.seconds + (ageDelta.days * 86400)
      volume['currentAge'] = currentAge
      log_info('   '+volume['key']+' -> '+('DISABLED' if volume['disabled'] else ( volume['lastBackup']+' = '+ ('%d'%currentAge)) ) )

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


