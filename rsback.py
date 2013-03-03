#!/usr/bin/python

import os
import datetime
import subprocess
import shlex
import glob
import operator

volumeInfo = [
   { 'user':'root',  'host':'aspire',  'name':'etc',     'path':'/etc',     'disabled':True,  },  # small
   { 'user':'root',  'host':'aspire',  'name':'home',    'path':'/home',    'disabled':True,  },  # 46G
   { 'user':'root',  'host':'aspire',  'name':'boot',    'path':'/boot',    'disabled':True,  },  # small
   { 'user':'root',  'host':'bender',  'name':'root',    'path':'/',                          },  # 2G
   { 'user':'root',  'host':'bender',  'name':'boot',    'path':'/boot',    'disabled':True,  },  # small
   { 'user':'root',  'host':'bender',  'name':'home',    'path':'/home',    'disabled':True,  },  # 13G
   { 'user':'root',  'host':'bender',  'name':'backup',  'path':'/backup',  'disabled':True,  },  # 44G
   { 'user':'root',  'host':'bender',  'name':'pub',     'path':'/pub',     'disabled':True,  },  # small
   { 'user':'root',  'host':'bender',  'name':'copy',    'path':'/copy',    'disabled':True,  },  # 124G
   { 'user':'root',  'host':'enigma',  'name':'home',    'path':'/home',    'disabled':True,  },  # small
   { 'user':'root',  'host':'kimono',  'name':'users',   'path':'/Users',   'disabled':True   },  # 95G
   { 'user':'root',  'host':'kimono',  'name':'x',       'path':'/x',       'disabled':True,  },  # 203G
   { 'user':'root',  'host':'mini',    'name':'users',   'path':'/Users',   'disabled':True,  },  # 46G
   { 'user':'root',  'host':'sheeva',  'name':'root',    'path':'/',        'disabled':True,  },  # 2G
   { 'user':'root',  'host':'sheeva',  'name':'boot',    'path':'/boot',    'disabled':True,  },  # small
   { 'user':'root',  'host':'xps',     'name':'home',    'path':'/home',    'disabled':True,  },  # 35G
   { 'user':'root',  'host':'xps',     'name':'etc',     'path':'/etc',     'disabled':True,  },  # small
   { 'user':'root',  'host':'xps',     'name':'boot',    'path':'/boot',    'disabled':True,  },  # small
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
minAge = 86400
minAge = 600

# globals
g_logFD = None

#-----------------------------------------------------------

def init():
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

def log_info(string):
   global g_logFD
   timeStamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
   g_logFD.write(timeStamp+" "+string+"\n")
   g_logFD.flush()
   ##os.fsync(g_logFD)

#-----------------------------------------------------------

def shell_capture(cmdargs):
   global g_logFD
   log_info('shell_capture command >> '+(' '.join(cmdargs)))
   p = subprocess.Popen(cmdargs, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
   stdout, stderr = p.communicate()
   rc = p.returncode
   log_info("shell_capture done, rc="+('%d'%rc))
   log_info("")
   return rc, stdout, stderr

#-----------------------------------------------------------

def shell_do(cmdargs):
   global g_logFD
   log_info('shell_do command >> '+(' '.join(cmdargs)))
   rc = subprocess.call(cmdargs, stdout=g_logFD, stderr=g_logFD)
   log_info("shell_do rc = "+("%d"%rc))
   log_info("")
   return rc

#-----------------------------------------------------------

def do_backup(v):

   cfgfilename = '/tmp/rsback.conf'
   f1 = open(cfgfilename, 'w+')

   # rsync_options = -val --delete --delete-excluded --stats --numeric-ids --one-file-system
   # exclude_file = /etc/rsback/global.exclude
   f1.write('''
[global]
rsync_cmd = /usr/bin/rsync
cp_cmd = /bin/cp
mv_cmd = /bin/mv
rm_cmd = /bin/rm
mkdir_cmd = /bin/mkdir
lock_dir = /var/lock
rsync_options = -al --delete --delete-excluded --stats --numeric-ids --one-file-system
if_locked_retry = 3 10m
if_error_continue = yes
ignore_rsync_errors = 10 12 24
use_link_dest = yes
''')

   f1.write('tasks = %s-%s-daily %s-%s-weekly' % ( v['host'], v['name'], v['host'], v['name'] ) )

   f1.write('''
[%s-%s-daily]
source = %s@%s:%s/
destination = %s/%s/%s/
rotate = daily 9
mode = rsync
''' % ( v['host'], v['name'], v['user'], v['host'], v['path'], top, v['host'], v['name'] ) )

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

#-----------------------------------------------------------

# START
init()

# LOOK FOR PID FILE, EXIT IF FOUND

pidfile='/var/run/rsback-py.pid'
try:
   with open(pidfile) as f:
      sys.exit()
except IOError as e:
   file(pidfile,'w').write(str(os.getpid()))


# ADD SOME DEFAULTS TO 'volumeInfo' DICTIONARY

for volume in volumeInfo:
   key = volume['host']+'-'+volume['name']
   volume['key'] = key
   volume['lastBackup'] = '2000-01-01 00:00:00'
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
   log_info('<<'+line+'>> -> '+host+' & '+name+' & '+lastBackup)
   # find the volumeInfo line that contains key='host-name'
   try:
      idx = map(operator.itemgetter('key'), volumeInfo).index(host+'-'+name)
      volumeInfo[idx]['lastBackup'] = lastBackup
   except:
      pass

# SORT RECENT BACKUPS BY AGE

sortedVolumes = sorted(volumeInfo, key=operator.itemgetter('lastBackup'))

# GO THROUGH THE LIST IN ORDER, DETERMINE THEIR AGES

now = datetime.datetime.now()
for volume in sortedVolumes:
   lastBackup = datetime.datetime.strptime(volume['lastBackup'],'%Y-%m-%d %H:%M:%S')
   ageDelta = now - lastBackup
   ageSeconds = ageDelta.seconds + (ageDelta.days * 86400)
   volume['ageSeconds'] = ageSeconds
   log_info('   '+volume['key']+' -> '+('DISABLED' if volume['disabled'] else ( volume['lastBackup']+' = '+ ('%d'%ageSeconds)) ) )

# GO THROUGH THE LIST IN ORDER, BACKING UP EACH ONE IF NEEDED

for volume in sortedVolumes:
   if volume['ageSeconds'] < minAge : continue
   if volume['disabled'] : continue
   do_backup(volume)

# CLEAN UP

os.unlink(pidfile)

