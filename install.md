
To install flashback...

# Make sure you have the prerequisites.

    apt-get install python rsync make

# Get the source from github.

    git clone https://github.com/sudoer/flashback

# Run "make install".

    cd flashback
    make install

# Set up config files.

    cp /usr/share/doc/flashback/examples/* /etc
    vim /etc/flashback.*

# Mount the partition where you will store the backups.

    fdisk /dev/sdb
    mkfs.ext4 /dev/sdb1
    mkdir /backup
    mount /dev/sdb1 /backup
    vim /etc/fstab

# Start the flashback service.

    service flashback start

# Verify that it is running.

    cat /var/lib/flashback/status
    cat /var/lib/flashback/queue

# Add a monitor script.

    vim /etc/rc.local



