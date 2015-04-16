
# "flashback" - backs up your stuff

This project backs up files from the computers in my house.  First, I'll
describe how I use it, and then I'll give the general description.

I have a "Pogo Plug" dedicated to doing backups.  It's a $12 embedded Linux
mini-machine that is about as powerful as a Raspberry Pi.  I attached a
USB hard disk to it -- that's where the backup files are stored.

Flashback is a Python script that maintains a list of all of the computers
and disk volumes that you want to back up.  Every ten minutes, it wakes
up and goes through the list to see which ones are due for backing up.
It tries to ping those machines, and then it tries to do an rsync (an
incremental backup with very a efficient copy algorithm).  It uses some
of rsync's clever "hard link" options so that each daily backup is a
complete copy of the backed up disk volume, but files that do not change
from day to day are only stored on the disk once.

Although Flashback was designed to be run on a dedicated machine, there
is no reason why it can not be run on a normal Linux server.  Since it
runs OK on the ridiculously underpowered Pogo Plug, it should be fine
on a normal Linux desktop or server.

Flashback is suited for making regular backups of many computers in a
home or a small office, or even for backing up remote servers.

A word of warning... Flashback is a "no frills" backup package.  It takes
its orders from a few config files, and it writes its status to two output
files.  I share these status files via a web server, and that has been a
pretty adequate way of checking in on my backups.  However, there is no
user interface for setting up jobs, checking on statuses, or recovering
files.  You set up jobs by editing two config files.  You check on the
status by looking at two status files (via logging in and using 'cat',
or by browser if you share those files using a web server).  You restore
files using rsync.  If you are not comfortable with the shell and command
line programs, then flashback is probably not for you.

Flashback has saved my bacon several times.  I've had hard disks die
suddenly, and have used the very recent backups to recover.  I have made
mistakes that messed up a server's filesystem, and used the backups to
rebuild the server from scratch.  I have even used flashback to remotely
access recent copies of files from a machine that is currently powered
off (wife's laptop is at home, powered off, and I am away from home).

Running on a small (and cheap) (and silent) computer like a Pogo Plug,
this little dedicated program just persistently and consistently backs
up everything that I care about.  When I get home and open up my laptop,
flashback notices and starts backing up anything that has changed
recently.

# History

Flashback started as a python wrapper around 'rsback', which itself is a
Perl wrapper around 'rsync'.  Rsback does a really nice job of using
rsync's hard linking to save multiple backups of a volume without wasting
space on files that stay the same day after day.  For more info on that
feature, see the 'link-dest' option in the man page for rsync.

Rsback is meant to be run as a cron job, but I wanted a daemon that would
check every so often (10 minutes) and back up anything that was at least
'so old' (a day).  So early versions of flashback simply looped forever,
and when it was time to do a backup, it would create a temporary rsback
config file and then call rsback.  After a while, I decided that it was
silly to be setting up rsback for these temporary jobs when I could just
call rsync myself.  I do owe a lot to the rsback project, since it
introduced me to rsync's link-dest capability.

## A message from the author

This has been a very fun project, and it is useful as well.  I hope you
enjoy it.  If you have questions or comments, please contact me.

Alan Porter
(alan@alanporter.com)

