
# "flashback" - backs up your stuff

This project backs up files from the computers in my house.  It started
as a python wrapper around 'rsback', which itself is a perl wrapper around
'rsync'.  Rsback does a really nice job of using rsync's hard linking to
save multiple backups of a volume without wasting space on files that stay
the same day after day.  For more info on that feature, see the 'link-dest'
option in the man page for rsync.

Rsback is meant to be run as a cron job, but I wanted a daemon that would
check every so often (10 minutes) and back up anything that was at least
'so old' (a day).  So early versions of flashback simply looped forever,
and when it was time to do a backup, it would create a temporary rsback
config file and then call rsback.  After a while, I decided that it was
silly to be setting up rsback for these temporary jobs when I could just
call rsync myself.

Flashback is a "no frills" backup package.  It takes its orders from a
few config files, and it writes its status in two output files.  I share
these status files via a web server, and that has been a pretty adequate
way of checking in on my backups.

## A message from the author

This has been a very fun project, and it is useful as well.  I hope you
enjoy it.  If you have questions or comments, please contact me.

Alan Porter
(alan@alanporter.com)

