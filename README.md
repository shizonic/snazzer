snazzer
=======

btrfs snapshotting and backup system offering snapshot measurement, transport
and pruning.

* `snazzer-prune-candidates`: [![Build Status](https://secure.travis-ci.org/csirac2/snazzer.png)](https://travis-ci.org/csirac2/snazzer)

Features
--------

* Minimal dependencies (portable-ish sh script, mostly checked with http://shellcheck.nett)
* Maintains snapshots for each subvol under
  `subvol/.snapshotz/YYYY-MM-DDTHHMMSS+hhmm` i.e. a valid isodate
* Operates on specific subvols, all subvols on a filesystem, or all
  subvols on all mounted filesystems, Eg: `snazzer --all`
* Operations include snapshotting (default), `--measure` (sha512sum &
  PGP signatures of snapshots), `--prune` (deleting snapshots except for
  those required to meet configured number of
  hourlies/daylies/monthlies/yearlies to keep)
* `snazzer-receive` operates on remote hosts for specific subvols, all
  subvols on a filesystem, or all subvols on all mounted filesystems,
  Eg: `snazzer-receive somehost --all` (or `snazzer-receive -- --all` to
  receive local paths without ssh in the middle)
* Automated regression testing (TODO: snazzer-receive)
  
Getting started
---------------

### Documentation

The full documentation for each part of snazzer is available as follows:

    snazzer --man                  # Create, prune and measure snapshots
    snazzer-receive --man          # Receive remote snapshots over ssh
    
Supporting scripts are also fully documented:

    snazzer-measure --man          # Support script, used by snazzer
    snazzer-send-wrapper --man     # Support script, snazzer-receive ssh wrapper
    snazzer-prune-candidates --man # Support script, used by snazzer[-receive]
    
These man pages are also available at:
* https://github.com/csirac2/snazzer/blob/master/doc/snazzer.md
* https://github.com/csirac2/snazzer/blob/master/doc/snazzer-receive.md
* https://github.com/csirac2/snazzer/blob/master/doc/snazzer-measure.md
* https://github.com/csirac2/snazzer/blob/master/doc/snazzer-send-wrapper.md
* https://github.com/csirac2/snazzer/blob/master/doc/snazzer-prune-candidates.md

### Generate and mount a test btrfs filesystem image

    snazzer --generate-test-img ~/test.img
    mount ~/test.img /mnt
    
### Snapshotting and pruning

Snapshots are maintained in a directory under `.snapshotz` of the root of each btrfs subvolume. Snapshots are named as valid isodates in the form of `YYYY-MM-DDTHHMMSS+hhmm` (or `YYYY-MM-DDTHHMMSSZ` if `SNAZZER_USE_UTC` is set) under this directory. Here's the output of `sudo tree -a /mnt/home` after two snapshots have been created and measured:

    /mnt/home
    ├── home_junk
    └── .snapshotz
        ├── 2015-04-16T115421+1000
        │   ├── home_junk
        │   ├── .snapshot_measurements.exclude
        │   └── .snapshotz
        ├── 2015-04-16T160810+1000
        │   ├── home_junk
        │   ├── .snapshot_measurements.exclude
        │   └── .snapshotz
        │       ├── 2015-04-16T115421+1000
        │       └── .measurements
        │           └── 2015-04-16T115421+1000
        └── .measurements
            ├── 2015-04-16T115421+1000
            └── 2015-04-16T160810+1000
        
Example usage to snapshot all subvolumes in the btrfs filesystem mounted under `/mnt`:

    snazzer --all /mnt
    snazzer --all /mnt # create another snapshot
    snazzer --all /mnt # create another snapshot
    # have unneeded snapshots now, prune them:
    snazzer --prune --force --all /mnt

### Measuring snapshots

`snazzer` offers a way to generate reproducible measurements for snapshots under its management. These measurements are reports generated by `snazzer-measure` and they include `du -bs`, `sha512sum` and `gpg2` signatures. These measurements may be performed on the original host, or any other machines receiving and handling snapshots along the way (Eg. via `snazzer-receive`). `snazzer` appends the output of `snazzer-measure` to text files in `.snapshotz/.measurements` with the same names as the snapshots they have measured under `.snapshotz`, so for example a snapshot at `/mnt/home/.snapshotz/2015-04-16T115421+1000` will have measurement results appended to `/mnt/home/.snapshotz/.measurements/2015-04-16T115421+1000`.

This example will generate measurements for all snapshots of all subvolumes under the btrfs filesystem mounted at `/mnt`:

    snazzer --measure --all /mnt

Here's an example measurement result found at  `/mnt/home/.snapshotz/.measurements/2015-04-16T115421+1000` (example only). Note that the commands listed to reproduce the results (lines beginning and ending with parentheses) should work consistently regardless of whether the snapshot directory is on a btrfs filesystem or not:

    ################################################################################
    > on host1 at 2015-04-16T155828+1000, du bytes:
    (du -bs --one-file-system --exclude-from '../2015-04-16T115421+1000/.snapshot_measurements.exclude' '../2015-04-16T115421+1000')
    512098  /mnt/home/.snapshotz/2015-04-16T115421+1000
    
    > on host1 at 2015-04-16T155828+1000, sha512sum:
    (find '../2015-04-16T115421+1000' -xdev -not -path '../2015-04-16T115421+1000' -printf '%P\0' | LC_ALL=C sort -z | tar --no-recursion --one-file-system --preserve-permissions --numeric-owner --null --create --to-stdout --directory '../2015-04-16T115421+1000' --files-from - --exclude-from '../2015-04-16T115421+1000/.snapshot_measurements.exclude' | sha512sum -b)
    c5626e1e6036d317ac98e5ed185b9c5520e4eba67becd250fc1b6fc94574cbc483b9ca677b1f69e8691d0ad4cb17c9b07f0084271b8e11e95915fadb6ced473c *-
    > on host1 at 2015-04-16T155829+1000, gpg:
    (SIG=$(mktemp) && grep -v '/,/' '2015-04-16T115421+1000' | sed -n '/> on host1 at 2015-04-16T155829+1000, gpg:/,/-----END PGP SIGNATURE-----/ { /-----BEGIN PGP SIGNATURE-----/{x;d}; H }; ${x;p}' >"$SIG" && find '../2015-04-16T115421+1000' -xdev -not -path '../2015-04-16T115421+1000' -printf '%P\0' | LC_ALL=C sort -z | tar --no-recursion --one-file-system --preserve-permissions --numeric-owner --null --create --to-stdout --directory '../2015-04-16T115421+1000' --files-from - --exclude-from '../2015-04-16T115421+1000/.snapshot_measurements.exclude' | gpg2 --verify "$SIG" - && rm "$SIG")
    -----BEGIN PGP SIGNATURE-----
    Version: GnuPG v2
    <snip!>
    -----END PGP SIGNATURE-----
    
    > on host1 at 2015-04-16T155840+1000, tar info:
    tar (GNU tar) 1.27.1 --format=gnu -f- -b20 --quoting-style=escape --rmt-command=/usr/lib/tar/rmt --rsh-command=/usr/bin/rsh

Now observe that running the same command again, `snazzer` is smart enough to skip re-measuring snapshots which have already been measured by this host (use --force to override this behaviour):

    snazzer --measure --all /mnt

Some observations:
* Yes, the verification commands are huge and ugly, but eminently reproducible.
* Each snapshot root contains a carefully maintained list of subvolumes which
  existed under it at the time of the snapshot in a file named
  `.snapshot_measurments.exclude`. This is to work around a btrfs bug which
  means certain empty directories within snapshots have bogus atimes, see
  https://bugzilla.kernel.org/show_bug.cgi?id=95201

### Receive snapshots from a remote system

Receive all missing `snazzer` managed btrfs snapshots, along with any measurement files they may have, from the host `host1` via ssh to the current working directory:

    cd /media/backup-drive/hosts/host1
    snazzer-receive host1 --all

The example above assumes a valid working ssh configuration and properly configured `/etc/sudoers` on `host1`. Refer to `snazzer-receive --man` for configuration hints.

### Receive snapshots from a local filesystem to local backup media

Receive all missing `snazzer` managed btrfs snapshots on the local system, along with any measurement files they may have, into btrfs subvolumes maintained under the current working directory:

    cd /media/backup-drive/hosts/host1
    snazzer-receive -- --all

Inspiration
-----------
Most mature backup solutions do not leverage btrfs features, particularly
copy-on-write snapshots or send/receive transport. This makes it too easy to end
up with VMs needlessly struggling with disk I/O throughput for hours per day
when a btrfs snapshot and send/receive operation would take minutes or even
seconds.

SuSE's `snapper` project was interesting enough to provide inspiration for the
naming of `snazzer`, but seems focused on supporting recovery from sysadmin
tasks and thus complements rather than provides a coherent basis for a
distributed backup solution. Additionally, whilst SuSE's `snapper` has few
dependencies we thought it would be possible to provide something using exactly
zero dependencies beyond only very basic core utilities present on even minimal
installation of any given distro.

Immediate goals and assumptions
-------------------------------
* Leverage btrfs (and eventually zfs?) snapshots, send/receive features as the
  basis for _one part_ an efficient backup system.
* Provide easily reproducible sha512sum, GPG signatures etc. of snapshots to
  detect any btrfs shenanigans or malicious tampering.
* Zero config, or at least issue helpful _easily actionable_ error messages and
  sanity checks along the way.
* Zero dependencies, or as close as we can get. `snazzer-prune-candidates` uses
  perl, a core part of some distros but not others; python version coming soon.
* Simple architecture without databases, XML config or daemons.

Longer-term goals
-----------------
* Seamlessly support ZFS On Linux instead of or in addition to btrfs
* Implement `snazzer-prune-candidates` in a python version for those distros
  which have standardized on python rather than perl as part of base packages
* Distro packaging, starting with Debian. Lots of debconf to help alleviate
  `snazzer-receive` config tedium.
* Automated distro testing infrastructure
* Remove any lingering GNU-isms and keep POSIX sh code portable to BSDs for
  FreeBSD and OpenIndiana compatibility (assuming `snazzer` makes sense there)

License and Copyright
---------------------

Copyright (c) 2015, Paul Harvey <csirac2@gmail.com> All rights reserved.

This project uses the 2-clause Simplified BSD License.
