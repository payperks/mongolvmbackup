mongolvmbackup
==============

NOTE: This tool is not maintained anymore.  USE AT YOUR OWN RISK.  Other forks of this code might be more useful.

A tool for backing up your MongoDB datasets with almost no downtime.  It accomplishes this MongoDB's fsync* commands and LVM snapshotting (so requires your DB volume be created in LVM!).

Features:
* Roughly follows suggestions made in the [MongoDB](http://docs.mongodb.org/manual/administration/backups/) [docs](http://www.mongodb.org/display/DOCS/Backups).
* Lock MongoDB only briefly while the snapshot is being created.  Usually this takes only a couple of seconds; after that it's business as usual.
* A symlink to the latest backup is created to aid with restores and help other scripts find your data to send it offsite.
* Compress with gzip by default; other algorithms are supported
* Remove compressed backups older than N days
* Works with shards if you run a mongolvmbackup for each shard, but results [may not be consistent](http://www.mongodb.org/display/DOCS/Backing+Up+Sharded+Cluster)


__WARNING:__ Mongolvmbackup is to be used entirely at your own risk.  That said it's believed to be safe and we use it on production hosts.  

__WARNING:__ This is pre-1.0 quality.  See the todo section.

__WARNING:__ An untested backup system is worse than none at all.  Periodically test your backups. 


##Usage
        ./mongolvmbackup.sh -g <volumegroup> -v <volume>

e.g. for a LVM mongodb data volume at /dev/myvolgroup/mongodata:
  ./mongolvmbackup.sh -g myvolgroup -v mongodata

It requires:
* your data be held on a LVM volume
* some space left in that pv for the snapshot
* root


## Tips & Tricks
### Faster Compression
By default mongolvmbackup uses gzip: it's available on almost all Linux systems and good enough for most needs.  However if you're backing up really big datasets on a modern host with more than one CPU you'll find moving to a parallel compression util makes things a lot faster.  Try pbzip2 or pigz.

### Use Multiple Disks
On all but the slowest hosts mongolvmbackup will be bound by the read speed of your mongodb data volume.  It'll help if your target (where you're writing the compressed backup) is not on the same physical disk or Amazon EBS volume.

### Backup from a Slave
Although MongoDB is only locked against writes for a couple of seconds its performance on this host will take a hit while mongolvmbackup is reading and compressing the snapshot.  You may find it results in performance too slow for production.  

In this case try setting up a dedicated host for backups in a replicaset and running mongolvmbackup on /that/ so your master is unaffected.  Make sure that this replica is 'hidden' and has a priority of 0 so no production queries will be directed to it.


## Successes
At PayPerks Inc. we use this script to backup from our production MongoDB clusters.  Since we use a dedicated replica for taking backups an m1.small is sufficient; once the snapshot's taken we don't mind if it takes an hour or so to compress the data.

## FAQ
* Why the name? - Because a long-popular tool for backing up MySQL using LVM is called '[mylvmbackup](http://www.lenzg.net/mylvmbackup/)'.  It seemed logical for a MongoDB equivalent to follow the same scheme.
* You're on AWS.  Couldn't you do this with a regular EBS snapshot?  - Sure, but automating this would be a pain.  We find it easier to do inside a machine we control and this means we can also script a transfer of the backup offsite.
* I found a bug!  - Good.  Hope it didn't bite.  Plz to report it to alex@payperks.com.


## Todo
* More paranoia
 * When creating snapshot
 * Check target FS has enough free space
* Pre & post backup hooks
* Save in backup some metadata about the host & mongodb config


##History
* Originally created by Alex Hewson (alex@payperks.com, https://github.com/alexmbird)

<table>
  <tr>
    <th>Version</th><th>Date</th><th>Notes</th>
  </tr>
  <tr>
    <td>0.01</td><td>2012-10-12</td><td>First release</td>
  </tr>
  <tr>
    <td>0.02</td><td>2012-10-12</td><td>Minor fixes</td>
  </tr>
  <tr>
    <td>0.03</td><td>2012-10-12</td><td>Abandon <a href='https://forums.aws.amazon.com/message.jspa?messageID=254579'>futile</a> attempt at path-independence</td>
  </tr>
    <tr>
    <td>0.10</td><td>2016-05-12</td><td>Updates mongolvmbackup.sh by cprato79 including: Workaround for mount the lvm snapshot volume, Changed to gzip as default compression tool, Added login parameters if mongo auth it is enabled, Added check if mongo it has been locked before snapshot when it's requires, Added mongo version check for lock database only when MDB is minor then 3.2.x and the Engine is wiredtiger.</td>
  </tr>
</table>


##License

Copyright (c) 2012-2017, PayPerks, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
* Neither the name of PayPerks, Inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

