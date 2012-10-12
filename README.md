mongolvmbackup
==============

A tool for backing up your MongoDB datasets with almost no downtime.  It accomplishes this MongoDB's fsync* commands and LVM snapshotting (so requires your DB volume be created in LVM!).

Features:
* Roughly follows suggestions made in the [MongoDB](http://docs.mongodb.org/manual/administration/backups/) [docs](http://www.mongodb.org/display/DOCS/Backups).
* Lock MongoDB only briefly while the snapshot is being created.  Usually this takes only a couple of seconds; after that it's business as usual.
* A symlink to the latest backup is created to aid with restores and help other scripts find your data to send it offsite.
* Compress with bzip2 by default; other algorithms are supported
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
By default mongolvmbackup uses bzip2: it's available on almost all Linux systems and good enough for most needs.  However if you're backing up really big datasets on a modern host with more than one CPU you'll find moving to a parallel compression util makes things a lot faster.  Try pbzip2 or pigz.

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
 * Test db.fsyncLock() really worked
* Pre & post backup hooks
* Save in backup some metadata about the host & mongodb config


##History
* Originally created by Alex Hewson (alex@payperks.com)

<table>
  <tr>
    <th>Version</th><th>Date</th><th>Notes</th>
  </tr>
  <tr>
    <td>0.01</td><td>2012-10-12</td><td>First release</td>
  </tr>
</table>


##License
Copyright 2012 PayPerks, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.