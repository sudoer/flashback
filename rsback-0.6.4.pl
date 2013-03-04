#!/usr/bin/perl
# -------------------------------------------------------------
#
# rsback --  Program to backup file trees in rotating
#            archives on Unix-based hosts
#
# Copyright (C) 2007 Hans-Juergen Beie <hjb@pollux.franken.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# -------------------------------------------------------------

my $me = 'rsback';
my $version = '0.6.4';
my $lupdate = '2008-01-10';
my $author = 'hjb';
my $header = "$me-$version ($author -- $lupdate)";

# -------------------------------------------------------------
#
# You may change this, to choose an other default config file
#
my $rsback_conf = '/etc/rsback/rsback.conf';


# -------------------------------------------------------------
# !!! You should know what you are doing if you change somthing below here !!!
# -------------------------------------------------------------

require 5.005;
use IO::File;
use Getopt::Std;
use strict qw(vars);

# errors
my $ERR_BACKUP = 1;
my $ERR_DESTDIR_CREATE = 2;
my $ERR_ROT_PREVIOUS = 3;
my $ERR_HLINK_LATEST= 4;
my $ERR_RM_LATEST = 5;
my $ERR_ROT_BACK = 6;
my $ERR_RM_OLD = 7;

my %error_msg = (
    $ERR_BACKUP         => 'backup failed',
    $ERR_DESTDIR_CREATE => 'creation of destination directory',
    $ERR_ROT_PREVIOUS   => 'rotation of previous archives',
    $ERR_HLINK_LATEST   => 'hard-linking latest backup archive',
    $ERR_RM_LATEST      => 'removing latest backup archive',
    $ERR_ROT_BACK       => 'back-rotating backup archives',
    $ERR_RM_OLD         => 'removing old archive',
);

# -------------------------------------------------------------

$| = 1;        # flush output imediately
my $t = iso_dts();
my $job_time = time();
print "$me: [$t] $header\n";

#
# parse cmd line
#
my %opts;
unless (getopts('hvidc:', \%opts)) {
    print "$me: Error reading arguments: $!";
    usage();
    exit 1;
}

if ($opts{h}) {            # help
    usage();
    exit 1;
};

if ($opts{c}) {            # config file
    $rsback_conf = $opts{c};
}

if ($opts{d}) {            # debug mode
    $opts{v} = 1;
}

#
# read config file
#
my %config = read_config($rsback_conf);

#
# get backup tasks
#
my @tasks = @ARGV;
my $task_cnt = @tasks;
print"$me: processing $task_cnt tasks: ";
foreach my $t (@tasks) {
    print "'$t' ";
}
print "\n";

#
# if no backup tasks are given with init option
# select all tasks from config file
#
if (($task_cnt == 0) && $opts{i}) {
    @tasks = split_list($config{'global:tasks'});
    $task_cnt = @tasks;
    print "$me: $task_cnt tasks to init\n" if $opts{d};
}

unless ($task_cnt) {
        usage();
        die "$me: You should specify one backup task, at least.\n";
}


#
# check definitions for each given task
#
my $missing_defs = 0;
foreach my $task(@tasks) {
    my $list = $config{'global:tasks'};
    print "$me: checking defs for task '$task' in config '$list'\n" if $opts{d};
    unless ( is_in_string($task, $config{'global:tasks'}) ) {
        print "$me: no config for task '$task' found\n";
        $missing_defs++;
    }

}
die "$me: check command and/or config file '$rsback_conf'\n" if $missing_defs;

 
# default values for retrying if task is locked
#
my $default_retry_max_attempts = 0;
my $default_retry_delay = 600;
my $delay_value = 0;
my $delay_unit = '';
if ( exists $config{'global:if_locked_retry'} ) {
    ($default_retry_max_attempts, $default_retry_delay) = split_list($config{'global:if_locked_retry'});
    if ( $default_retry_delay =~ /^(\d+)(\D+)/ ) {
        $delay_value = $1;
        $delay_unit = $2;
        $default_retry_delay = $delay_value;
        $default_retry_delay = $delay_value * 60 if $delay_unit =~ /^[mM]/;
        $default_retry_delay = $delay_value * 3600 if $delay_unit =~ /^[hH]/;
    }
}

#
# process backup tasks
#
my %history;
#my $task_failed = 0;
#my $task_locked = 0;
my @locked_by;

TASK:
foreach my $task(@tasks) {
    my $t = iso_dts();
    my $task_time = time();
    my ($retry_max_attempts, $retry_delay);
    my $retry_attempt = 0;
    my $task_triggered = 0;
    my $backup_error = 0;
    my $task_locked = 0;
    my $new_history_ref = ();

    #
    # how should we handle task failures?
    #
    my $if_error_continue = 1;        # default: continue when a task fails
    if (exists $config{'global:if_error_continue'}) {
        $if_error_continue = 1 if ($config{'global:if_error_continue'} =~ /^(yes|true)/i);
        $if_error_continue = 0 if ($config{'global:if_error_continue'} =~ /^(no|false)/i);
    }
    if (exists $config{"$task:if_error_continue"}) {
        $if_error_continue = 1 if ($config{"$task:if_error_continue"} =~ /^(yes|true)/i);
        $if_error_continue = 0 if ($config{"$task:if_error_continue"} =~ /^(no|false)/i);
    }

    $config{'if_error_undo'} = 1;        # default: undo backup if it didn't succeed
    if (exists $config{'global:if_error_undo'}) {
        $config{'if_error_undo'} = 1 if ($config{'global:if_error_undo'} =~ /^(yes|true)/i);
        $config{'if_error_undo'} = 0 if ($config{'global:if_error_undo'} =~ /^(no|false)/i);
    }
    if (exists $config{"$task:if_error_undo"}) {
        $config{'if_error_undo'} = 1 if ($config{"$task:if_error_undo"} =~ /^(yes|true)/i);
        $config{'if_error_undo'} = 0 if ($config{"$task:if_error_undo"} =~ /^(no|false)/i);
    }

    # new as of v0.6.0
    $config{'use_link_dest'} = 1;        # default: use rsync's link-dest option
    if (exists $config{'global:use_link_dest'}) {
        $config{'use_link_dest'} = 1 if ($config{'global:use_link_dest'} =~ /^(yes|true)/i);
        $config{'use_link_dest'} = 0 if ($config{'global:use_link_dest'} =~ /^(no|false)/i);
    }
    if (exists $config{"$task:use_link_dest"}) {
        $config{'use_link_dest'} = 1 if ($config{"$task:use_link_dest"} =~ /^(yes|true)/i);
        $config{'use_link_dest'} = 0 if ($config{"$task:use_link_dest"} =~ /^(no|false)/i);
    }

    # new as of v0.6.2
    $config{'warnings_to_stdout'} = 0;        # default: don't print warnings to stdout
    if (exists $config{'global:warnings_to_stdout'}) {
        $config{'warnings_to_stdout'} = 1 if ($config{'global:warnings_to_stdout'} =~ /^(yes|true)/i);
        $config{'warnings_to_stdout'} = 0 if ($config{'global:warnings_to_stdout'} =~ /^(no|false)/i);
    }
    if (exists $config{"$task:warnings_to_stdout"}) {
        $config{'warnings_to_stdout'} = 1 if ($config{"$task:warnings_to_stdout"} =~ /^(yes|true)/i);
        $config{'warnings_to_stdout'} = 0 if ($config{"$task:warnings_to_stdout"} =~ /^(no|false)/i);
    }

    $config{'ignore_rsync_errors'} = 0;    # default: don't ingore rsync errors
    if (exists $config{'global:ignore_rsync_errors'}) {
        $config{'ignore_rsync_errors'} = $config{'global:ignore_rsync_errors'};
    }
    if (exists $config{"$task:ignore_rsync_errors"}) {
        $config{'ignore_rsync_errors'} = $config{"$task:ignore_rsync_errors"};
    }


    print "$me: [$t] task '$task'\n";
    
    #
    # check for previous errors
    #
    if ( $backup_error ) {
        unless ( $if_error_continue ) {
            print "$me: [$t] *** backup task '$task' skipped because of previous errors.\n" if $config{'warnings_to_stdout'};
            warn "$me: [$t] *** backup task '$task' skipped because of previous errors.\n";
            next TASK;
        }
    }

    #
    # check for suspend file
    #
    if ( exists $config{"$task:suspend_file"} ) {
        # don't run task if suspend file exists
        if ( -e $config{"$task:suspend_file"} ) {
            print "$me: suspend file '", $config{"$task:suspend_file"}, "' found.\n" if $opts{v};
            print "$me: backup task '$task' suspended.\n";
            next TASK;
        }
    }
    
    #
    # check for trigger file
    #
    if ( exists $config{"$task:trigger_file"} ) {
        if ( -e $config{"$task:trigger_file"} ) {
            # run task only if trigger exists
            print "$me: trigger file '", $config{"$task:trigger_file"}, "' found.\n" if $opts{v};
            print "$me: backup task '$task' triggered.\n";
            $task_triggered = 1;
        } else {
            print "$me: trigger file '", $config{"$task:trigger_file"}, "' not found.\n" if $opts{v};
            print "$me: no trigger, task '$task' skipped.\n";
            next TASK;
        }
    }

    #
    # retry parameters
    #
    if (exists $config{"$task:if_locked_retry"}) {
        ($retry_max_attempts, $retry_delay) = split_list($config{"$task:if_locked_retry"});
        if ($retry_delay =~ /^(\d+)(\D+)/) {
            my $delay_value = $1;
            my $delay_unit = $2;
            $retry_delay = $delay_value;
            $retry_delay = $delay_value * 60 if $delay_unit =~/^[mM]/;
            $retry_delay = $delay_value * 3600 if $delay_unit =~/^[hH]/;
        }
    } else {
        $retry_max_attempts = $default_retry_max_attempts;
        $retry_delay =  $default_retry_delay;
    }
    
    #
    # check if the current task is locked
    #
    ($task_locked, @locked_by) = task_is_locked($task, \%config);
    while ( $task_locked ) {
        # the current task is locked by one or more other tasks
        $t = iso_dts();
        print "$me: [$t] task '$task' is locked by: @locked_by\n";
        
        if ($retry_attempt >= $retry_max_attempts) {
            # no more attempts allowed
            my $msg = '';
            $msg .= "giving up after $retry_attempt attempts, " if $retry_attempt;
            $msg .= "task '$task' is locked and cannot be executed.";
            warn "$me: [$t] *** $msg\n";
            print "$me: [$t] *** $msg\n" if $config{'warnings_to_stdout'};
            next TASK;
        } else {
            # try it again after retry_delay
            print "$me: [$t] will try to restart task '$task' in $retry_delay seconds ...\n";
            $retry_attempt++;
            sleep $retry_delay;
            ($task_locked, @locked_by) = task_is_locked($task, \%config);
        }
    }

    #
    # lock other tasks
    #
    my @locked_tasks = lock_tasks($task, \%config);
    
    if ($opts{i}) {
        #
        # init repositories only
        #
        # This is not really necessary, because during a real backup
        # directories are created on the fly if they don't yet exist.
        #
        print "$me: [$t] initializing repository '$task' ...\n";
        init_repository($task, \%config);
    } else {
        #
        # do the job
        #
        print "$me: [$t] processing backup task '$task'\n";
        %history = read_history($task, \%config);
        ($backup_error, $new_history_ref) = process_backup($task, \%config, \%history);
        write_history($task, \%config, $new_history_ref) unless $backup_error;
    }
    $task_time = s2hms(time() - $task_time);
    $t = iso_dts();
    if ($backup_error) {
        warn "$me: [$t] *** backup task '$task' failed: $backup_error - $error_msg{$backup_error}\n";
        print "$me: [$t] *** backup task '$task' failed: $backup_error - $error_msg{$backup_error}\n" if $config{'warnings_to_stdout'};
    } else {
        print "$me: [$t] backup task '$task' done, runtime: $task_time.\n";
    }
    
    #
    # remove trigger if everything seems to be ok
    #
    if ($task_triggered) {
        if ( $backup_error ) {
            warn "$me: don't remove trigger file '", $config{"$task:trigger_file"}, "' because of previous problems\n";
            print "$me: don't remove trigger file '", $config{"$task:trigger_file"}, "' because of previous problems\n" if $config{'warnings_to_stdout'};
        } else {
            print "$me: removing trigger file '", $config{"$task:trigger_file"}, "'\n";
            unlink $config{"$task:trigger_file"};
        }
    }
    
    #
    # unlock tasks
    #
    unlock_tasks(\@locked_tasks, \%config);
}

$t = iso_dts();
$job_time = s2hms(time() - $job_time);
print "$me: [$t] total runtime: $job_time\n";
print "$me: [$t] Thank you for making a simple program very happy.\n\n";

# -------------------------------------------------------------
#
# usage
#
sub usage {
    print <<__END_OF_USAGE__
$me: backup file trees in rotating archives using rsync

usage: $me [options] backup-tasks(s)

  Make a backup of one or more backup tree(s). The backup tasks itself
  are described in the configuration file.

    $rsback_conf

options:
  -h             Display this help
  -v             Be verbose
  -d             Debug mode (more verbose, runs rsync with option --dry-run)
  -i             Init backup repositories only
  -c conf-file   Configuration file other than $rsback_conf

__END_OF_USAGE__
;
};

# -------------------------------------------------------------
#
# process backup
#
sub process_backup {
    my($task, $config_ref, $history_ref) = @_;

    my $source = $config_ref->{"$task:source"};
    my $dest_dir = $config_ref->{"$task:destination"};
    $dest_dir =~ s/\/+$//;        # no trailing slashes
    my ($bak_name, $keep) = split_list($config_ref->{"$task:rotate"});
    my $mode = lc($config_ref->{"$task:mode"});
    my $rsync = $config_ref->{'global:rsync_cmd'};
    my $cp = $config_ref->{'global:cp_cmd'};
    my $mv = $config_ref->{'global:mv_cmd'};
    my $rm = $config_ref->{'global:rm_cmd'};
    my $mdir = $config_ref->{'global:mkdir_cmd'};
    my $use_link_dest = $config_ref->{'use_link_dest'}; 
    my $current_dir = "$dest_dir/$bak_name.0";
    my $latest_dir = "$dest_dir/$bak_name.1";
    my $backup_failed = 0;
    my $remark = '';
    my %new_history;
    
    # for reporting rsync exit values in clear text
    # see man rsync: 'EXIT VALUES'
    my %rsync_exit_text = (
        0   => "Success",
        1   => "Syntax or usage error",
        2   => "Protocol incompatibility",
        3   => "Errors selecting input/output files, dirs",
        4   => "Requested action not supported: an attempt was made to manipulate 64-bit files on a platform that cannot support them; or an option was specified that is supported by the client and not by the server.",
        5   => "Error starting client-server protocol",
        6   => "Daemon unable to append to log-file",
        10  => "Error in socket I/O",
        11  => "Error in file I/O",
        12  => "Error in rsync protocol data stream",
        13  => "Errors with program diagnostics",
        14  => "Error in IPC code",
        20  => "Received SIGUSR1 or SIGINT",
        21  => "Some error returned by waitpid()",
        22  => "Error allocating core memory buffers",
        23  => "Partial transfer due to error",
        24  => "Partial transfer due to vanished source files",
        25  => "The --max-delete limit stopped deletions",
        30  => "Timeout in data send/receive",
    );

    
    
    unless (-d $dest_dir) {
        print "$me:   destination '$dest_dir' does not exist: creating it\n" if $opts{v};
        my @args = ($mdir, '-p', $dest_dir);
        unless (system(@args) == 0) {
            my $exit_value = $? >> 8;
            warn "$me: *** command '@args' failed: $exit_value\n";
            print "$me: *** command '@args' failed: $exit_value\n" if $config_ref->{'warnings_to_stdout'};
            return ($ERR_DESTDIR_CREATE, undef);
        }
    }


    #
    # rsync options
    #
    my @options = ();
    # changed as of v0.5.0: task options always have precedence
    if ( exists($config_ref->{"$task:rsync_options"}) ) {
        # use task options
        @options = split_params($config_ref->{"$task:rsync_options"});
    } elsif ( exists($config_ref->{'global:rsync_options'}) ) {
        # use global option
        @options = split_params($config_ref->{'global:rsync_options'});
    } else {
        # this as been removed as of versiom 0.5.0; there are no longer default options 
        # use default options
        #@options = @default_global_rsync_options;
        
    }
    
    my $dry_run = 0;

    if ( $mode eq 'rsync') {
        #
        # mode rsync
        #
        #print "$me:   checking rsync options ...\n" if $opts{v};
        push(@options, '-vv') if $opts{d};

        #
        # look for exclude files given in global and task sections of config file
        #
        for my $x_file ('global:exclude_file', "$task:exclude_file") {
            if (exists $config_ref->{$x_file}) {
                my $exclude_file = $config_ref->{$x_file};
                if (-r $exclude_file) {
                    print "$me:   using exclude file $exclude_file\n" if $opts{v};
                    push(@options, "--exclude-from=$exclude_file");
                } else {
                    # continue, but drop a warning
                    warn "$me:     exclude file $exclude_file not readable.\n";
                    print "$me:     exclude file $exclude_file not readable.\n" if $config_ref->{'warnings_to_stdout'};
                }
            }
        }

        #
        # look for rsync option '--dry-run'
        #
        for my $o ('-n', '--dry-run') {
            if ( is_in_array($o, @options) ) {
                print "$me:     option '$o' found, will not rotate.\n" if $opts{v};
                $dry_run = 1;
                last;
            }
        }

        #
        # unless using link-dest, make a hard-link copy of the latest backup, if that exists
        #
        unless ( $use_link_dest ) {
            if (-d $latest_dir) {
                print "$me:     hard-linking latest backup: $latest_dir --> $current_dir\n" if $opts{v};
                my @cmd = ($cp, '-al', $latest_dir, $current_dir);
                unless (system(@cmd) == 0) {
                    my $exit_value = $? >> 8;
                    warn "$me: *** command '@cmd' failed: $exit_value\n";
                    print "$me: *** command '@cmd' failed: $exit_value\n" if $config_ref->{'warnings_to_stdout'};
                    return ($ERR_HLINK_LATEST, undef);
                }
                #
                # update history
                #
                $new_history{1} = $history_ref->{0};
            }
        }
    }

    #
    # backup the source tree to current backup dir
    #
    my @cmd;
    my $exit_value;
    if ( $mode eq 'rsync') {
        #
        # mode rsync
        #
        print "$me:   backup using rsync: $source --> $current_dir\n" if $opts{v};
        if ( $use_link_dest ) {
            push( @options , "--link-dest=$latest_dir");
            print "$me:   link destination is $latest_dir\n" if $opts{v};
        }
        my $args = join(' ', @options) . " $source $current_dir";
        @cmd = ($rsync, $args);
        print "$me:   calling '@cmd'\n" if $opts{d};
        my $exit_code = system("$rsync $args");
        $exit_value = $exit_code >> 8;    # rsync exit value: the higher order byte
        my $rsync_result = "$exit_value ($rsync_exit_text{$exit_value})";
        unless ( $exit_value == 0 ) {
            if ( lc($config_ref->{'ignore_rsync_errors'}) eq 'all' ) {
                print "$me:   all rsync errors are to be ignored\n" if $opts{d};
            } else {
                $backup_failed = not is_in_string($exit_value, $config_ref->{'ignore_rsync_errors'});
                unless ($backup_failed) {
                    print "$me:   rsync error $rsync_result is one of the errors to be ignored\n" if $opts{d};
                }
            }
            if ( $backup_failed ) {
                warn "$me:   rsync error $rsync_result\n";
                print "$me:   rsync error $rsync_result\n" if $config_ref->{'warnings_to_stdout'};
            }
        }
        if ( $backup_failed ) {
            warn "$me:   rsync failed, exit value was $rsync_result\n";
            print "$me:   rsync failed, exit value was $rsync_result\n" if $config_ref->{'warnings_to_stdout'};
        }

    } else {
        #
        # mode link using cp command
        #
        print "$me:   backup by hard-link: $source --> $current_dir\n" if $opts{v};
        @cmd = ($cp, '-alf', $source, $current_dir);
        print "$me:   calling '@cmd'\n" if $opts{d};
        $exit_value = system(@cmd);
        $exit_value = $? >> 8;
        $backup_failed = $exit_value;
    }

    if ( $backup_failed ) {
        #
        # backup failed: undo last operation if not in dry-run mode or undo is not set
        #
        my $error_msg = "$me: *** backup command '@cmd' failed: $exit_value\n";
        warn $error_msg;
        print $error_msg if $config_ref->{'warnings_to_stdout'};
        unless ( $dry_run or ($config_ref->{'if_error_undo'} == 0) ) {
            #
            # remove current backup set
            #
            if (-d $current_dir) {
                print "$me:   removing backup set $current_dir\n" if $opts{v};
                my @args = ($rm, '-rf', $current_dir);
                unless (system(@args) == 0) {
                    my $exit_value = $? >> 8;
                    warn "$me:   *** command '@args' failed: $exit_value\n";
                    print "$me:   *** command '@args' failed: $exit_value\n" if $config_ref->{'warnings_to_stdout'};
                    return($ERR_RM_LATEST, undef);
                }
            }
        }
        return ($ERR_BACKUP, undef);
    }

    print "$me:   backup seems to be ok\n" if $opts{v};

    if ( $dry_run ) {
        #
        # in case of dry-run, there is nothing to do
        #
        print "$me:   rsync will dry-run, skipping rotation of backups\n";
        return (0, $history_ref);
    }

    #
    # update atime, mtime, and history of current backup
    #
    if ( $mode eq 'rsync' ) {
        #
        # mode rsync
        #
        my $now = time;
        utime $now, $now, $current_dir;
        #$new_history{0} = unix2iso_dts($now);
        $history_ref->{0} = unix2iso_dts($now);
    } else {
        #
        # mode link
        #
        my ($atime, $mtime) = (stat($source))[8,9];
        #$new_history{0} = unix2iso_dts($mtime);
        $history_ref->{0} = unix2iso_dts($mtime);
    }


    #
    # rotate backup sets
    #
    # as of version 0.6.4: don't rotate/remove if $bak_name.0 doesn't exist
    # this can happen if an rsnync error was ignored before.
    unless ( -d "$dest_dir/$bak_name.0" ) {
        my $msg = "$dest_dir/$bak_name.0 not found. Rotation of repository skipped.";
        $msg .= " May be a problem of previous rsync job." if $mode eq 'rsync';
        warn "$me: *** $msg";
        print "$me: *** $msg" if $config_ref->{'warnings_to_stdout'};
    } else {    
        # as of version 0.6.2: honor 'update = task'
        # dirty trick: we are setting $keep = 0, temporarily
        my $keep_save = $keep;
        if ( exists($config_ref->{"$task:update"}) ) {
            $keep = 0;
            print "$me:   replacing backup set $bak_name.1 by $bak_name.0\n" if $opts{v};
        } else {
            print "$me:   rotating backup sets $bak_name.0 .. $bak_name.$keep\n" if $opts{v};
        }
        for ( my $from = $keep; $from > -1; $from-- ) {
            my $from_dir = "$dest_dir/$bak_name.$from";
            my $time_stamp = $history_ref->{$from};
            my $to = $from + 1;
            my $to_dir = "$dest_dir/$bak_name.$to";
            my $time_stamp_old = $history_ref->{$to};
            if (-d $from_dir) {
                if ( -d $to_dir ) {
                    # remove existing $to_dir
                    print "$me:     removing old backup set $to_dir ($time_stamp_old)\n" if $opts{v};
                    my @args = ($rm, '-rf', $to_dir);
                    unless ( system(@args) == 0 ) {
                        my $exit_value = $? >> 8;
                        warn "$me: *** command '@args' failed: $exit_value\n";
                        print "$me: *** command '@args' failed: $exit_value\n" if $config_ref->{'warnings_to_stdout'};
                    return($ERR_ROT_PREVIOUS, undef);
                    }
                }
                print "$me:     moving $from_dir to $to_dir ($time_stamp)\n" if $opts{v};
                my @args = ($mv, $from_dir, $to_dir);
                # changed in rsback-0.5.0
                # system(@args) == 0 or die "$me: command '@args' failed: $?\n";
                unless (system(@args) == 0) {
                    my $exit_value = $? >> 8;
                    warn "$me:     *** command '@args' failed: $exit_value\n";
                    print "$me:     *** command '@args' failed: $exit_value\n" if $config_ref->{'warnings_to_stdout'};
                    return ($ERR_ROT_PREVIOUS, undef);
                }
                #
                # update history
                #
                $new_history{$to} = $history_ref->{$from};
                # print "history $i: $history_ref->{$j}\n" if $opts{d};
            } else {
                print "$me:     $from_dir does not exist\n" if $opts{v};
            }
        }   # for ...
    
        #
        # remove oldest backup set
        #
        # If $keep == 0 we don't remove anything, because this was just an update of
        # the most recent backup set
        #
        if ( $keep > 0 ) {
            my $old = $keep + 1;
            my $oldest_dir = "$dest_dir/$bak_name.$old";
            if ( -d $oldest_dir ) {
                my $time_stamp = $history_ref->{$keep};
                print "$me:   removing spare set $oldest_dir ($time_stamp)\n" if $opts{v};
                my @args = ($rm, '-rf', $oldest_dir);
                # changed in rsback-0.5.0
                # system(@args) == 0 or die "$me: command '@args' failed: $?\n";
                unless ( system(@args) == 0 ) {
                    my $exit_value = $? >> 8;
                    warn "$me: *** command '@args' failed: $exit_value\n";
                    print "$me: *** command '@args' failed: $exit_value\n" if $config_ref->{'warnings_to_stdout'};
                    return($ERR_RM_OLD, undef);
                }
            }
        }
        $keep = $keep_save;
    }
    return (0, \%new_history);
}


# -------------------------------------------------------------
#
# init repository (make backup dirs)
#
sub init_repository {
    my ($task, $config_ref) = @_;

    my $dest_dir = $config_ref->{"$task:destination"};
    my $mdir = $config_ref->{'global:mkdir_cmd'};
    $dest_dir =~ s/\/+$//;        # no trailing slashes
    unless (-d $dest_dir) {
        print "$me:   making directory $dest_dir\n" if $opts{v};
        my @args = ($mdir, '-p', $dest_dir);
        system(@args) == 0 or die "$me: command '@args' failed: $!";
    }
}


# -------------------------------------------------------------
#
# build history from mtime of backup sets
#
sub build_history {
    my ($task, $config_ref) = @_;

    my $dest_dir = $config_ref->{"$task:destination"};
    $dest_dir =~ s/\/+$//;        # no trailing slashes
    my ($bak_name, $keep) = split_list($config_ref->{"$task:rotate"});
    my $hist_file = "$dest_dir/history.$bak_name";
    my %history;

    print "$me:   building history from backup repository $dest_dir\n" if $opts{v};
    for my $i (1 .. $keep) {
        my $back_dir = "$dest_dir/$bak_name.$i";
        if (-d $back_dir) {
            my ($atime, $mtime) = (stat($back_dir))[8,9];
            my $m_iso = unix2iso_dts($mtime);
            $history{$i} = $m_iso;
        }
    }
    return %history;
}

# -------------------------------------------------------------
#
# read history into hash (key=number, value=date/time)
#
sub read_history {
    my ($task, $config_ref) = @_;

    my $dest_dir = $config_ref->{"$task:destination"};
    $dest_dir =~ s/\/+$//;        # no trailing slashes
    my ($bak_name, $keep) = split_list($config_ref->{"$task:rotate"});
    my $hist_file = "$dest_dir/history.$bak_name";
    my %history;
    my @missing;
    
    if ( -r $hist_file ) {
        print "$me:   reading history file $hist_file ...\n" if $opts{v};
        open(HF, $hist_file) or die "$me: can't open history file $hist_file: $!\n";
        while (<HF>) {
            chomp;
            my $line = trim($_);        # trim white space
            next if $line eq '';        # ignore empty lines
            next if $line =~ /^[#;]/;   # ignore comment lines
            my ($num, $date_time) = split(/\t+/, $line);
            $history{$num} = $date_time;
            print "$me:     $bak_name.$num\t$date_time\n" if $opts{v};
        }
        close(HF);

        # check history, should not have empty entries
        my $num = 1;
        foreach my $key (sort keys %history) {
            unless ( $key == $num ) {
                push(@missing, $num);
                print "$me:     missing history entry #$num\n" if $opts{v};
            }    
            $num = $key +1;
        }

        # rebuild history if uncomplete
        if ( @missing ) {
            print "$me: *** missing entries (@missing) in history file, rebuild forced.\n";
            warn "$me: *** missing entries (@missing) in history file, rebuild forced.\n" if $config_ref->{'warnings_to_stdout'};
            %history = build_history($task, $config_ref);
        }
    } else {
        print "$me:   no history file found in $dest_dir\n" if $opts{v};
        %history = build_history($task, $config_ref);
    }
    return %history;
}

# -------------------------------------------------------------
#
# write history from hash (key=number, value=date/time)
#
sub write_history {
    my ($task, $config_ref, $history_ref) = @_;

    my $dest_dir = $config_ref->{"$task:destination"};
    $dest_dir =~ s/\/+$//;        # no trailing slashes
    my ($bak_name, $keep) = split_list($config_ref->{"$task:rotate"});
    my $hist_file = "$dest_dir/history.$bak_name";
    open(HF, ">$hist_file") or die "$me: can't write history file '$hist_file': $!\n";
    print "$me:   writing history file $hist_file\n" if $opts{v};
    print HF "# $header\n";
    foreach my $key (1 .. $keep) {
        next unless exists $history_ref->{$key};
        next if $history_ref->{$key} eq '';
        print HF "$key\t$history_ref->{$key}\n";
    }
    close (HF);

}

# -------------------------------------------------------------
#
# check if task is locked
# returns undef if not, otherwise returns true and a list of tasks, which locked us
#
sub task_is_locked {
    my($task, $config_ref) = @_;

    my @lock_list;
    my $lock_dir = $config_ref->{'global:lock_dir'};
    my $lock_file = "$lock_dir/rsback\.$task\.lock";
    return undef unless -f $lock_file;
    
    #
    # we are locked, let's see ...
    #
    print "$me: lock file '$lock_file' found.\n" if $opts{d};
    if (open (LF, $lock_file)) {
        @lock_list = ();
        while (<LF>) {
            chomp;
            push @lock_list;
        }
        close(LF);
    } else {
        warn "$me:   *** can't open lock file $lock_file: $!\n";
        print "$me:   *** can't open lock file $lock_file: $!\n" if $config_ref->{'warnings_to_stdout'};
        push(@lock_list, "*** can't open lock file $lock_file: $!");
    }
    return (1, @lock_list);
}


# -------------------------------------------------------------
#
# lock other tasks
# returns a list of locked tasks
#
sub lock_tasks {
    my($task, $config_ref) = @_;

    my (@tasks_locked, @to_lock);
    my $lock_dir = $config_ref->{'global:lock_dir'};
    if ($config_ref->{"$task:lock"} eq '*') {
        # lock all tasks
        @to_lock = split_list($config_ref->{'global:tasks'});
    } else {
        @to_lock = split_list($config_ref->{"$task:lock"});
        # at least we have to lock our own task
        push(@to_lock, $task);
    }
    return undef unless @to_lock;
    
    my $dts = iso_dts();
    foreach my $other_task (@to_lock) {
        my $lock_file = "$lock_dir/rsback\.$other_task\.lock";
        #
        # May be, another task wants to lock us too;
        # so, open lock file in append mode
        #
        if (open (LF, ">>$lock_file")) {
            # write task name, pid and date/time
            print LF "$$\t$task\t$dts\n";
            close(LF);
            print "$me: locked task $other_task\n" if $opts{v};
            push(@tasks_locked, $other_task);
        } else {
            # we can't create a lock file
            # just print a warning and go on
            warn "$me: *** can't create lock file $lock_file: $!\n";
            print "$me: *** can't create lock file $lock_file: $!\n" if $config_ref->{'warnings_to_stdout'};
            next;
        }
    }
    return @tasks_locked;
}

# -------------------------------------------------------------
#
# get the names of lock files which are locking this task
#
sub get_lock_files {
    my($task, $config_ref) = @_;
    my $lock_dir = $config_ref->{'global:lock_dir'};
    my @lock_files;
    unless (opendir(DIR, $lock_dir)) {
        warn "$me:    *** can't opendir $lock_dir: $!\n";
        print "$me:    *** can't opendir $lock_dir: $!\n" if $config_ref->{'warnings_to_stdout'};
        return undef;
    }
    my @files = redadir(DIR);
    closedir(DIR);
    foreach my $file (@files) {
        # get all files like 'rsback.task.lock'
        push(@lock_files, $file) if $file =~ /$me\..+\.lock$/;
    }
    return @lock_files;
}

# -------------------------------------------------------------
#
# unlock tasks
#
sub unlock_tasks {
    my($tasks_ref, $config_ref) = @_;

    my $lock_dir = $config_ref->{'global:lock_dir'};
    
    
    foreach my $task (@$tasks_ref) {
        my $lock_file = "$lock_dir/rsback\.$task\.lock";
        if ( -e $lock_file ) {
            print "$me: unlocking task '$task'\n" if $opts{v};
            unless ( -w $lock_file ) {
                warn "$me: *** lock file '$lock_file' is not writable, cannot be removed.\n";
                print "$me: *** lock file '$lock_file' is not writable, cannot be removed.\n"  if $config_ref->{'warnings_to_stdout'};
            } else {
                unlink $lock_file if -w $lock_file;
                print "$me: lock file '$lock_file' removed\n" if $opts{d};
            }
        } else {
            warn "$me: *** lock file '$lock_file' not found\n";
            print "$me: *** lock file '$lock_file' not found\n"  if $config_ref->{'warnings_to_stdout'};
        }
    }
}

#---------------------------------------------------------------
#
# read config file
#
# returns a hash of params if successfull, otherwhise returns undef
#
sub read_config {
    #  file name, server name, list of required parameters
    my ($conf_file) = @_;

    my (%config);
    my $last_line = '';
    
    open (CNF, $conf_file) or die "$me: can't open config file '$conf_file': $!\n";
    print "$me: reading config file '$conf_file' ...\n" if $opts{d};

    my $section = '';
        while (<CNF>) {
            chomp;
            my $line = trim($_);        # trim white space
            next if $line eq '';        # ignore empty lines
            next if $line =~ /^[#;]/;    # ignore comment lines
            
            if ($last_line ne '') {        # append next line
                $line = "$last_line $line";
                $last_line = '';
            }
            if ($line =~ s/\\$//) {        # continuation line follows
                $last_line = trim($line);
                next;
            } else {
                $last_line = '';
            }

            my $sec = get_section($line);
            if ($sec) {
                # it's a section, something like '[foobar]'
                $section = $sec;
            print "$me: [$section]\n" if $opts{d};
            } elsif ($section ne '') {
                # check for 'param = value' pairs
                my ($param, $value) = get_param_value($line);
                if ($param) {
                    # it's a line like 'param = value'
                    $config{"$section:$param"} = $value;
                    print "$me:   $section:$param = '$value'\n" if $opts{d};
                    # complete other params if 'update = <task>' was found
                    if ( $param eq 'update' ) {
                        if ( exists $config{"$value:source"} ) {
                            print"$me:   'update = $value found', completing params with those of section '$value'\n" if $opts{d};
                            while ( my ($k, $v) = each(%config) ) {
                                my ($t, $p) = split(/:/, $k);
                                if ( $t eq $value ) {
                                    $config{"$section:$p"} = $v; 
                                    print "$me:    $section:$p = '$v'\n" if $opts{d};
                                }
                            }
                        } else {
                            
                            print "$me: *** $conf_file: task refered in '$section:update = $value' not found\n" if $config{'warnings_to_stdout'};
                            die "$me: *** $conf_file: task refered in '$section:update = $value' not found\n";
                        }
                    }
                };
            };
        }
        close(CNF);

    # tasks under [global] must exist
    die "$me: no [global] section found in config file '$conf_file'\n" unless exists $config{'global:tasks'};

    #
    # collect required params
    #
    my @required = (
        'global:tasks',
        'global:rsync_cmd',
        'global:cp_cmd',
        'global:mv_cmd',
        'global:rm_cmd',
        'global:mkdir_cmd',
        'global:lock_dir',
        'global:rsync_options',
    );

    foreach my $param(split_list($config{'global:tasks'})) {
        push @required, "$param:source" , "$param:destination", "$param:mode", , "$param:rotate";
    }


    #
    # check for required params
    #
    my $param_cnt = keys %config;
    if (keys(%config)) {
        my $missing = 0;
        foreach my $param(@required) {
            unless (exists($config{$param})) {
                $missing++;
                print "$me: *** $conf_file: require paramter $param\n";
                warn "$me: *** $conf_file: require paramter $param\n";
            }
        }
        die "$me: *** $conf_file: configuration not complete\n" if ($missing);
    } else {
        die "$me: *** no configuration parameters found in '$conf_file'\n";
    }

    print "$me: config file '$conf_file' OK\n" if $opts{d};
    return %config;
}

#---------------------------------------------------------------
#
# Get a section name, something like '[foobar]'?
# Section names may contain alphanumerical characters including '_' and '-'.
#
sub get_section {
    my ($string) = @_;
        if ($string =~ s/^\[(.+)\]$/$1/) {
                return trim($1);
        } else {
                return undef;
        };
};


#---------------------------------------------------------------
#
# Get a 'param = value' pair
#
sub get_param_value {
    my ($string) = @_;
    my ($param, $value) = split(/\s*=\s*/, $string, 2);
    if ($param && $value) {
        return ($param, $value);
    } else {
        return undef;
    };
};


#---------------------------------------------------------------
#
# Trim leading and trailing white space
#

sub trim {
    my ($string) = @_;

    $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        $string;
};

#---------------------------------------------------------------
#
# Trim leading and trailing delimiters
#

sub trim_delimters {
    my ($string) = @_;

    $string =~ s/^[\s,;]+//;
    $string =~ s/[\s,;]+$//;
    return $string;
};

#---------------------------------------------------------------
#
# Split a string consisting of a list of parameters
# separated by commas, semicolons, or white space
# and return the parameters in an array
#

sub split_list {
    my ($list) = @_ or return undef;
    my @params;
    @params = split(/[\s,;]+/,$list);
    return @params;
};

#---------------------------------------------------------------
#
# Split a string consisting of a list of parameters
# separated by commas, semicolons, or white space
# and return the parameters in an array.
# A quoted sub-list will be returned as one single parameter.
#

sub split_params {
    my ($list) = @_;
    my @params;
    my $dq = "\"";
    my $sq = "'";
    
    # loop over the list until it's empty
    while ($list ne '') {
        $list = trim_delimters($list);
        my $remainder = '';
        my $p = '';
        if ( $list =~ /^($dq[^$dq]*?$dq)(.*?)$/o ) {        # double-quoted parameter list?
            $p = $1;
            $remainder = $2;
        } elsif ( $list =~ /^($sq[^$sq]*?$sq)(.*?)$/o ) {    # single-quoted parameter list?
            $p = $1;
            $remainder = $2;
        } else {                                    # not quoted
            ($p, $remainder) = split(/[\s,;]+/, $list, 2);

        }
        push(@params, $p);
        $list = $remainder;
    }
    return @params;
};


#---------------------------------------------------------------
#
# Search string in an array
#
# return index >= 0 if found
#

sub is_in_array {
    my ($str, @array) = @_;
    my $i = -1;

    # print "[iia] array= @array\n";
    foreach my $item (@array) {
        $i++;
        # print "[iia] i=$i, cell='$item'\n" if $item eq $str;
        return 1 if $item eq $str;
    }
    return undef;
}

#---------------------------------------------------------------
#
# Search word within a string
#
# return index >=0 if found
#

sub is_in_string {
    my ($word, $string) = @_;
    my @list = split_list($string);
    my $found = is_in_array($word, @list);
    return $found;
}

#---------------------------------------------------------------
#
# Convert Unix time to date/time string (ISO-8601)
#
sub unix2iso_dts {
    my ($t) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($t);
    my $iso = sprintf ("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    return $iso;
};


#---------------------------------------------------------------
#
# Convert time to date/time string (ISO-8601)
#
sub iso_dts {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    my $now = sprintf ("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    return $now;
};

#---------------------------------------------------------------
#
# Convert seconds to HH:MM:SS
#
sub s2hms {
    my ($seconds) = @_;

    my $h = int($seconds / 3600);
    $seconds = $seconds - $h * 3600;

    my $m = int($seconds / 60);
    $seconds = $seconds - $m * 60;

    my $hms = sprintf("%02d:%02d:%02d", $h, $m, $seconds);
    return $hms;
}

#---------------------------------------------------------------
#
# POD follows ...
#

__END__

