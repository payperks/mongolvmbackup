#!/bin/bash -e


# mongolvmbackup v0.03
#
# Backup the local MongoDB database by:
#
#  1)   fsync+lock mongodb
#  2)   lvm snapshot mongodb's data volume
#  3)   unlock mongodb
#  4)   bzip2 the snapshot into tempdir
#  4.1) symlink 'latest.tbz2' to the snapshot we just took
#  5)   destroy snapshot
#


# Copyright (c) 2012, PayPerks, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#  * Neither the name of PayPerks, Inc. nor the names of its contributors may
#    be used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.



# =============================================================================
#    CONFIGURATION SECTION

# Where compressed backup will be temporarily staged for transmission to S3
TARGET_DIR=/mnt/mongosnaps


# How long to keep backups around on local storage.  This is ephemeral so must
# never be relied upon, but if it does survive your disaster it's quicker than
# downloading from S3.
LOCAL_RETENTION_DAYS=7

# Compression program & level.  Tweak this to get better/faster compression.
COMPRESS_PROG=bzip2
COMPRESS_SUFFIX=tbz2
COMPRESS_LEVEL=6


#    END CONFIG SECTION
# =============================================================================




print_help() {
  echo
  echo "$0: -g <lvmgroup> -v <lvmvolume> -b <s3 bucket>"
  echo
  echo "Snapshot & compress MongoDB databases present on this host.  Place them in"
  echo "$TARGET_DIR and create a 'latest' symlink."
  echo
  exit 0
}


# Check for some required utilities
command lvcreate --help >/dev/null 2>&1 || { echo "Error: lvcreate is required.  Cannot continue."; exit 1; }
command lvremove --help >/dev/null 2>&1 || { echo "Error: lvremove is required.  Cannot continue."; exit 1; }
command $COMPRESS_PROG -V >/dev/null 2>&1 || { echo "Error: compression util required.  Cannot continue."; exit 1; }



# Process CLI options
s3bucket=''
vgroup=''
volume=''

while [ $# -gt 0 ]
do
  case $1 in
    -h) print_help ;;
    --help) print_help ;;
    -b) s3bucket=$2 ; shift 2 ;;
    -g) vgroup=$2 ; shift 2 ;;
    -v) volume=$2 ; shift 2 ;;
    *) shift 1 ;;
  esac
done


# Check volume is really set
if [ "$vgroup" == "" ]
then
  echo "No group set, won't continue"
  exit 1
fi
if [ "$volume" == "" ]
then
  echo "No volume set, won't continue"
  exit 1
fi


# Check volume is a real LVM volume
if ! lvdisplay "/dev/$vgroup/$volume" >/dev/null 2>/dev/null
then
  echo "/dev/$vgroup/$volume is not a real LVM volume!"
  exit 1
fi


# Figure out where to put it
date=`date +%F_%H%M`
targetfile="${volume}-${date}-snap.${COMPRESS_SUFFIX}"


# =============================================================================
# Print a meaningful banner!


echo "==================== LVM MONGODB SNAPSHOT SCRIPT ====================="
echo
echo "  Snapshotting: /dev/${vgroup}/${volume}"
echo "  Target:       ${TARGET_DIR}/${targetfile}"
echo



# Create target dir if not extant
if [ ! -d "$TARGET_DIR" ]
then
  echo "Your target dir ${TARGET_DIR} doesn't exist and I'm too cowardly to create it"
  exit 1
fi




# Create the snapshot
snapvol="$volume-snap"
echo "Freezing MongoDB before LVM snapshot"
mongo -eval "db.fsyncLock()"
echo
echo "Taking snapshot $snapvol"
lvcreate --snapshot "/dev/$vgroup/$volume" --name "$snapvol" --extents '90%FREE'
echo
echo "Snapshot OK; unfreezing DB"
mongo -eval "db.fsyncUnlock()"
echo
echo

# Mount the snapshot
mountpoint=`mktemp -t -d mount.mongolvmbackup_XXX`
mount -v -o ro "/dev/${vgroup}/${snapvol}" "${mountpoint}"
echo

# Remove backups older than $LOCAL_RETENTION_DAYS to free up space now.
# Do this as late as possible in case the failure develops; we do not want
# to cycle the last remining backups away when not taking more!
find "$TARGET_DIR" -iname "*-snap.${COMPRESS_SUFFIX}" -mtime +${LOCAL_RETENTION_DAYS} -delete
echo

# Compress the data into a file in our target dir
echo "Compressing snapshot into ${TARGET_DIR}/${targetfile}"
cd "${mountpoint}"
tar cv * | $COMPRESS_PROG "-${COMPRESS_LEVEL}" -c > "${TARGET_DIR}/${targetfile}"
echo
cd -
cd "$TARGET_DIR"
rm -vf latest.${COMPRESS_SUFFIX}
ln -v -s ${targetfile} latest.${COMPRESS_SUFFIX}
cd -

echo
echo


# Unmount & remove temp snapshot
echo "Removing temporary volume..."
umount -v "$mountpoint"
rm -rvf "$mountpoint"
echo
lvremove -f "/dev/${vgroup}/${snapvol}"
echo
echo


