#!/bin/bash

function zaloha_docu {
  less << 'ZALOHADOCU'
###########################################################

MIT License

Copyright (c) 2019 Fitus

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

###########################################################

OVERVIEW

Zaloha is a small and simple directory synchronizer:

 * Zaloha is a BASH script that uses only FIND, SORT and AWK. All you need
   is THIS file. For documentation, also read THIS file.
 * Cyber-secure: No new binary code, no new open ports, easily reviewable.
 * Both <sourceDir> and <backupDir> must be available locally (local HDD/SSD,
   flash drive, mounted Samba or NFS volume).
 * Zaloha does not lock files while copying them. No writing on either directory
   may occur while Zaloha runs.
 * Zaloha always copies whole files (not parts of files like RSYNC). This is,
   however, fully sufficient in many situations.
 * Zaloha has optional reverse-synchronization features (details below).
 * Zaloha can optionally compare files byte by byte (details below).
 * Zaloha prepares scripts for case of eventual restore (details below).

To detect which files need synchronization, Zaloha compares file sizes and
modification times. It is clear that such detection is not 100% waterproof.
A waterproof solution requires comparing file contents, e.g. via "byte by byte"
comparison or via SHA-256 hashes. However, such comparing would increase the
runtime by orders of magnitude. Therefore, it is not enabled by default.
Section Advanced Use of Zaloha describes two alternatives how to enable or
implement it.

Zaloha asks to confirm actions before they are executed, i.e. prepared actions
can be skipped, exceptional cases manually resolved, and Zaloha re-run.
For automatic operations, use the "--noExec" option to tell Zaloha to not ask
and to not execute the actions (but still prepare the scripts).

<sourceDir> and <backupDir> can be on different filesystem types if the
filesystem limitations are not hit. Such limitations are (e.g. in case of
ext4 -> FAT): not allowed characters in filenames, filename uppercase
conversions, file size limits, etc.

No writing on either directory may occur while Zaloha runs (no file locking is
implemented). In high-availability IT operations, a higher class of backup
solution should be deployed, based on taking filesystem snapshots at times when
writing processes are stopped for a short instant (i.e. functionality that must
be supported by the underlying OS). If either directory contains data files
of running databases, then they must be excluded from backups on file level.
Databases have their own logic of backups, replications and failovers, usually
based on transactional logs, and it is plainly wrong to intervene with generic
tools that operate on files and directories. Dedicated tools provided by the
database vendor shall be used.

Handling of "weird" characters in filenames was a special focus during
development of Zaloha (details below).

On Linux/Unics, Zaloha runs natively. On Windows, Cygwin is needed.

Repository: https://github.com/Fitus/Zaloha.sh

An add-on script to create hardlink-based snapshots of the backup directory
exists, that allows to create "Time Machine"-like backup solutions:

Repository of add-on script: https://github.com/Fitus/Zaloha_Snapshot.sh

###########################################################

MORE DETAILED DESCRIPTION

The operation of Zaloha can be partitioned into five steps, in that following
actions are performed:

Exec1:  unavoidable removals from <backupDir> (objects of conflicting types
        which occupy needed namespace)
-----------------------------------
RMDIR     regular remove directory from <backupDir>
REMOVE    regular remove file from <backupDir>
REMOVE.!  remove file from <backupDir> which is newer than the
          last run of Zaloha
REMOVE.l  remove symbolic link from <backupDir>
REMOVE.x  remove other object from <backupDir>, x = object type (p/s/c/b/D)

Exec2:  copy files/directories to <backupDir> which exist only in <sourceDir>,
        or files which are newer in <sourceDir>
-----------------------------------
MKDIR     regular create new directory in <backupDir>
NEW       regular create new file in <backupDir>
UPDATE    regular update file in <backupDir>
UPDATE.!  update file in <backupDir> which is newer than the last run of Zaloha
UPDATE.?  update file in <backupDir> by a file in <sourceDir> which is not newer
          (or not newer by 3600 secs if option "--ok3600s" is given plus
           an eventual 2 secs FAT tolerance)
unl.UP    unlink file in <backupDir> + UPDATE (can be switched off via the
          "--noUnlink" option, see below)
unl.UP.!  unlink file in <backupDir> + UPDATE.! (can be switched off via the
          "--noUnlink" option, see below)
unl.UP.?  unlink file in <backupDir> + UPDATE.? (can be switched off via the
          "--noUnlink" option, see below)
ATTR:ugm  update only attributes in <backupDir> (u=user ownership,
          g=group ownership, m=mode) (optional feature, see below)

Exec3:  reverse-synchronization from <backupDir> to <sourceDir> (optional
        feature, can be activated via the "--revNew" and "--revUp" options)
-----------------------------------
REV.MKDI  reverse-create parent directory in <sourceDir> due to REV.NEW
REV.NEW   reverse-create file in <sourceDir> (if a standalone file in
          <backupDir> is newer than the last run of Zaloha)
REV.UP    reverse-update file in <sourceDir> (if the file in <backupDir>
          is newer than the file in <sourceDir>)
REV.UP.!  reverse-update file in <sourceDir> which is newer
          than the last run of Zaloha (or newer than the last run of Zaloha
          minus 3600 secs if option "--ok3600s" is given)

Exec4:  remaining removals of obsolete files/directories from <backupDir>
        (can be optionally switched off via the "--noRemove" option)
-----------------------------------
RMDIR     regular remove directory from <backupDir>
REMOVE    regular remove file from <backupDir>
REMOVE.!  remove file from <backupDir> which is newer than the
          last run of Zaloha
REMOVE.l  remove symbolic link from <backupDir>
REMOVE.x  remove other object from <backupDir>, x = object type (p/s/c/b/D)

Exec5:  updates resulting from optional "byte by byte" comparing of files
        (optional feature, can be activated via the "--byteByByte" option)
-----------------------------------
UPDATE.b  update file in <backupDir> because it is not identical byte by byte
unl.UP.b  unlink file in <backupDir> + UPDATE.b (can be switched off via the
          "--noUnlink" option, see below)

(internal use, for completion only)
-----------------------------------
OK        object without needed action in <sourceDir> (either files or
          directories already synchronized with <backupDir>, or other objects
          not to be synchronized to <backupDir>). These records are necessary
          for preparation of shellscripts for the case of restore.
OK.b      file proven identical byte by byte (in CSV metadata file 555)
KEEP      object to be kept only in <backupDir>
uRMDIR    unavoidable RMDIR which goes into Exec1 (in CSV files 380 and 390)
uREMOVE   unavoidable REMOVE which goes into Exec1 (in CSV files 380 and 390)

###########################################################

INDIVIDUAL STEPS IN FULL DETAIL

Exec1:
------
Unavoidable removals from <backupDir> (objects of conflicting types which occupy
needed namespace). This must be the first step, because objects of conflicting
types in <backupDir> would prevent synchronization (e.g. a file cannot overwrite
a directory).

Unavoidable removals are prepared regardless of the "--noRemove" option.

Exec2:
------
Files and directories which exist only in <sourceDir> are copied to <backupDir>
(action codes NEW and MKDIR).

Zaloha "updates" files in <backupDir> (action code UPDATE) if files exist under
same paths in both <sourceDir> and <backupDir> and the comparisons of file sizes
and modification times result in needed synchronization of the files. If the
files in <backupDir> are multiply linked (hardlinked), Zaloha removes (unlinks)
them first (action code unl.UP), to prevent "updating" multiply linked files,
which could lead to follow-up effects. This unlinking can be switched off via
the "--noUnlink" option.

If the files differ only in attributes (u=user ownership, g=group ownership,
m=mode), and attribute synchronization is switched on via the "--pUser",
"--pGroup" and "--pMode" options, then only these attributes will be
synchronized (action code ATTR). However, this is an optional feature, because:
(1) the filesystem of <backupDir> might not be capable of storing these
attributes, or (2) it may be wanted that all files and directories in
<backupDir> are owned by the user who runs Zaloha.

Regardless of whether these attributes are synchronized or not, an eventual
restore of <sourceDir> from <backupDir> including these attributes is possible
thanks to the restore scripts which Zaloha prepares in its metadata directory
(see below).

Zaloha contains an optional feature to detect multiply linked (hardlinked) files
in <sourceDir>. If this feature is switched on (via the "--hLinks" option),
Zaloha internally flags the second, third, etc. links to same file as
"hardlinks", and synchronizes to <backupDir> only the first link (the "file").
The "hardlinks" are not synchronized to <backupDir>, but Zaloha prepares a
restore script in its metadata directory. If this feature is switched off
(no "--hLinks" option), then each link to a multiply linked file is treated as
a separate regular file.

The detection of hardlinks brings two risks: Zaloha might not detect that a file
is in fact a hardlink, or Zaloha might falsely detect a hardlink while the file
is in fact a unique file. The second risk is more severe, because the contents
of the unique file will not be synchronized to <backupDir> in such case.
For that reason, Zaloha contains additional checks against falsely detected
hardlinks (see code of AWKHLINKS). Generally, use this feature only after proper
testing on your filesystems. Be cautious as inode-related issues exist on some
filesystems and network-mounted filesystems.

Symbolic links in <sourceDir>: In the absence of the "--followSLinksS" option,
they are neither followed nor synchronized to <backupDir>, and Zaloha prepares
a restore script in its metadata directory. If the "--followSLinksS" option is
given, symbolic links on <sourceDir> are followed and the referenced files and
directories are synchronized to <backupDir>. See section Following Symbolic
Links for details.

Zaloha does not synchronize other types of objects in <sourceDir> (named pipes,
sockets, special devices, etc). These objects are considered to be part of the
operating system or parts of applications, and dedicated scripts for their
(re-)creation should exist.

It was a conscious decision to synchronize to <backupDir> only files and
directories and keep other objects in metadata only. This gives more freedom
in the choice of filesystem type for <backupDir>, because every filesystem type
is able to store files and directories, but not necessarily the other objects.

Exec3:
------
This step is optional and can be activated via the "--revNew" and "--revUp"
options.

Why is this feature useful? Imagine you use a Windows notebook while working in
the field.  At home, you have got a Linux server to that you regularly
synchronize your data. However, sometimes you work directly on the Linux server.
That work should be "reverse-synchronized" from the Linux server (<backupDir>)
back to the Windows notebook (<sourceDir>) (of course, assumed that there is no
conflict between the work on the notebook and the work on the server).

REV.NEW: If standalone files in <backupDir> are newer than the last run of
Zaloha, and the "--revNew" option is given, then Zaloha reverse-copies that
files to <sourceDir> (action code REV.NEW) including all necessary parent
directories (action code REV.MKDI).

REV.UP: If files exist under same paths in both <sourceDir> and <backupDir>,
and the files in <backupDir> are newer, and the "--revUp" option is given,
then Zaloha uses that files to reverse-update the older files in <sourceDir>
(action code REV.UP).

Optionally, to preserve attributes during the REV.MKDI, REV.NEW and REV.UP
operations: use options "--pRevUser", "--pRevGroup" and "--pRevMode".

If reverse-synchronization is not active: If no "--revNew" option is given,
then each standalone file in <backupDir> is considered obsolete (and removed,
unless the "--noRemove" option is given). If no "--revUp" option is given, then
files in <sourceDir> always update files in <backupDir> if they differ.

Reverse-synchronization to <sourceDir> increases the overall complexity of the
solution. Use it only in the interactive regime of Zaloha, where human oversight
and confirmation of the prepared actions are in place.
Do not use it in automatic operations.

Exec4:
------
Zaloha removes all remaining obsolete files and directories from <backupDir>.
This function can be switched off via the "--noRemove" option.

Why are removals from <backupDir> split into two steps (Exec1 and Exec4)?
The unavoidable removals must unconditionally occur first, also in Exec1 step.
But what about the remaining (avoidable) removals: Imagine a scenario when a
directory is renamed in <sourceDir>: If all removals were executed in Exec1,
then <backupDir> would transition through a state (namely between Exec1 and
Exec2) when the backup copy of the directory is already removed (under the old
name), but not yet created (under the new name). To minimize the chance for such
transient states to occur, the avoidable removals are postponed to Exec4.

Advise to this topic: In case of bigger reorganizations of <sourceDir>, also
e.g. in case when a directory with large content is renamed, it is much better
to prepare a rename script (more generally speaking: a migration script) and
apply it to both <sourceDir> and <backupDir>, instead of letting Zaloha perform
massive copying followed by massive removing.

Exec5:
------
Zaloha updates files in <backupDir> for which the optional "byte by byte"
comparing revealed that they are in fact not identical (despite appearing
identical by looking at their file sizes and modification times).

The action codes are UPDATE.b and unl.UP.b (the latter is update with prior
unlinking of multiply linked target file, as described under Exec2).

Please note that these actions might indicate deeper problems like storage
corruption (or even a cyber security issue), and should be actually perceived
as surprises.

This step is optional and can be activated via the "--byteByByte" option.

Metadata directory of Zaloha
----------------------------
Zaloha creates a metadata directory: <backupDir>/.Zaloha_metadata. The location
of the metadata directory can be changed via the "--metaDir" option.

The purposes of the individual files are described as comments in program code.
Briefly, they are:

 * AWK program files (produced from "here documents" in Zaloha)
 * Shellscripts to run FIND commands
 * CSV metadata files
 * Exec1/2/3/4/5 shellscripts
 * Shellscripts for the case of restore
 * Touchfile 999 marking execution of actions

Files persist in the metadata directory until the next invocation of Zaloha.

To obtain information about what Zaloha did (counts of removed/copied files,
total counts, etc), do not parse the screen output: Query the CSV metadata files
instead. Query the CSV metadata files after AWKCLEANER. Do not query the raw
CSV outputs of the FIND commands (before AWKCLEANER) and the produced
shellscripts, because due to eventual newlines in filenames, they may contain
multiple lines per "record".

In some situations, the existence of Zaloha metadata directory is unwanted after
Zaloha finishes. In such cases, put a command to remove it to the wrapper script
that invokes Zaloha. At the same time, use the option "--noLastRun" to prevent
Zaloha from running FIND on file 999 in Zaloha metadata directory to obtain the
time of the last run of Zaloha. Please note that by not keeping the Zaloha
metadata directory, you sacrifice some functionality (see "--noLastRun" option
below), and you loose the CSV metadata for an eventual analysis of problems and
you loose the shellscripts for case of restore.

Shellscripts for case of restore
--------------------------------
Zaloha prepares shellscripts for the case of restore in its metadata directory
(scripts 800 through 860). Each type of operation is contained in a separate
shellscript, to give maximum freedom (= for each script, decide whether to apply
or to not apply). Further, each shellscript has a header part where
key variables for whole script are defined (and can be adjusted as needed).

###########################################################

INVOCATION

Zaloha.sh --sourceDir=<sourceDir> --backupDir=<backupDir> [ other options ... ]

--sourceDir=<sourceDir> is mandatory. <sourceDir> must exist, otherwise Zaloha
    throws an error (except when the "--noDirChecks" option is given).

--backupDir=<backupDir> is mandatory. <backupDir> must exist, otherwise Zaloha
    throws an error (except when the "--noDirChecks" option is given).

--findSourceOps=<findSourceOps> are additional operands for the FIND command
    that scans <sourceDir>, to be used to exclude files or subdirectories in
    <sourceDir> from synchronization to <backupDir>. This is a complex topic,
    described in full detail in section FIND operands to control FIND commands
    invoked by Zaloha.

    The "--findSourceOps" option can be passed in several times. In such case
    the final <findSourceOps> will be the concatenation of the several
    individual <findSourceOps> passed in with the options.

--findGeneralOps=<findGeneralOps> are additional operands for the FIND commands
    that scan both <sourceDir> and <backupDir>, to be used to exclude "Trash"
    subdirectories, independently on where they exist, from Zaloha's scope.
    This is a complex topic, described in full detail in section FIND operands
    to control FIND commands invoked by Zaloha.

    The "--findGeneralOps" option can be passed in several times. In such case
    the final <findGeneralOps> will be the concatenation of the several
    individual <findGeneralOps> passed in with the options.

--noExec        ... needed if Zaloha is invoked automatically: do not ask,
    do not execute the actions, but still prepare the scripts. The prepared
    scripts then will not contain shell tracing and the "set -e" instruction.
    This means that the scripts will ignore individual failed commands and try
    to do as much work as possible, which is a behavior different from the
    interactive regime, where scripts are traced and halt on the first error.

--noRemove      ... do not remove files, directories and symbolic links that
    are standalone in <backupDir>. This option is useful when <backupDir> should
    hold "current" plus "historical" data whereas <sourceDir> holds only
    "current" data.

    Please keep in mind that if objects of conflicting types in <backupDir>
    prevent synchronization (e.g. a file cannot overwrite a directory),
    removals are unavoidable and will be prepared regardless of this option.
    In such case Zaloha displays a warning message in the interactive regime.
    In automatic operations, the calling process should query the CSV metadata
    file 510 to detect this case.

--revNew        ... enable REV.NEW (= if standalone file in <backupDir> is
                    newer than the last run of Zaloha, reverse-copy it
                    to <sourceDir>)

--revUp         ... enable REV.UP (= if file in <backupDir> is newer than
                    file in <sourceDir>, reverse-update the file in <sourceDir>)

--hLinks        ... perform hardlink detection (inode-deduplication)
                    on <sourceDir>

--ok2s          ... tolerate +/- 2 seconds differences due to FAT rounding of
                    modification times to nearest 2 seconds (explained in
                    Special Cases section below). This option is necessary only
                    if Zaloha is unable to determine the FAT file system from
                    the FIND output (column 6).

--ok3600s       ... additional tolerable offset of modification time differences
                    of exactly +/- 3600 seconds (explained in Special Cases
                    section below)

--byteByByte    ... compare "byte by byte" files that appear identical (more
                    precisely, files for which no action (OK) or just update of
                    attributes (ATTR) has been prepared).
                    (Explained in the Advanced Use of Zaloha section below).
                    This comparison might dramatically slow down Zaloha.
                    If additional updates of files result from this comparison,
                    they will be executed in step Exec5.

--noUnlink      ... never unlink multiply linked files in <backupDir> before
                    writing to them

--touch         ... use cp + touch instead of cp --preserve=timestamps
                    (explained in Special Cases section below)

--pUser         ... synchronize user ownerships in <backupDir>
                    based on <sourceDir>

--pGroup        ... synchronize group ownerships in <backupDir>
                    based on <sourceDir>

--pMode         ... synchronize modes (permission bits) in <backupDir>
                    based on <sourceDir>

--pRevUser      ... preserve user ownerships during REV operations

--pRevGroup     ... preserve group ownerships during REV operations

--pRevMode      ... preserve modes (permission bits) during REV operations

--followSLinksS ... follow symbolic links on <sourceDir>
--followSLinksB ... follow symbolic links on <backupDir>
                    Please see section Following Symbolic Links for details.

--noWarnSLinks  ... suppress warnings related to symbolic links

--noRestore     ... do not prepare scripts for the case of restore (= saves
    processing time and disk space, see optimization note below). The scripts
    for the case of restore can still be produced ex-post by manually running
    the respective AWK program (700 file) on the source CSV file (505 file).

--optimCSV      ... optimize space occupied by CSV metadata files by removing
    intermediary CSV files after use (see optimization note below).
    If intermediary CSV metadata files are removed, an ex-post analysis of
    eventual problems may be impossible.

--metaDir=<metaDir> allows to place the Zaloha metadata directory to a different
    location than the default (which is <backupDir>/.Zaloha_metadata).
    The reasons might be:
      a) non-writable <backupDir> (if Zaloha is used to perform comparison only
        (i.e. with "--noExec" option))
      b) a requirement to have Zaloha metadata on a separate storage
      c) advanced use of Zaloha, see Advanced Use of Zaloha section below
    It is possible (but not recommended) to place <metaDir> to a different
    location inside of <backupDir>, or inside of <sourceDir>. In such cases,
    FIND expressions to exclude the metadata directory from the FIND scans
    must be explicitly passed in via <findGeneralOps>.
    If Zaloha is used to synchronize multiple directories, then each such
    instance of Zaloha must have its own separate metadata directory.

--noDirChecks   ... switch off the checks for existence of <sourceDir> and
    <backupDir>. (Explained in the Advanced Use of Zaloha section below).

--noLastRun     ... do not obtain time of the last run of Zaloha by running
                    FIND on file 999 in Zaloha metadata directory.
                    This makes Zaloha state-less, which might be a desired
                    property in certain situations, e.g. if you do not want to
                    keep the Zaloha metadata directory. However, this sacrifices
                    features based on the last run of Zaloha: REV.NEW and
                    distinction of operations on files newer than the last run
                    of Zaloha (e.g. distinction between UPDATE.! and UPDATE).

--noIdentCheck  ... do not check if objects on identical paths in <sourceDir>
                    and <backupDir> are identical (= identical inodes). This
                    check brings to attention cases where objects in <sourceDir>
                    and corresponding objects in <backupDir> are in reality
                    the same objects (possibly via hardlinks), which violates
                    the logic of backup. Switching off this check might be
                    necessary in some special uses of Zaloha.

--noFindSource  ... do not run FIND (script 210) to scan <sourceDir>
                    and use externally supplied CSV metadata file 310 instead
--noFindBackup  ... do not run FIND (script 220) to scan <backupDir>
                    and use externally supplied CSV metadata file 320 instead
   (Explained in the Advanced Use of Zaloha section below).

--noExec1Hdr    ... do not write header to the shellscript for Exec1 (file 610)
--noExec2Hdr    ... do not write header to the shellscript for Exec2 (file 620)
--noExec3Hdr    ... do not write header to the shellscript for Exec3 (file 630)
--noExec4Hdr    ... do not write header to the shellscript for Exec4 (file 640)
--noExec5Hdr    ... do not write header to the shellscript for Exec5 (file 650)
   These options can be used only together with the "--noExec" option.
   (Explained in the Advanced Use of Zaloha section below).

--noR800Hdr     ... do not write header to the restore script 800
--noR810Hdr     ... do not write header to the restore script 810
--noR820Hdr     ... do not write header to the restore script 820
--noR830Hdr     ... do not write header to the restore script 830
--noR840Hdr     ... do not write header to the restore script 840
--noR850Hdr     ... do not write header to the restore script 850
--noR860Hdr     ... do not write header to the restore script 860
   (Explained in the Advanced Use of Zaloha section below).

--noProgress    ... suppress progress messages (less screen output). If both
                    options "--noExec" and "--noProgress" are used, Zaloha does
                    not produce any output on stdout (traditional behavior of
                    Unics tools).

--color         ... use color highlighting (can be used on terminals which
                    support ANSI escape codes)

--mawk          ... use mawk, the very fast AWK implementation based on a
                    bytecode interpreter. Without this option, awk is used,
                    which usually maps to GNU awk (but not always).
                    (Note: If you know that awk on your system maps to mawk,
                     use this option to make the mawk usage explicit, as this
                     option also turns off mawk's i/o buffering on places where
                     progress of commands is displayed, i.e. on places where
                     i/o buffering causes confusion and is unwanted).

--lTest         ... (do not use in real operations) support for lint-testing
                    of AWK programs

--help          ... show Zaloha documentation (using the LESS program) and exit

Optimization note: If Zaloha operates on directories with huge numbers of files,
especially small ones, then the size of metadata plus the size of scripts for
the case of restore may exceed the size of the files themselves. If this leads
to problems, use options "--noRestore" and "--optimCSV".

Zaloha must be run by a user with sufficient privileges to read <sourceDir> and
to write and perform other required actions on <backupDir>. In case of the REV
actions, privileges to write and perform other required actions on <sourceDir>
are required as well. Zaloha does not contain any internal checks as to whether
privileges are sufficient. Failures of commands run by Zaloha must be monitored
instead.

Zaloha does not contain protection against concurrent invocations with
conflicting <backupDir> (and for REV also conflicting <sourceDir>): this is
responsibility of the invoker, especially due to the fact that Zaloha may
conflict with other processes as well.

In case of failure: resolve the problem and re-run Zaloha with same parameters.
In the second run, Zaloha should not repeat the actions completed by the first
run: it should continue from the action on which the first run failed. If the
first run completed successfully, no actions should be performed in the second
run (this is an important test case, see below).

Typically, Zaloha is invoked from a wrapper script that does the necessary
directory mounts, then runs Zaloha with the required parameters, then directory
unmounts.

###########################################################

FIND OPERANDS TO CONTROL FIND COMMANDS INVOKED BY ZALOHA

Zaloha obtains information about the files and directories via the FIND command.

Ad FIND command itself: It must support the -printf operand, as this allows to
obtain all needed information from a directory in one scan (= one process),
which is efficient. GNU find supports the -printf operand, but some older
FIND implementations don't, so they cannot be used with Zaloha.

The FIND scans of <sourceDir> and <backupDir> can be controlled by two options:
Option "--findSourceOps" are additional operands for the FIND command that scans
<sourceDir> only, and the option "--findGeneralOps" are additional operands
for both FIND commands (scans of both <sourceDir> and <backupDir>).

Both options "--findSourceOps" and "--findGeneralOps" can be passed in several
times. This allows to construct the final <findSourceOps> and <findGeneralOps>
in Zaloha part-wise, e.g. expression by expression.

Difference between <findSourceOps> and <findGeneralOps>
-------------------------------------------------------
<findSourceOps> applies only to <sourceDir>. If files in <sourceDir> are
excluded by <findSourceOps> and files exist in <backupDir> under same paths,
then Zaloha evaluates the files in <backupDir> as obsolete (= removes them,
unless the "--noRemove" option is given, or eventually even attempts to
reverse-synchronize them (which leads to one of the corner cases
(see the Corner Cases section)).

On the contrary, the files excluded by <findGeneralOps> are not visible to
Zaloha at all, neither in <sourceDir> nor in <backupDir>, so Zaloha will not
act on them.

The main use of <findSourceOps> is to exclude files or subdirectories in
<sourceDir> from synchronization to <backupDir>.

The main use of <findGeneralOps> is to exclude "Trash" subdirectories,
independently on where they exist, from Zaloha's scope.

Rules and limitations
---------------------
Both <findSourceOps> and <findGeneralOps> must consist of one or more
FIND expressions in the form of an OR-connected chain:

    expressionA -o expressionB -o ... expressionN -o

Adherence to this convention assures that Zaloha is able to correctly combine
<findSourceOps> with <findGeneralOps> and with own FIND expressions.

The OR-connected chain works so that if an earlier expression in the chain
evaluates TRUE, FIND does not evaluate following expressions, i.e. will not
evaluate the final -printf operand, so no output will be produced. In other
words, matching by any of the expressions leads to exclusion.

Further, the internal logic of Zaloha imposes the following limitations:

 * Exclusion of files by the "--findSourceOps" option: No limitations exist
   here, all expressions supported by FIND can be used (but make sure the
   exclusion applies only to files). Example: exclude all files smaller than
   1000 bytes:

    --findSourceOps='( -type f -a -size -1000c ) -o'

 * Exclusion of subdirectories by the "--findSourceOps" option: One limitation
   must be obeyed: If a subdirectory is excluded, all its contents must be
   excluded too. Why? If Zaloha sees the contents but not the subdirectory
   itself, it will prepare commands to create the contents of the subdirectory,
   but they will fail as the command to create the subdirectory itself (mkdir)
   will not be prepared. Example: exclude all subdirectories owned by user fred
   including all their contents:

    --findSourceOps='( -type d -a -user fred ) -prune -o'

   The -prune operand instructs FIND to not descend into directories matched
   by the preceding expression.

 * Exclusion of files by the "--findGeneralOps" option: As <findGeneralOps>
   applies to both <sourceDir> and <backupDir>, and the objects in both
   directories are "matched" by file paths, only expressions with -path or
   -name operands make sense. Why? If objects exist under same paths in both
   directories, Zaloha should either see both of them or none of them.
   Both -path and -name expressions assure this, but not necessarily the
   expressions based on other operands like -size, -user and so on.
   Example: exclude core dumps (files named core) wherever they exist:

    --findGeneralOps='( -type f -a -name core ) -o'

   Note 1: GNU find supports the -ipath and -iname operands for case-insensitive
   matching of paths and names. They fulfill the above described "both or none"
   criterion as well and hence are allowed too. The same holds for the -regex
   and -iregex operands supported by GNU find, as they act on paths as well.

   Note 2: As <findGeneralOps> act on both <sourceDir> and <backupDir> and the
   paths differ in the start point directories, the placeholder ///d/ must be
   used in the involved path patterns. This is described further below.

 * Exclusion of subdirectories by the "--findGeneralOps" option: Both above
   described limitations must be obeyed: Only expressions with -path or -name
   operands are allowed, and if subdirectories are excluded, all their contents
   must be excluded too. Notes 1 and 2 from previous bullet hold too.
   Example: exclude subdirectories lost+found wherever they exist:

    --findGeneralOps='( -type d -a -name lost+found ) -prune -o'

   If you do not care if an object is a file or a directory, you can abbreviate:

    --findGeneralOps='-name unwanted_name -prune -o'
    --findGeneralOps='-path unwanted_path -prune -o'

*** CAUTION <findSourceOps> AND <findGeneralOps>: Zaloha does not validate if
the described rules and limitations are indeed obeyed. Wrong <findSourceOps>
and/or <findGeneralOps> can break Zaloha. On the other hand, an eventual
advanced use by knowledgeable users is not prevented.

Troubleshooting
---------------
If FIND operands do not work as expected, debug them using FIND alone.
Let's assume, that this does not work as expected:

    --findSourceOps='( -type f -a -name *.tmp ) -o'

The find command to debug this is:

    find <sourceDir> '(' -type f -a -name '*.tmp' ')' -o -printf 'path: %P\n'

Beware of interpretation by your shell
--------------------------------------
Your shell might interpret certain special characters contained on the command
line. Should these characters be passed to the called program (= Zaloha)
uninterpreted, they must be quoted or escaped.

The bash shell does not interpret any characters in strings quoted by single
quotes. In strings quoted by double-quotes, the situation is more complex.

Please see the respective shell documentation for more details.

Parsing of FIND operands by Zaloha
----------------------------------
<findSourceOps> and <findGeneralOps> are passed into Zaloha as single strings.
Zaloha has to split these strings into individual operands (words) and pass them
to FIND, each operand as a separate command line argument. Zaloha has a special
parser (AWKPARSER) to do this.

The trivial case is when each (space-delimited) word is a separate FIND operand.
However, if a FIND operand contains spaces, it must be enclosed in double-quotes
(") to be treated as one operand. Moreover, if a FIND operand contains
double-quotes themselves, then it too must be enclosed in double-quotes (")
and the original double-quotes must be escaped by second double-quotes ("").

Examples (for bash for both single-quoted and double-quoted strings):

  * exclude all objects named Windows Security
  * exclude all objects named My "Secret" Things

    --findSourceOps='-name "Windows Security" -prune -o'
    --findSourceOps='-name "My ""Secret"" Things" -prune -o'

    --findSourceOps="-name \"Windows Security\" -prune -o"
    --findSourceOps="-name \"My \"\"Secret\"\" Things\" -prune -o"

Interpretation of special characters by FIND itself
---------------------------------------------------
In the patterns of the -path and -name expressions, FIND itself interprets
following characters specially (see FIND documentation): *, ?, [, ], \.

If these characters are to be taken literally, they must be handed over to
FIND backslash-escaped.

Examples (for bash for both single-quoted and double-quoted strings):

  * exclude all objects whose names begin with abcd (i.e. FIND pattern abcd*)
  * exclude all objects named exactly mnop* (literally including the asterisk)

    --findSourceOps='-name abcd* -prune -o'
    --findSourceOps='-name mnop\* -prune -o'

    --findSourceOps="-name abcd* -prune -o"
    --findSourceOps="-name mnop\\* -prune -o"

The placeholder ///d/ for the start point directories
-----------------------------------------------------
If expressions with the "-path" operand are used in <findSourceOps>, the
placeholder ///d/ should be used in place of <sourceDir>/ in their path
patterns.

If expressions with the "-path" operand are used in <findGeneralOps>, the
placeholder ///d/ must (not should) be used in place of <sourceDir>/ and
<backupDir>/ in their path patterns, unless, perhaps, the <sourceDir> and
<backupDir> parts of the paths are matched by a FIND wildcard.

Zaloha will replace ///d/ by the start point directory that is passed to FIND
in the given scan, with eventual FIND pattern special characters properly
escaped (which relieves you from doing the same by yourself).

Example: exclude <sourceDir>/.git

    --findSourceOps="-path ///d/.git -prune -o"

Internally defined default for <findGeneralOps>
-----------------------------------------------
<findGeneralOps> has an internally defined default, used to exclude:

    <sourceDir or backupDir>/$RECYCLE.BIN
      ... Windows Recycle Bin (assumed to exist directly under <sourceDir> or
          <backupDir>)

    <sourceDir or backupDir>/.Trash_<number>*
      ... Linux Trash (assumed to exist directly under <sourceDir> or
          <backupDir>)

    <sourceDir or backupDir>/lost+found
      ... Linux lost + found filesystem fragments (assumed to exist directly
          under <sourceDir> or <backupDir>)

To replace this internal default with own <findGeneralOps>:

    --findGeneralOps=<your replacement>

To switch off this internal default:

    --findGeneralOps=

To extend (= combine, not replace) the internal default by own extension (note
the plus (+) sign):

    --findGeneralOps=+<your extension>

If several "--findGeneralOps" options are passed in, the plus (+) sign mentioned
above should be passed in only with the first instance, not with the second,
third (and so on) instances.

Known traps and problems
------------------------
Beware of matching the start point directories <sourceDir> or <backupDir> 
themselves by the expressions and patterns.

In some FIND versions, the name patterns starting with the asterisk (*)
wildcard do not match objects whose names start with a dot (.).

###########################################################

FOLLOWING SYMBOLIC LINKS

Technically, the "--followSLinksS" and/or "--followSLinksB" options in Zaloha
"just" pass the -L option to the FIND commands that scan <sourceDir> and/or
<backupDir>. However, it takes a fair amount of text to describe the impacts:

If FIND is invoked with the -L option, it returns information about the objects
the symbolic links point to rather than the symbolic links themselves (unless
the symbolic links are broken). Moreover, if the symbolic links point to
directories, the FIND scans continue in that directories as if they were
subdirectories (= symbolic links are followed).

In other words: If the directory structure of <sourceDir> is spanned by symbolic
links and symbolic links are followed due to the "--followSLinksS" option,
the FIND output will contain the whole structure spanned by the symbolic links,
BUT will not give any clue that FIND was going over the symbolic links.

The same sentence holds for <backupDir> and the "--followSLinksB" option.

Corollary 1: Independently on whether <sourceDir> is a plain directory structure
or spanned by symbolic links, Zaloha will create a plain directory structure
in <backupDir>. If the structure of <backupDir> should by spanned by symbolic
links too (not necessarily identically to <sourceDir>), then the symbolic links
and the referenced objects must be prepared in advance and the "--followSLinksB"
option must be given to follow symbolic links on <backupDir> (otherwise Zaloha
would remove the prepared symbolic links on <backupDir> and create real files
and directories in place of them).

Corollary 2: The restore scripts are not aware of the symbolic links that
spanned the original structure. They will restore a plain directory structure.
Again, if the structure of the restored directory should be spanned by symbolic
links, then the symbolic links and the referenced objects must be prepared
in advance. Please note that if the option "--followSLinksS" is given, the file
820_restore_sym_links.sh will contain only the broken symbolic links (as these
were the only symbolic links reported by FIND as symbolic links in that case).

The abovesaid is not much surprising given that symbolic links are frequently
used to place parts of directory structures to different storage media:
The different storage media must be mounted, directories on them must be
prepared and referenced by the symbolic links before any backup (or restore)
operations can begin.

Corner case synchronization of attributes (user ownerships, group ownerships,
modes (permission bits)) if symbolic links are followed: the attributes are
synchronized on the objects the symbolic links point to, not on the symbolic
links themselves.

Corner case removal operations: Eventual removal operations on places where the
structure is held together by symbolic links are problematic. Zaloha will
prepare the REMOVE (rm -f) or RMDIR (rmdir) operations due to the objects having
been reported to it as files or directories. However, if the objects are in
reality symbolic links, "rm -f" removes the symbolic links themselves, not the
referenced objects, and "rmdir" fails altogether.

Corner case loops: Loops can occur if symbolic links are in play. Zaloha can
only rely on the FIND commands to handle them (and prevent running forever).
GNU find, for example, contains an internal mechanism to detect loops.

Technical note for the case when the start point directories themselves are
symbolic links: Zaloha passes all start point directories to FIND with trailing
slashes, which instructs FIND to follow them if they are symbolic links.

###########################################################

TESTING, DEPLOYMENT, INTEGRATION

First, test Zaloha on a small and noncritical set of your data. Although Zaloha
has been tested on several environments, it can happen that Zaloha malfunctions
on your environment due to different behavior of the operating system, bash,
FIND, SORT, AWK and other utilities. Perform tests in the interactive regime
first. If Zaloha prepares wrong actions, abort it at the next prompt.

After first synchronization, an important test is to run second synchronization,
which should execute no actions, as the directories should be already
synchronized.

Test Zaloha under all scenarios which can occur on your environment. Test Zaloha
with filenames containing "weird" or national characters.

Verify that all your programs that write to <sourceDir> change modification
times of the files written, so that Zaloha does not miss changed files.

Simulate the loss of <sourceDir> and perform test of the recovery scenario using
the recovery scripts prepared by Zaloha.

Automatic operations
--------------------
Additional care must be taken when using Zaloha in automatic operations
("--noExec" option):

Exit status and standard error of Zaloha and of the scripts prepared by Zaloha
must be monitored by a monitoring system used within your IT landscape.
Nonzero exit status and writes to standard error must be brought to attention
and investigated. If Zaloha itself fails, the process must be aborted.
The scripts prepared under the "--noExec" option do not halt on the first error,
also their zero exit status does not imply that there were no failed
individual commands.

Implement sanity checks to avoid data disasters like synchronizing <sourceDir>
to <backupDir> in the moment when <sourceDir> is unmounted, which would lead
to loss of backup data. Evaluate counts of actions prepared by Zaloha (count
records in CSV metadata files in Zaloha metadata directory). Abort the process
if the action counts exceed sanity thresholds defined by you, e.g. when Zaloha
prepares an unexpectedly high number of removals.

The process which invokes Zaloha in automatic regime should function as follows
(pseudocode):

  run Zaloha.sh --noExec
  in case of failure: abort process
  perform sanity checks on prepared actions
  if ( sanity checks OK ) then
    execute script 610_exec1.sh
    execute script 620_exec2.sh
    execute script 630_exec3.sh
    execute script 640_exec4.sh
    execute script 650_exec5.sh
    monitor execution (writing to stderr)
    if ( execution successful ) then
      execute script 690_touch.sh
    end if
  end if

###########################################################

SPECIAL AND CORNER CASES

To detect which files need synchronization, Zaloha compares file sizes and
modification times. If the file sizes differ, synchronization is needed.
The modification times are more complex:

 * If one of the filesystems is FAT (i.e. FAT16, VFAT, FAT32), Zaloha tolerates
   differences of +/- 2 seconds. This is necessary because FAT rounds the
   modification times to nearest 2 seconds, while no such rounding occurs on
   other filesystems. (Note: Why is a +/- 1 second tolerance not sufficient:
   In some situations, a "ceiling" to nearest 2 seconds was observed instead of
   "rounding", making a +/- 2 seconds tolerance necessary).

 * If Zaloha is unable to determine the FAT file system from the FIND output
   (column 6), it is possible to enforce the +/- 2 seconds tolerance via the
   "--ok2s" option.

 * In some situations, offsets of exactly +/- 1 hour (+/- 3600 seconds)
   must be tolerated as well. Typically, this is necessary when one of the
   directories is on a filesystem type that stores modification times
   in local time instead of in universal time (e.g. FAT), and the OS is not
   able, for some reason, to correctly adjust for daylight saving time while
   converting the local time.

 * The additional tolerable offsets of +/- 3600 seconds can be activated via the
   "--ok3600s" option. They are assumed to exist between files in <sourceDir>
   and files in <backupDir>, but not between files in <backupDir> and the
   999 file in <metaDir> (from which the time of the last run of Zaloha is
   obtained). This last note is relevant especially if <metaDir> is located
   outside of <backupDir> (which is achievable via the "--metaDir" option).

In some situations (e.g. Linux Samba + Linux Samba client),
cp --preserve=timestamps does not preserve modification timestamps (unless on
empty files). In that case, Zaloha should be instructed (via the "--touch"
option) to use subsequent touch commands instead, which is a more robust
solution. In the scripts for case of restore, touch commands are used
unconditionally.

Corner case REV.NEW with namespace on <sourceDir> needed for REV.MKDI or REV.NEW
actions is occupied by objects of conflicting types: The files in <backupDir>
will not be reverse-copied to <sourceDir>, but removed. As these files must be
newer than the last run of Zaloha, the actions will be REMOVE.!.

Corner case REV.NEW with "--findSourceOps": If files exist under same paths in
both <sourceDir> and <backupDir>, and in <sourceDir> the files is masked by
<findSourceOps> and in <backupDir> the corresponding files are newer than the
last run of Zaloha, the REV.NEW actions prepared by Zaloha are wrong. This is
an error which Zaloha is unable to detect. Hence, the shellscript for Exec3
contains a test that throws an error in such situations.

Corner case REV.UP with "--ok3600s": The "--ok3600s" option makes it harder
to determine which file is newer (decision UPDATE vs REV.UP). The implemented
solution for that case is that for REV.UP, the <backupDir> file must be newer
by more than 3600 seconds (plus an eventual 2 secs FAT tolerance).

Corner case "--hLinks" with new link(s) to same file added or removed: The
assignment of what link will be kept as "file" (f) and what links will be tagged
as "hardlinks" (h) in CSV metadata after AWKHLINKS may change, leading to
NEW and REMOVE actions.

Corner case REV.UP with "--hLinks": Zaloha supports reverse-update of only the
first links in <sourceDir> (the ones that stay tagged as "files" (f) in
CSV metadata after AWKHLINKS).

Corner case UPDATE or REV.UP with hardlinked file: Updating a multiply linked
(hardlinked) file means that the new contents will appear under all other links,
and that may lead to follow-up effects.

Corner case update of attributes with hardlinked file: Updated attributes on a
multiply linked (hardlinked) file will (with exceptions on some filesystem
types) appear under all other links, and that may lead to follow-up effects.

Corner case "--hLinks" with objects in <backupDir> under same paths as the
seconds, third etc. hardlinks in <sourceDir> (the ones that will be tagged as
"hardlinks" (h) in CSV metadata after AWKHLINKS): The objects in <backupDir>
will be (unavoidably) removed to avoid misleading situations in that for a
hardlinked file in <sourceDir>, <backupDir> would contain a different object
(or eventually even a different file) under same path.

Corner case objects in <backupDir> under same paths as symbolic links in
<sourceDir>: The objects in <backupDir> will be (unavoidably) removed to avoid
misleading situations in that for a symbolic link in <sourceDir> that points
to an object, <backupDir> would contain a different object under same path.
The only exception is when the objects in <backupDir> are symbolic links too,
in which case they will be kept (but not changed). Please see section
Following Symbolic Links on when symbolic links are not reported as
symbolic links by FIND.

Corner case objects in <backupDir> under same paths as other objects (p/s/c/b/D)
in <sourceDir>: The objects in <backupDir> will be (unavoidably) removed except
when they are other objects (p/s/c/b/D) too, in which case they will be kept
(but not changed).

Corner case if directory .Zaloha_metadata exists under <sourceDir> as well
(e.g. in case of backups of backups): It will be ignored. If a backup of that
directory is needed as well, it should be solved separately (Hint: if the
secondary backup starts one directory higher, then .Zaloha_metadata of the
original backup will be taken).

Corner case FAT uppercase conversions: The widespread FAT filesystem has been
already mentioned as a source of challenges. Here is another one: The source
directory is on a Linux ext4 filesystem and contains the files SOUBOR.TXT,
SOUBOR.txt, soubor.TXT and soubor.txt in one of the subdirectories. The backup
directory is on a FAT-formatted USB flash drive. The synchronization executes
without visible problems, but in the backup directory, only SOUBOR.TXT exists.
What happened is that the OS/filesystem re-directed all four copy operations
into SOUBOR.TXT. Also, after three overwrites, the backup of only one of the
four source files exists. Zaloha detects this situation on next synchronization
and prepares new copy commands, but they again hit the same problem. The only
effective solution seems to be the renaming of the source files to avoid this
type of name conflict. Last note: A similar phenomenon has been observed in the
Cygwin environment running on Windows/ntfs too.

Corner case if same directory is passed in as <sourceDir> and <backupDir>:
Zaloha will issue a warning about identical objects. No actions will be prepared
due to both directories being identical, except when the directory contains
multiply-linked (hardlinked) files and the "--hLinks" option is given. In that
case, Zaloha will prepare removals of the second, third, etc. links to same
files. This interesting side-effect (or new use case) is explained as follows:
Zaloha will perform hardlink detection on <sourceDir> and for the detected
hardlinks (h) it prepares removals of the corresponding files in <backupDir>,
which is the same directory. The hardlinks can be restored by restore script
830_restore_hardlinks.sh.

It is possible (but not recommended) for <backupDir> to be a subdirectory of
<sourceDir> and vice versa. In such cases, FIND expressions to avoid recursive
copying must be passed in via <findGeneralOps>.

###########################################################

HOW ZALOHA WORKS INTERNALLY

Handling and checking of input parameters should be self-explanatory.

The actual program logic is embodied in AWK programs, which are contained in
Zaloha as "here documents".

The AWK program AWKPARSER parses the FIND operands assembled from
<findSourceOps> and <findGeneralOps> and constructs the FIND commands.
The outputs of running these FIND commands are tab-separated CSV metadata files
that contain all information needed for following steps. These CSV metadata
files, however, must first be processed by AWKCLEANER to handle (escape)
eventual tabs and newlines in filenames.

The cleaned CSV metadata files are then checked by AWKCHECKER for unexpected
deviations (in which case an error is thrown and the processing stops).

The next (optional) step is to detect hardlinks: the CSV metadata file from
<sourceDir> will be sorted by device number + inode number. This means that
multiply-linked files will be in adjacent records. The AWK program AWKHLINKS
evaluates this situation: The type of the first link will be kept as "file" (f),
the types of the other links will be changed to "hardlinks" (h).

Then comes the core function of Zaloha. The CSV metadata files from <sourceDir>
and <backupDir> will be united and sorted by filename and the Source/Backup
indicator. This means that objects existing in both directories will be in
adjacent records, with the <backupDir> record coming first. The AWK program
AWKDIFF evaluates this situation (as well as records from objects existing in
only one of the directories), and writes target state of synchronized
directories with actions to reach that target state.

The output of AWKDIFF is then sorted by filename in reverse order (so that
parent directories come after their children) and post-processed by AWKPOSTPROC.
AWKPOSTPROC modifies actions on parent directories of files to REV.NEW and
objects to KEEP only in <backupDir>.

The remaining code uses the produced data to perform actual work, and should be
self-explanatory.

Understanding AWKDIFF is the key to understanding of whole Zaloha. An important
hint to AWKDIFF is that there can be five types of filesystem objects in
<sourceDir> and four types of filesystem objects in <backupDir>. At any given
path, each type in <sourceDir> can meet each type in <backupDir>, plus each
type can be standalone in either <sourceDir> or <backupDir>. Mathematically,
this results in ( 5 x 4 ) + 5 + 4 = 29 cases to be handled by AWKDIFF:

                           backupDir:    d       f       l     other  (none)
  ---------------------------------------------------------------------------
  sourceDir:  directory          d  |    1       2       3       4      21
              file               f  |    5       6       7       8      22
              hardlink           h  |    9      10      11      12      23
              symbolic link      l  |   13      14      15      16      24
              other      p/s/c/b/D  |   17      18      19      20      25
              (none)                |   26      27      28      29
  ---------------------------------------------------------------------------

  Note 1: Hardlinks (h) cannot occur in <backupDir>, because the type "h" is not
  reported by FIND but determined by AWKHLINKS that can operate only on
  <sourceDir>.

  Note 2: Please see section Following Symbolic Links on when symbolic links
  are not reported as symbolic links by FIND.

The AWKDIFF code is commented on key places to make orientation easier.
A good case to begin with is case 6 (file in <sourceDir>, file in <backupDir>),
as this is the most important (and complex) case.

If you are a database developer, you can think of the CSV metadata files as
tables, and Zaloha as a program that operates on these tables: It fills them
with data obtained from the filesystems (via FIND), then processes the data
(defined sequence of sorts, sequential processings, unions and selects), then
converts the data to shellscripts, and finally executes the shellscripts
to apply the required changes back to the filesystems.

Among the operations which Zaloha performs, there is no operation which would
require the CSV metadata to fit as a whole into memory. This means that the size
of memory does not constrain Zaloha on how big "tasks" it can handle.
The critical operations from this perspective are the sorts. However,
GNU sort, for instance, is able to intelligently switch to an external
sort-merge algorithm, if it determines that the data is "too big",
thus mitigating this concern.

Talking further in database developer's language: The data model of all CSV
metadata files is the same and is described in form of comments in AWKPARSER.
Files 310 and 320 do not qualify as tables, as their fields and records are
broken by eventual tabs and newlines in filenames. In files 330 through 370,
field 2 is the Source/Backup indicator. In files 380 through 555, field 2 is
the Action Code.

The natural primary key in files 330 through 360 is the file's path (column 13).
In files 370 through 505, the natural primary key is combined column 13 with
column 2. In files 510 through 555, the natural primary key is again
column 13 alone.

The combined primary key in file 505 is obvious e.g. in the case of other object
in <sourceDir> and other object in <backupDir>: File 505 then contains an
OK record for the former and a KEEP record for the latter, both with the
same file's path (column 13).

###########################################################

TECHNIQUES USED BY ZALOHA TO HANDLE WEIRD CHARACTERS IN FILENAMES

Handling of "weird" characters in filenames was a special focus during
development of Zaloha. Actually, it was an exercise of how far can be gone with
shellscript alone, without reverting to a C program. Tested were:
!"#$%&'()*+,-.:;<=>?@[\]^`{|}~, spaces, tabs, newlines, alert (bell) and
a few national characters (beyond ASCII 127). Please note that some filesystem
types and operating systems do not permit some of these weird characters at all.

Zaloha internally uses tab-separated CSV files, also tabs and newlines are major
disruptors. The solution is based on the following idea: POSIX (the most
"liberal" standard under which Zaloha must function) says that filenames may
contain all characters except slash (/, the directory separator) and ASCII NUL.
Hence, except these two, no character can be used as an escape character
(if we do not want to introduce some re-coding). Further, ASCII NUL is not
suitable, as it is widely used as a string delimiter. Then, let's have a look
at the directory separator itself: It cannot occur inside of filenames.
It separates file and directory names in the paths. As filenames cannot have
zero length, no two slashes can appear in sequence. The only exception is the
naming convention for network-mounted directories, which may contain two
consecutive slashes at the beginning. But three consecutive slashes
(a triplet ///) are impossible. Hence, it is a waterproof escape sequence.
This opens the way to represent a tab as ///t and a newline as ///n.

For display of filenames on terminal (and only there), control characters (other
than tabs and newlines) are displayed as ///c, to avoid terminal disruption.
(Such control characters are still original in the CSV metadata files).

Further, /// is used as first field in the CSV metadata files, to allow easy
separation of record lines from continuation lines caused by newlines in
filenames (it is impossible that continuation lines have /// as the first field,
because filenames cannot contain the newline + /// sequence).

Finally, /// are used as terminator fields in the CSV metadata files, to be able
to determine where the filenames end in a situation when they contain tabs and
newlines (it is impossible that filenames produce a field containing /// alone,
because filenames cannot contain the tab + /// sequence).

An additional challenge is passing of variable values to AWK. During its
lexical parsing, AWK interprets backslash-led escape sequences. To avoid this,
backslashes are converted to ///b in the bash script, and ///b are converted
back to backslashes in the AWK programs.

Zaloha checks that no input parameters contain ///, to avoid breaking of the
internal escape logic from the outside. The only exception are <findSourceOps>
and <findGeneralOps>, which may contain the ///d/ placeholder.

In the shellscripts produced by Zaloha, single quoting is used, hence single
quotes are disruptors. As a solution, the '"'"' quoting technique is used.

The SORT commands are invoked under the LC_ALL=C environment variable, to avoid
problems caused by some locales that ignore slashes and other punctuations
during sorting.

In the CSV metadata files 330 through 500 (i.e. those which undergo the sorts),
file's paths (field 13) have directory separators (/) appended and all
directory separators then converted to ///s. This is to ensure correct sort
ordering. Imagine the ordering bugs that would happen otherwise:
  Case 1: given dir and dir!, they would be sort ordered:
          dir, dir!, dir!/subdir, dir/subdir.
  Case 2: given dir and dir<tab>ectory, they would be sort ordered:
          dir/!subdir1, dir///tectory, dir/subdir2.

Zaloha does not contain any explicit handling of national characters in
filenames (= characters beyond ASCII 127). It is assumed that the commands used
by Zaloha handle them transparently (which should be tested on environments
where this topic is relevant). <sourceDir> and <backupDir> must use the same
code page for national characters in filenames, because Zaloha does not contain
any code page conversions.

###########################################################

ADVANCED USE OF ZALOHA - DIRECTORIES NOT AVAILABLE LOCALLY

Zaloha contains several options to handle situations when <sourceDir> and/or
<backupDir> are not available locally. In the extreme case, Zaloha can be used
as a mere "difference engine" by a wrapper script, which obtains the inputs
(FIND data from <sourceDir> and/or <backupDir>) remotely, and also applies the
outputs (= executes the Exec1/2/3/4/5 scripts) remotely.

First useful option is "--noDirChecks": This switches off the checks for local
existence of <sourceDir> and <backupDir>.

If <backupDir> is not available locally, it is necessary to use the "--metaDir"
option to place the Zaloha metadata directory to a different location accessible
to Zaloha.

Next useful options are "--noFindSource" and/or "--noFindBackup": They instruct
Zaloha to not run FIND on <sourceDir> and/or <backupDir>, but use externally
supplied CSV metadata files 310 and/or 320 instead. This means that these files
must be produced by the wrapper script (e.g. by running FIND commands in an SSH
session) and downloaded to the Zaloha metadata directory before invoking Zaloha.
These files must, of course, have the same names and contents as the CSV
metadata files that would otherwise be produced by the scripts 210 and/or 220.

The "--noFindSource" and/or "--noFindBackup" options are also useful when
network-mounted directories are available locally, but running FIND on them is
slow. Running the FINDs directly on the respective file servers in SSH sessions
should be much quicker.

If <sourceDir> or <backupDir> are not available locally, the "--noExec" option
must be used to prevent execution of the Exec1/2/3/4/5 scripts by Zaloha itself.

Last set of useful options are "--noExec1Hdr" through "--noExec5Hdr". They
instruct Zaloha to produce header-less Exec1/2/3/4/5 scripts (i.e. bodies only).
The headers normally contain definitions used in the bodies of the scripts.
Header-less scripts can be easily used with alternative headers that contain
different definitions. This gives much flexibility:

The "command variables" can be assigned to different commands (e.g. cp -> scp).
Own shell functions can be defined and assigned to the "command variables".
This makes more elaborate processing possible, as well as calling commands that
have different order of command line arguments. Next, the "directory variables"
sourceDir and backupDir can be assigned to empty strings, thus causing the paths
passed to the commands to be not prefixed by <sourceDir> or <backupDir>.

###########################################################

ADVANCED USE OF ZALOHA - COPYING FILES IN PARALLEL

First, let's clarify when parallel operations do not make sense: When copying
files locally, even one single process will probably fully utilize the available
bus capacity. In such cases, copying files in parallel does not make sense.

On the contrary, imagine what happens when a process copies a small file over
a network with high latency: sending out the small file takes microseconds,
but waiting for the network round-trip to finish takes milliseconds. Also, the
process is idle most of the time, and the network capacity is under-utilized.
In such cases, also typically when many small files are copied over a network,
running the processes in parallel will speed up the process significantly.

Zaloha provides support for parallel operations of up to 8 parallel processes
(constant MAXPARALLEL). How to utilize this support:

Let's take the Exec2 script as an example (file 620): make 1+8=9 copies of the
Exec2 script. In the header of the first copy, keep only MKDIR, CHOWN_DIR,
CHGRP_DIR and CHMOD_DIR assigned to real commands, and assign all other
"command variables" to the empty command (shell builtin ":"). This first copy
will hence prepare only the directories and must run first. In the next copy,
keep only CP1, TOUCH1, UNLINK1, CHOWN1, CHGRP1 and CHMOD1 assigned to real
commands. In the over-next copy, keep only CP2, TOUCH2, UNLINK2, CHOWN2, CHGRP2
and CHMOD2 assigned to real commands, and so on in the other copies. Each of
these remaining 8 copies will hence process only its own portion of files, so
they can be run in parallel.

These manipulations should, of course, be automated by a wrapper script: The
wrapper script should invoke Zaloha with the "--noExec" and "--noExec2Hdr"
options, also Zaloha prepares the 620 script without header (i.e. body only).
The wrapper script should prepare the 1+8 different headers and use them
with the header-less 620 script.

Exec1 and Exec4: use the same recipe, except that the script which removes
the directories must run last, of course, not first.

###########################################################

ADVANCED USE OF ZALOHA - COMPARING CONTENTS OF FILES

First, let's make it clear that comparing contents of files will increase the
runtime dramatically, because instead of reading just the directory data to
obtain file sizes and modification times, the files themselves must be read.

ALTERNATIVE 1: option "--byteByByte" (suitable if both filesystems are local)

Option "--byteByByte" forces Zaloha to compare "byte by byte" files that appear
identical (more precisely, files for which either no action (OK) or just update
of attributes (ATTR) has been prepared). If additional updates of files result
from this comparison, they will be executed in step Exec5.

ALTERNATIVE 2: overload the file size field (CSV column 4) with SHA-256 hash

The idea is: Zaloha does not compare file sizes numerically, but as strings.
Also, appending semicolon (";") and the SHA-256 hash to the file size field
achieves exactly what is needed: If the file sizes are identical but the SHA-256
hashes differ, Zaloha will detect that the files need synchronization.

There is an almost 100% security that files are identical if they have equal
sizes and SHA-256 hashes. An implementation requires use of the "--noFindSource"
and "--noFindBackup" options with own mechanism of (local or remote) preparation
of CSV metadata files 310 and 320 with column 4 overloaded as described.

###########################################################

CYBER SECURITY TOPICS

Standard security practices should be followed on environments exposed to
potential attackers: Potential attackers should not be allowed to modify the
command line that invokes Zaloha, the PATH variable, bash init scripts or other
items that may influence how Zaloha works and invokes operating system commands.

Further, the following security threats arise from backup of a directory that is
writable by a potential attacker:

Backup media overflow attack via hardlinks
------------------------------------------
The attacker might create a huge file in his home directory and hardlink it
many thousands times, hoping that the backup program writes all copies to
the backup media ...

Mitigation with Zaloha: perform hardlink detection (use the "--hLinks" option)

Backup media overflow attack via symbolic links
-----------------------------------------------
The attacker might create many symbolic links pointing to directories with huge
contents outside of his home directory, hoping that the backup program writes
all linked contents to the backup media ...

Mitigation with Zaloha: do not follow symbolic links on <sourceDir> (do not use
                        the "--followSLinksS" option)

Privilege escalation attacks
----------------------------
The attacker might create a rogue executable program in his home directory with
the SetUID and/or SetGID bits set, hoping that within the backup process (or
within the restore process, which he might explicitly request for this purpose),
the user/group ownership of his rogue program changes to a user/group with
higher privileges (ideally root), the SetUID and/or SetGID bits will be restored
and he will have access to this program ...

Mitigation with Zaloha: Prevent this scenario. Be specially careful with options
                        "--pMode" and "--pRevMode" and with the restore script
                        860_restore_mode.sh

Shell code injection attacks
----------------------------
The attacker might create a file in his home directory with a name that is
actually a rogue shell code (e.g. '; rm -Rf ..'), hoping that the shell code
will, due to some program flaw, be executed by a user with higher privileges.

Mitigation with Zaloha: currently not aware of such vulnerability within Zaloha.
                        If found, please open a high priority issue on GitHub.

###########################################################
ZALOHADOCU
}

# DEFINITIONS OF INDIVIDUAL FILES IN METADATA DIRECTORY OF ZALOHA

f000Base="000_parameters.csv"        # parameters under which Zaloha was invoked and internal variables

f100Base="100_awkpreproc.awk"        # AWK preprocessor for other AWK programs
f102Base="102_xtrace2term.awk"       # AWK program for terminal display of shell traces (with control characters escaped), color handling
f104Base="104_actions2term.awk"      # AWK program for terminal display of actions (with control characters escaped), color handling
f106Base="106_parser.awk"            # AWK program for parsing of FIND operands and construction of FIND commands
f110Base="110_cleaner.awk"           # AWK program for handling of raw outputs of FIND (escape tabs and newlines, field 13 handling)
f130Base="130_checker.awk"           # AWK program for checking
f150Base="150_hlinks.awk"            # AWK program for hardlink detection (inode-deduplication)
f170Base="170_diff.awk"              # AWK program for differences processing
f190Base="190_postproc.awk"          # AWK program for differences post-processing and splitting off Exec1 and Exec4 actions

f200Base="200_find_lastrun.sh"       # shellscript for FIND on <metaDir>/999_mark_executed
f210Base="210_find_source.sh"        # shellscript for FIND on <sourceDir>
f220Base="220_find_backup.sh"        # shellscript for FIND on <backupDir>

f300Base="300_lastrun.csv"           # output of FIND on <metaDir>/999_mark_executed
f310Base="310_source_raw.csv"        # raw output of FIND on <sourceDir>
f320Base="320_backup_raw.csv"        # raw output of FIND on <backupDir>
f330Base="330_source_clean.csv"      # <sourceDir> metadata clean (escaped tabs and newlines, field 13 handling)
f340Base="340_backup_clean.csv"      # <backupDir> metadata clean (escaped tabs and newlines, field 13 handling)
f350Base="350_source_s_hlinks.csv"   # <sourceDir> metadata sorted for hardlink detection (inode-deduplication)
f360Base="360_source_hlinks.csv"     # <sourceDir> metadata after hardlink detection (inode-deduplication)
f370Base="370_union_s_diff.csv"      # <sourceDir> + <backupDir> metadata united and sorted for differences processing
f380Base="380_diff.csv"              # result of differences processing
f390Base="390_diff_r_post.csv"       # differences result reverse sorted for post-processing and splitting off Exec1 and Exec4 actions

f405Base="405_select23.awk"          # AWK program for selection of Exec2 and Exec3 actions
f410Base="410_exec1.awk"             # AWK program for preparation of shellscripts for Exec1 and Exec4
f420Base="420_exec2.awk"             # AWK program for preparation of shellscripts for Exec2 and Exec5
f430Base="430_exec3.awk"             # AWK program for preparation of shellscript for Exec3
f490Base="490_touch.awk"             # AWK program for preparation of shellscript to touch file 999_mark_executed

f500Base="500_target_r.csv"          # differences result after splitting off Exec1 and Exec4 actions (= target state) reverse sorted
f505Base="505_target.csv"            # target state (includes Exec2 and Exec3 actions) of synchronized directories
f510Base="510_exec1.csv"             # Exec1 actions (reverse sorted)
f520Base="520_exec2.csv"             # Exec2 actions
f530Base="530_exec3.csv"             # Exec3 actions
f540Base="540_exec4.csv"             # Exec4 actions (reverse sorted)
f550Base="550_exec5.csv"             # Exec5 actions
f555Base="555_byte_by_byte.csv"      # result of byte by byte comparing of files that appear identical

f610Base="610_exec1.sh"              # shellscript for Exec1
f620Base="620_exec2.sh"              # shellscript for Exec2
f630Base="630_exec3.sh"              # shellscript for Exec3
f640Base="640_exec4.sh"              # shellscript for Exec4
f650Base="650_exec5.sh"              # shellscript for Exec5
f690Base="690_touch.sh"              # shellscript to touch file 999_mark_executed

f700Base="700_restore.awk"           # AWK program for preparation of shellscripts for the case of restore

f800Base="800_restore_dirs.sh"       # for the case of restore: shellscript to restore directories
f810Base="810_restore_files.sh"      # for the case of restore: shellscript to restore files
f820Base="820_restore_sym_links.sh"  # for the case of restore: shellscript to restore symbolic links
f830Base="830_restore_hardlinks.sh"  # for the case of restore: shellscript to restore hardlinks
f840Base="840_restore_user_own.sh"   # for the case of restore: shellscript to restore user ownerships
f850Base="850_restore_group_own.sh"  # for the case of restore: shellscript to restore group ownerships
f860Base="860_restore_mode.sh"       # for the case of restore: shellscript to restore modes (permission bits)

f999Base="999_mark_executed"         # empty touchfile marking execution of actions

###########################################################
set -u
set -e
set -o pipefail

function error_exit {
  echo "Zaloha.sh: ${1}" >&2
  exit 1
}

trap 'error_exit "Error on line ${LINENO}"' ERR

function opt_dupli_check {
  if [ ${1} -eq 1 ]; then
    error_exit "Option ${2} passed in two or more times"
  fi
}

function start_progress {
  if [ ${noProgress} -eq 0 ]; then
    echo -n "    ${1} ${DOTS60:1:$(( 53 - ${#1} ))}"
    progressCurrColNo=58
  fi
}

function start_progress_by_chars {
  if [ ${noProgress} -eq 0 ]; then
    echo -n "    ${1} "
    (( progressCurrColNo = ${#1} + 5 ))
  fi
}

function progress_char {
  if [ ${noProgress} -eq 0 ]; then
    if [ ${progressCurrColNo} -ge 80 ]; then
      echo -ne "\n    "
      progressCurrColNo=4
    fi
    echo -n "${1}"
    (( progressCurrColNo++ ))
  fi
}

function stop_progress {
  if [ ${noProgress} -eq 0 ]; then
    if [ ${progressCurrColNo} -gt 58 ]; then
      echo -ne "\n    "
      progressCurrColNo=4
    fi
    echo "${BLANKS60:1:$(( 58 - ${progressCurrColNo} ))} done."
  fi
}

function file_not_prepared {
  if [ -e "${1}" ]; then
    rm -f "${1}"
  fi
}

function optim_csv_after_use {
  if [ ${optimCSV} -eq 1 ]; then
    rm -f "${1}"
  fi
}

function echo_args_with_ifs {
  echo "${*}"
}

TAB=$'\t'
NLINE=$'\n'
BSLASHPATTERN='\\'
DQUOTEPATTERN='\"'
DQUOTE='"'
ASTERISKPATTERN='\*'
ASTERISK='*'
QUESTIONMARKPATTERN='\?'
QUESTIONMARK='?'
LBRACKETPATTERN='\['
LBRACKET='['
RBRACKETPATTERN='\]'
RBRACKET=']'
CNTRLPATTERN='[[:cntrl:]]'
TRIPLETDSEP='///d/'  # placeholder in FIND patterns for <sourceDir> or <backupDir> followed by directory separator
TRIPLETT='///t'      # escape for tab
TRIPLETN='///n'      # escape for newline
TRIPLETB='///b'      # escape for backslash
TRIPLETC='///c'      # display of control characters on terminal
TRIPLET='///'        # escape sequence, leading field, terminator field

FSTAB=$'\t'
TERMNORM=$'\033''[0m'
TERMBLUE=$'\033''[94m'
printf -v BLANKS60 '%60s' ' '
DOTS60="${BLANKS60// /.}"

###########################################################
sourceDir=
sourceDirPassed=0
backupDir=
backupDirPassed=0
findSourceOps=
findGeneralOps=
findGeneralOpsPassed=0
noExec=0
noRemove=0
revNew=0
revUp=0
hLinks=0
ok2s=0
ok3600s=0
byteByByte=0
noUnlink=0
touch=0
pUser=0
pGroup=0
pMode=0
pRevUser=0
pRevGroup=0
pRevMode=0
followSLinksS=0
followSLinksB=0
noWarnSLinks=0
noRestore=0
optimCSV=0
metaDir=
metaDirPassed=0
noDirChecks=0
noLastRun=0
noIdentCheck=0
noFindSource=0
noFindBackup=0
noExec1Hdr=0
noExec2Hdr=0
noExec3Hdr=0
noExec4Hdr=0
noExec5Hdr=0
noR800Hdr=0
noR810Hdr=0
noR820Hdr=0
noR830Hdr=0
noR840Hdr=0
noR850Hdr=0
noR860Hdr=0
noProgress=0
color=0
mawk=0
lTest=0
help=0

for tmpVal in "${@}"
do
  case "${tmpVal}" in
    --sourceDir=*)       opt_dupli_check ${sourceDirPassed} "${tmpVal%%=*}";  sourceDir="${tmpVal#*=}";  sourceDirPassed=1 ;;
    --backupDir=*)       opt_dupli_check ${backupDirPassed} "${tmpVal%%=*}";  backupDir="${tmpVal#*=}";  backupDirPassed=1 ;;
    --findSourceOps=*)   findSourceOps="${findSourceOps}${tmpVal#*=} " ;;
    --findGeneralOps=*)  findGeneralOps="${findGeneralOps}${tmpVal#*=} ";  findGeneralOpsPassed=1 ;;
    --noExec)            opt_dupli_check ${noExec} "${tmpVal}";         noExec=1 ;;
    --noRemove)          opt_dupli_check ${noRemove} "${tmpVal}";       noRemove=1 ;;
    --revNew)            opt_dupli_check ${revNew} "${tmpVal}";         revNew=1 ;;
    --revUp)             opt_dupli_check ${revUp} "${tmpVal}";          revUp=1 ;;
    --hLinks)            opt_dupli_check ${hLinks} "${tmpVal}";         hLinks=1 ;;
    --ok2s)              opt_dupli_check ${ok2s} "${tmpVal}";           ok2s=1 ;;
    --ok3600s)           opt_dupli_check ${ok3600s} "${tmpVal}";        ok3600s=1 ;;
    --byteByByte)        opt_dupli_check ${byteByByte} "${tmpVal}";     byteByByte=1 ;;
    --noUnlink)          opt_dupli_check ${noUnlink} "${tmpVal}";       noUnlink=1 ;;
    --touch)             opt_dupli_check ${touch} "${tmpVal}";          touch=1 ;;
    --pUser)             opt_dupli_check ${pUser} "${tmpVal}";          pUser=1 ;;
    --pGroup)            opt_dupli_check ${pGroup} "${tmpVal}";         pGroup=1 ;;
    --pMode)             opt_dupli_check ${pMode} "${tmpVal}";          pMode=1 ;;
    --pRevUser)          opt_dupli_check ${pRevUser} "${tmpVal}";       pRevUser=1 ;;
    --pRevGroup)         opt_dupli_check ${pRevGroup} "${tmpVal}";      pRevGroup=1 ;;
    --pRevMode)          opt_dupli_check ${pRevMode} "${tmpVal}";       pRevMode=1 ;;
    --followSLinksS)     opt_dupli_check ${followSLinksS} "${tmpVal}";  followSLinksS=1 ;;
    --followSLinksB)     opt_dupli_check ${followSLinksB} "${tmpVal}";  followSLinksB=1 ;;
    --noWarnSLinks)      opt_dupli_check ${noWarnSLinks} "${tmpVal}";   noWarnSLinks=1 ;;
    --noRestore)         opt_dupli_check ${noRestore} "${tmpVal}";      noRestore=1 ;;
    --optimCSV)          opt_dupli_check ${optimCSV} "${tmpVal}";       optimCSV=1 ;;
    --metaDir=*)         opt_dupli_check ${metaDirPassed} "${tmpVal%%=*}";  metaDir="${tmpVal#*=}";  metaDirPassed=1 ;;
    --noDirChecks)       opt_dupli_check ${noDirChecks} "${tmpVal}";    noDirChecks=1 ;;
    --noLastRun)         opt_dupli_check ${noLastRun} "${tmpVal}";      noLastRun=1 ;;
    --noIdentCheck)      opt_dupli_check ${noIdentCheck} "${tmpVal}";   noIdentCheck=1 ;;
    --noFindSource)      opt_dupli_check ${noFindSource} "${tmpVal}";   noFindSource=1 ;;
    --noFindBackup)      opt_dupli_check ${noFindBackup} "${tmpVal}";   noFindBackup=1 ;;
    --noExec1Hdr)        opt_dupli_check ${noExec1Hdr} "${tmpVal}";     noExec1Hdr=1 ;;
    --noExec2Hdr)        opt_dupli_check ${noExec2Hdr} "${tmpVal}";     noExec2Hdr=1 ;;
    --noExec3Hdr)        opt_dupli_check ${noExec3Hdr} "${tmpVal}";     noExec3Hdr=1 ;;
    --noExec4Hdr)        opt_dupli_check ${noExec4Hdr} "${tmpVal}";     noExec4Hdr=1 ;;
    --noExec5Hdr)        opt_dupli_check ${noExec5Hdr} "${tmpVal}";     noExec5Hdr=1 ;;
    --noR800Hdr)         opt_dupli_check ${noR800Hdr} "${tmpVal}";      noR800Hdr=1 ;;
    --noR810Hdr)         opt_dupli_check ${noR810Hdr} "${tmpVal}";      noR810Hdr=1 ;;
    --noR820Hdr)         opt_dupli_check ${noR820Hdr} "${tmpVal}";      noR820Hdr=1 ;;
    --noR830Hdr)         opt_dupli_check ${noR830Hdr} "${tmpVal}";      noR830Hdr=1 ;;
    --noR840Hdr)         opt_dupli_check ${noR840Hdr} "${tmpVal}";      noR840Hdr=1 ;;
    --noR850Hdr)         opt_dupli_check ${noR850Hdr} "${tmpVal}";      noR850Hdr=1 ;;
    --noR860Hdr)         opt_dupli_check ${noR860Hdr} "${tmpVal}";      noR860Hdr=1 ;;
    --noProgress)        opt_dupli_check ${noProgress} "${tmpVal}";     noProgress=1 ;;
    --color)             opt_dupli_check ${color} "${tmpVal}";          color=1 ;;
    --mawk)              opt_dupli_check ${mawk} "${tmpVal}";           mawk=1 ;;
    --lTest)             opt_dupli_check ${lTest} "${tmpVal}";          lTest=1 ;;
    --help)              opt_dupli_check ${help} "${tmpVal}";           help=1 ;;
    *) error_exit "Unknown option ${tmpVal//${CNTRLPATTERN}/${TRIPLETC}}, get help via Zaloha.sh --help" ;;
  esac
done

if [ ${help} -eq 1 ]; then
  zaloha_docu
  exit 0
fi

if [ ${revNew} -eq 1 ] && [ ${noLastRun} -eq 1 ]; then
  error_exit "Option --revNew may not be used if option --noLastRun is given"
fi
if [ ${noExec1Hdr} -eq 1 ] && [ ${noExec} -eq 0 ]; then
  error_exit "Option --noExec1Hdr can be used only together with option --noExec"
fi
if [ ${noExec2Hdr} -eq 1 ] && [ ${noExec} -eq 0 ]; then
  error_exit "Option --noExec2Hdr can be used only together with option --noExec"
fi
if [ ${noExec3Hdr} -eq 1 ] && [ ${noExec} -eq 0 ]; then
  error_exit "Option --noExec3Hdr can be used only together with option --noExec"
fi
if [ ${noExec4Hdr} -eq 1 ] && [ ${noExec} -eq 0 ]; then
  error_exit "Option --noExec4Hdr can be used only together with option --noExec"
fi
if [ ${noExec5Hdr} -eq 1 ] && [ ${noExec} -eq 0 ]; then
  error_exit "Option --noExec5Hdr can be used only together with option --noExec"
fi

if [ ${mawk} -eq 1 ]; then
  awk="mawk"
  awkNoBuf="mawk -W interactive"
elif [ ${lTest} -eq 1 ]; then
  awk="awk -Lfatal"
  awkNoBuf="awk -Lfatal"
else
  awk="awk"
  awkNoBuf="awk"
fi

###########################################################
if [ "" == "${sourceDir}" ]; then
  error_exit "<sourceDir> is mandatory, get help via Zaloha.sh --help"
fi
if [ "${sourceDir/${TRIPLET}/}" != "${sourceDir}" ]; then
  error_exit "<sourceDir> contains the directory separator triplet (${TRIPLET})"
fi
if [ "/" != "${sourceDir:0:1}" ] && [ "./" != "${sourceDir:0:2}" ]; then
  sourceDir="./${sourceDir}"
fi
if [ "/" != "${sourceDir: -1:1}" ]; then
  sourceDir="${sourceDir}/"
fi
if [ ${noDirChecks} -eq 0 ] && [ ! -d "${sourceDir}" ]; then
  error_exit "<sourceDir> is not a directory"
fi
sourceDirAwk="${sourceDir//${BSLASHPATTERN}/${TRIPLETB}}"
sourceDirPattAwk="${sourceDir//${BSLASHPATTERN}/${TRIPLETB}${TRIPLETB}}"
sourceDirPattAwk="${sourceDirPattAwk//${ASTERISKPATTERN}/${TRIPLETB}${ASTERISK}}"
sourceDirPattAwk="${sourceDirPattAwk//${QUESTIONMARKPATTERN}/${TRIPLETB}${QUESTIONMARK}}"
sourceDirPattAwk="${sourceDirPattAwk//${LBRACKETPATTERN}/${TRIPLETB}${LBRACKET}}"
sourceDirPattAwk="${sourceDirPattAwk//${RBRACKETPATTERN}/${TRIPLETB}${RBRACKET}}"
sourceDirEsc="${sourceDir//${TAB}/${TRIPLETT}}"
sourceDirEsc="${sourceDirEsc//${NLINE}/${TRIPLETN}}"
if [ ${color} -eq 1 ]; then
  sourceDirTerm="${sourceDirEsc//${CNTRLPATTERN}/${TERMBLUE}${TRIPLETC}${TERMNORM}}"
  sourceDirTerm="${sourceDirTerm//${TRIPLETT}/${TERMBLUE}${TRIPLETT}${TERMNORM}}"
  sourceDirTerm="${sourceDirTerm//${TRIPLETN}/${TERMBLUE}${TRIPLETN}${TERMNORM}}"
else
  sourceDirTerm="${sourceDirEsc//${CNTRLPATTERN}/${TRIPLETC}}"
fi

###########################################################
if [ "" == "${backupDir}" ]; then
  error_exit "<backupDir> is mandatory, get help via Zaloha.sh --help"
fi
if [ "${backupDir/${TRIPLET}/}" != "${backupDir}" ]; then
  error_exit "<backupDir> contains the directory separator triplet (${TRIPLET})"
fi
if [ "/" != "${backupDir:0:1}" ] && [ "./" != "${backupDir:0:2}" ]; then
  backupDir="./${backupDir}"
fi
if [ "/" != "${backupDir: -1:1}" ]; then
  backupDir="${backupDir}/"
fi
if [ ${noDirChecks} -eq 0 ] && [ ! -d "${backupDir}" ]; then
  error_exit "<backupDir> is not a directory"
fi
backupDirAwk="${backupDir//${BSLASHPATTERN}/${TRIPLETB}}"
backupDirPattAwk="${backupDir//${BSLASHPATTERN}/${TRIPLETB}${TRIPLETB}}"
backupDirPattAwk="${backupDirPattAwk//${ASTERISKPATTERN}/${TRIPLETB}${ASTERISK}}"
backupDirPattAwk="${backupDirPattAwk//${QUESTIONMARKPATTERN}/${TRIPLETB}${QUESTIONMARK}}"
backupDirPattAwk="${backupDirPattAwk//${LBRACKETPATTERN}/${TRIPLETB}${LBRACKET}}"
backupDirPattAwk="${backupDirPattAwk//${RBRACKETPATTERN}/${TRIPLETB}${RBRACKET}}"
backupDirEsc="${backupDir//${TAB}/${TRIPLETT}}"
backupDirEsc="${backupDirEsc//${NLINE}/${TRIPLETN}}"
if [ ${color} -eq 1 ]; then
  backupDirTerm="${backupDirEsc//${CNTRLPATTERN}/${TERMBLUE}${TRIPLETC}${TERMNORM}}"
  backupDirTerm="${backupDirTerm//${TRIPLETT}/${TERMBLUE}${TRIPLETT}${TERMNORM}}"
  backupDirTerm="${backupDirTerm//${TRIPLETN}/${TERMBLUE}${TRIPLETN}${TERMNORM}}"
else
  backupDirTerm="${backupDirEsc//${CNTRLPATTERN}/${TRIPLETC}}"
fi

###########################################################
tmpVal="${findSourceOps//${TRIPLETDSEP}/M}"
if [ "${tmpVal/${TRIPLET}/}" != "${tmpVal}" ]; then
  error_exit "<findSourceOps> contains the directory separator triplet (${TRIPLET})"
fi
findSourceOpsAwk="${findSourceOps//${BSLASHPATTERN}/${TRIPLETB}}"
findSourceOpsEsc="${findSourceOps//${TAB}/${TRIPLETT}}"
findSourceOpsEsc="${findSourceOpsEsc//${NLINE}/${TRIPLETN}}"

###########################################################
findGeneralOpsDefault=
findGeneralOpsDefault="${findGeneralOpsDefault}-ipath ${TRIPLETDSEP}\$RECYCLE.BIN -prune -o "
findGeneralOpsDefault="${findGeneralOpsDefault}-path ${TRIPLETDSEP}.Trash-[0-9]* -prune -o "
findGeneralOpsDefault="${findGeneralOpsDefault}-path ${TRIPLETDSEP}lost+found -prune -o "
if [ "+" == "${findGeneralOps:0:1}" ]; then
  findGeneralOps="${findGeneralOpsDefault} ${findGeneralOps:1}"
elif [ ${findGeneralOpsPassed} -eq 0 ]; then
  findGeneralOps="${findGeneralOpsDefault}"
fi
tmpVal="${findGeneralOps//${TRIPLETDSEP}/M}"
if [ "${tmpVal/${TRIPLET}/}" != "${tmpVal}" ]; then
  error_exit "<findGeneralOps> contains the directory separator triplet (${TRIPLET})"
fi
findGeneralOpsAwk="${findGeneralOps//${BSLASHPATTERN}/${TRIPLETB}}"
findGeneralOpsEsc="${findGeneralOps//${TAB}/${TRIPLETT}}"
findGeneralOpsEsc="${findGeneralOpsEsc//${NLINE}/${TRIPLETN}}"

###########################################################
metaDirDefaultBase=".Zaloha_metadata"
metaDirDefault="${backupDir}${metaDirDefaultBase}"
if [ ${metaDirPassed} -eq 0 ]; then
  metaDir="${metaDirDefault}"
fi
if [ "" == "${metaDir}" ]; then
  error_exit "<metaDir> is mandatory if --metaDir option is given"
fi
if [ "/" != "${metaDir:0:1}" ] && [ "./" != "${metaDir:0:2}" ]; then
  metaDir="./${metaDir}"
fi
if [ "/" != "${metaDir: -1:1}" ]; then
  metaDir="${metaDir}/"
fi
if [ "${metaDir/${TRIPLET}/}" != "${metaDir}" ]; then
  error_exit "<metaDir> contains the directory separator triplet (${TRIPLET})"
fi
metaDirAwk="${metaDir//${BSLASHPATTERN}/${TRIPLETB}}"
metaDirPattAwk="${metaDir//${BSLASHPATTERN}/${TRIPLETB}${TRIPLETB}}"
metaDirPattAwk="${metaDirPattAwk//${ASTERISKPATTERN}/${TRIPLETB}${ASTERISK}}"
metaDirPattAwk="${metaDirPattAwk//${QUESTIONMARKPATTERN}/${TRIPLETB}${QUESTIONMARK}}"
metaDirPattAwk="${metaDirPattAwk//${LBRACKETPATTERN}/${TRIPLETB}${LBRACKET}}"
metaDirPattAwk="${metaDirPattAwk//${RBRACKETPATTERN}/${TRIPLETB}${RBRACKET}}"
metaDirEsc="${metaDir//${TAB}/${TRIPLETT}}"
metaDirEsc="${metaDirEsc//${NLINE}/${TRIPLETN}}"

###########################################################
findLastRunOpsFinalAwk="-path ${TRIPLETDSEP}${f999Base}"
findSourceOpsFinalAwk="${findGeneralOpsAwk} ${findSourceOpsAwk}"
findBackupOpsFinalAwk="${findGeneralOpsAwk}"

if [ ${metaDirPassed} -eq 0 ]; then
  findSourceOpsFinalAwk="-path ${TRIPLETDSEP}${metaDirDefaultBase} -prune -o ${findSourceOpsFinalAwk}"
  findBackupOpsFinalAwk="-path ${TRIPLETDSEP}${metaDirDefaultBase} -prune -o ${findBackupOpsFinalAwk}"
fi

###########################################################
if [ ! -d "${metaDir}" ]; then
  mkdir -p "${metaDir}"
fi

f000="${metaDir}${f000Base}"
f100="${metaDir}${f100Base}"
f102="${metaDir}${f102Base}"
f104="${metaDir}${f104Base}"
f106="${metaDir}${f106Base}"
f110="${metaDir}${f110Base}"
f130="${metaDir}${f130Base}"
f150="${metaDir}${f150Base}"
f170="${metaDir}${f170Base}"
f190="${metaDir}${f190Base}"
f200="${metaDir}${f200Base}"
f210="${metaDir}${f210Base}"
f220="${metaDir}${f220Base}"
f300="${metaDir}${f300Base}"
f310="${metaDir}${f310Base}"
f320="${metaDir}${f320Base}"
f330="${metaDir}${f330Base}"
f340="${metaDir}${f340Base}"
f350="${metaDir}${f350Base}"
f360="${metaDir}${f360Base}"
f370="${metaDir}${f370Base}"
f380="${metaDir}${f380Base}"
f390="${metaDir}${f390Base}"
f405="${metaDir}${f405Base}"
f410="${metaDir}${f410Base}"
f420="${metaDir}${f420Base}"
f430="${metaDir}${f430Base}"
f490="${metaDir}${f490Base}"
f500="${metaDir}${f500Base}"
f505="${metaDir}${f505Base}"
f510="${metaDir}${f510Base}"
f520="${metaDir}${f520Base}"
f530="${metaDir}${f530Base}"
f540="${metaDir}${f540Base}"
f550="${metaDir}${f550Base}"
f555="${metaDir}${f555Base}"
f610="${metaDir}${f610Base}"
f620="${metaDir}${f620Base}"
f630="${metaDir}${f630Base}"
f640="${metaDir}${f640Base}"
f650="${metaDir}${f650Base}"
f690="${metaDir}${f690Base}"
f700="${metaDir}${f700Base}"
f800="${metaDir}${f800Base}"
f810="${metaDir}${f810Base}"
f820="${metaDir}${f820Base}"
f830="${metaDir}${f830Base}"
f840="${metaDir}${f840Base}"
f850="${metaDir}${f850Base}"
f860="${metaDir}${f860Base}"
f999="${metaDir}${f999Base}"

f300Awk="${metaDirAwk}${f300Base}"
f310Awk="${metaDirAwk}${f310Base}"
f320Awk="${metaDirAwk}${f320Base}"
f510Awk="${metaDirAwk}${f510Base}"
f520Awk="${metaDirAwk}${f520Base}"
f530Awk="${metaDirAwk}${f530Base}"
f540Awk="${metaDirAwk}${f540Base}"
f800Awk="${metaDirAwk}${f800Base}"
f810Awk="${metaDirAwk}${f810Base}"
f820Awk="${metaDirAwk}${f820Base}"
f830Awk="${metaDirAwk}${f830Base}"
f840Awk="${metaDirAwk}${f840Base}"
f850Awk="${metaDirAwk}${f850Base}"
f860Awk="${metaDirAwk}${f860Base}"

###########################################################
${awk} '{ print }' << PARAMFILE > "${f000}"
${TRIPLET}${FSTAB}sourceDir${FSTAB}${sourceDir}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirAwk${FSTAB}${sourceDirAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirPattAwk${FSTAB}${sourceDirPattAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirEsc${FSTAB}${sourceDirEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}sourceDirTerm${FSTAB}${sourceDirTerm}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDir${FSTAB}${backupDir}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirAwk${FSTAB}${backupDirAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirPattAwk${FSTAB}${backupDirPattAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirEsc${FSTAB}${backupDirEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}backupDirTerm${FSTAB}${backupDirTerm}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOps${FSTAB}${findSourceOps}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOpsAwk${FSTAB}${findSourceOpsAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOpsEsc${FSTAB}${findSourceOpsEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOps${FSTAB}${findGeneralOps}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOpsAwk${FSTAB}${findGeneralOpsAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOpsEsc${FSTAB}${findGeneralOpsEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findGeneralOpsPassed${FSTAB}${findGeneralOpsPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noExec${FSTAB}${noExec}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noRemove${FSTAB}${noRemove}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}revNew${FSTAB}${revNew}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}revUp${FSTAB}${revUp}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}hLinks${FSTAB}${hLinks}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}ok2s${FSTAB}${ok2s}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}ok3600s${FSTAB}${ok3600s}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}byteByByte${FSTAB}${byteByByte}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noUnlink${FSTAB}${noUnlink}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}touch${FSTAB}${touch}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pUser${FSTAB}${pUser}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pGroup${FSTAB}${pGroup}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pMode${FSTAB}${pMode}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pRevUser${FSTAB}${pRevUser}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pRevGroup${FSTAB}${pRevGroup}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}pRevMode${FSTAB}${pRevMode}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}followSLinksS${FSTAB}${followSLinksS}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}followSLinksB${FSTAB}${followSLinksB}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noWarnSLinks${FSTAB}${noWarnSLinks}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noRestore${FSTAB}${noRestore}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}optimCSV${FSTAB}${optimCSV}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDir${FSTAB}${metaDir}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirAwk${FSTAB}${metaDirAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirPattAwk${FSTAB}${metaDirPattAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirEsc${FSTAB}${metaDirEsc}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}metaDirPassed${FSTAB}${metaDirPassed}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noDirChecks${FSTAB}${noDirChecks}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noLastRun${FSTAB}${noLastRun}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noIdentCheck${FSTAB}${noIdentCheck}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noFindSource${FSTAB}${noFindSource}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noFindBackup${FSTAB}${noFindBackup}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noExec1Hdr${FSTAB}${noExec1Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noExec2Hdr${FSTAB}${noExec2Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noExec3Hdr${FSTAB}${noExec3Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noExec4Hdr${FSTAB}${noExec4Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noExec5Hdr${FSTAB}${noExec5Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR800Hdr${FSTAB}${noR800Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR810Hdr${FSTAB}${noR810Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR820Hdr${FSTAB}${noR820Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR830Hdr${FSTAB}${noR830Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR840Hdr${FSTAB}${noR840Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR850Hdr${FSTAB}${noR850Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noR860Hdr${FSTAB}${noR860Hdr}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}noProgress${FSTAB}${noProgress}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}color${FSTAB}${color}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}mawk${FSTAB}${mawk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}lTest${FSTAB}${lTest}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findLastRunOpsFinalAwk${FSTAB}${findLastRunOpsFinalAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findSourceOpsFinalAwk${FSTAB}${findSourceOpsFinalAwk}${FSTAB}${TRIPLET}
${TRIPLET}${FSTAB}findBackupOpsFinalAwk${FSTAB}${findBackupOpsFinalAwk}${FSTAB}${TRIPLET}
PARAMFILE

###########################################################
${awk} '{ print }' << 'AWKAWKPREPROC' > "${f100}"
BEGIN {
  eex = "BEGIN {\n"                                                         \
        "  error_exit_filename = \"\"\n"                                    \
        "}\n"                                                               \
        "function error_exit( msg ) {\n"                                    \
        "  if ( \"\" == error_exit_filename ) {\n"                          \
        "    if ( \"\" != FILENAME ) {\n"                                   \
        "      error_exit_filename = FILENAME\n"                            \
        "      sub( /^.*\\//, \"\", error_exit_filename )\n"                \
        "      msg = \"(\" error_exit_filename \" FNR:\" FNR \") \" msg\n"  \
        "    }\n"                                                           \
        "    gsub( CNTRLREGEX, TRIPLETC, msg )\n"                           \
        "    print \"\\nZaloha AWK: \" msg > \"/dev/stderr\"\n"             \
        "    close( \"/dev/stderr\" )\n"                                    \
        "    exit 1\n"                                                      \
        "  }\n"                                                             \
        "}"
  war = "function warning( msg ) {\n"                                       \
        "  if ( \"\" == error_exit_filename ) {\n"                          \
        "    gsub( CNTRLREGEX, TRIPLETC, msg )\n"                           \
        "    print \"\\nZaloha AWK: Warning: \" msg > \"/dev/stderr\"\n"    \
        "    close( \"/dev/stderr\" )\n"                                    \
        "  }\n"                                                             \
        "}"
  mpa = 8     # MAXPARALLEL constant
}
{
  gsub( /DEFINE_ERROR_EXIT/, eex )
  gsub( /DEFINE_WARNING/, war )
  gsub( /BIN_BASH/, "print \"#!/bin/bash\"" )
  gsub( /XTRACE_ON/, "print \"BASH_XTRACEFD=1; PS4='    '; set -x\"" )
  gsub( /XTRACE_OFF/, "print \"  { set +x; } > /dev/null\"" )
  gsub( /SECTION_LINE/, "print \"#\" FSTAB TRIPLET" )
  gsub( /TABREGEX/, "/\\t/" )
  gsub( /FSTAB/, "\"\\t\"" )
  gsub( /TAB/, "\"\\t\"" )
  gsub( /NLINE/, "\"\\n\"" )
  gsub( /BSLASH/, "\"BSLASH\\\"" )
  gsub( /BSLASH/, "\\" )
  gsub( /SLASHREGEX/, "/\\//" )
  gsub( /SLASH/, "\"/\"" )
  gsub( /DQUOTE/, "\"\\\"\"" )
  gsub( /TRIPLETTREGEX/, "/\\/\\/\\/t/" )
  gsub( /TRIPLETNREGEX/, "/\\/\\/\\/n/" )
  gsub( /TRIPLETBREGEX/, "/\\/\\/\\/b/" )
  gsub( /TRIPLETSREGEX/, "/\\/\\/\\/s/" )
  gsub( /TRIPLETDSEPLENGTH/, "5" )
  gsub( /TRIPLETDSEP/, "\"///d/\"" )
  gsub( /TRIPLETT/, "\"///t\"" )
  gsub( /TRIPLETN/, "\"///n\"" )
  gsub( /TRIPLETC/, "\"///c\"" )
  gsub( /TRIPLETS/, "\"///s\"" )
  gsub( /TRIPLET/, "\"///\"" )
  gsub( /QUOTEREGEX/, "/'/" )
  gsub( /QUOTEESC/, "\"'\\\"'\\\"'\"" )
  gsub( /NUMBERREGEX/, "/^[0123456789]+$/" )
  gsub( /ZEROREGEX/, "/^0+$/" )
  gsub( /CNTRLREGEX/, "/[[:cntrl:]]/" )
  gsub( /FATREGEX/, "/[Ff][Aa][Tt]/" )
  gsub( /TERMNORM/, "\"\\033[0m\"" )
  gsub( /TERMRED/, "\"\\033[91m\"" )
  gsub( /TERMBLUE/, "\"\\033[94m\"" )
  if ( $0 ~ /ONE_TO_MAXPARALLEL/ ) {
    for ( i = 1; i <= mpa; i++ ) {
      s = $0
      gsub( /ONE_TO_MAXPARALLEL/, i, s )
      gsub( /MAXPARALLEL/, mpa, s )
      print s
    }
  } else {
    gsub( /MAXPARALLEL/, mpa )
    print
  }
}
AWKAWKPREPROC

${awk} -f "${f100}" << 'AWKXTRACE2TERM' > "${f102}"
{
  if ( 1 == color ) {
    gsub( TABREGEX, TRIPLETT )
    gsub( CNTRLREGEX, TERMBLUE TRIPLETC TERMNORM )
    gsub( TRIPLETTREGEX, TERMBLUE TRIPLETT TERMNORM )
  } else {
    gsub( TABREGEX, TRIPLETT )
    gsub( CNTRLREGEX, TRIPLETC )
  }
  print
}
AWKXTRACE2TERM

${awk} -f "${f100}" << 'AWKACTIONS2TERM' > "${f104}"
BEGIN {
  FS = FSTAB
}
{
  pt = $13
  if ( 1 == color ) {
    gsub( CNTRLREGEX, TERMBLUE TRIPLETC TERMNORM, pt )
    gsub( TRIPLETNREGEX, TERMBLUE TRIPLETN TERMNORM, pt )
    gsub( TRIPLETTREGEX, TERMBLUE TRIPLETT TERMNORM, pt )
    if ( $2 ~ /^(REMOVE|UPDATE|unl\.UP|REV\.UP)/ ) {    # actions requiring more attention
      printf "%s%-10s%s%s\n", TERMRED, $2, TERMNORM, pt
    } else {
      printf "%-10s%s\n", $2, pt
    }
  } else {
    gsub( CNTRLREGEX, TRIPLETC, pt )
    printf "%-10s%s\n", $2, pt
  }
}
AWKACTIONS2TERM

###########################################################
${awk} -f "${f100}" << 'AWKPARSER' > "${f106}"
DEFINE_ERROR_EXIT
BEGIN {
  gsub( TRIPLETBREGEX, BSLASH, startPoint )
  gsub( TRIPLETBREGEX, BSLASH, findOps )
  gsub( TRIPLETBREGEX, BSLASH, tripletDSepV )
  gsub( TRIPLETBREGEX, BSLASH, outFile )
  gsub( QUOTEREGEX, QUOTEESC, startPoint )
  gsub( QUOTEREGEX, QUOTEESC, outFile )
  cmd = "find"                   # FIND command being constructed
  wrd = ""                       # word of FIND command being constructed
  iwd = 0                        # flag inside of word (0=before, 1=in, 2=after)
  idq = 0                        # flag inside of double-quote
  dqu = 0                        # flag double-quote remembered
  if ( 1 == followSLinks ) {
    cmd = cmd " -L"
  }
  cmd = cmd " '" startPoint "'"
  findOps = findOps " "
  for ( i = 1; i <= length( findOps ); i++ ) {
    c = substr( findOps, i, 1 )
    if ( 1 == dqu ) {
      dqu = 0
      if ( DQUOTE == c ) {
        wrd = wrd c
        continue
      } else {
        idq = 0
      }
    }
    if ( DQUOTE == c ) {
      if ( 1 == idq ) {
        dqu = 1
      } else {
        iwd = 1
        idq = 1
      }
    } else if ( " " == c ) {
      if ( 1 == idq ) {
        wrd = wrd c
      } else if ( 1 == iwd ) {
        iwd = 2
      }
    } else {
      wrd = wrd c
      iwd = 1
    }
    # word boundary found: post-process word and add it to command
    if ( 2 == iwd ) {
      j = index( wrd, TRIPLETDSEP )
      if ( 0 != j ) {
        wpp = ""              # word of FIND command post-processed
        if ( 1 < j ) {
          wpp = wpp substr( wrd, 1, j - 1 )
        }
        wpp = wpp tripletDSepV
        if ( j < length( wrd ) - TRIPLETDSEPLENGTH + 1 ) {
          wpp = wpp substr( wrd, j + TRIPLETDSEPLENGTH )
        }
        j = index( wpp, TRIPLETDSEP )
        if ( 0 != j ) {
          error_exit( "<findOps> contains more than one placeholder " TRIPLETDSEP " in one word" )
        }
      } else {
        wpp = wrd
      }
      gsub( QUOTEREGEX, QUOTEESC, wpp )
      cmd = cmd " '" wpp "'"
      wrd = ""
      iwd = 0
    }
  }
  if ( 1 == idq ) {
    error_exit( "<findOps> contains unpaired double quote" )
  }
  cmd = cmd " -printf '"
  cmd = cmd TRIPLET             # column  1: leading field
  cmd = cmd "\\t" sourceBackup  # column  2: S = <sourceDir>, B = <backupDir>, L = last run record
  cmd = cmd "\\t%y"             # column  3: file's type (d = directory, f = file, [h = hardlink], l = symbolic link, p/s/c/b/D = other)
  cmd = cmd "\\t%s"             # column  4: file's size in bytes
  cmd = cmd "\\t%Ts"            # column  5: file's last modification time, seconds since 01/01/1970
  cmd = cmd "\\t%F"             # column  6: type of the filesystem the file is on
  cmd = cmd "\\t%D"             # column  7: device number the file is on
  cmd = cmd "\\t%i"             # column  8: file's inode number
  cmd = cmd "\\t%n"             # column  9: number of hardlinks to file
  cmd = cmd "\\t%u"             # column 10: file's user name
  cmd = cmd "\\t%g"             # column 11: file's group name
  cmd = cmd "\\t%m"             # column 12: file's permission bits (in octal)
  cmd = cmd "\\t%P"             # column 13: file's path with <sourceDir> or <backupDir> stripped
  cmd = cmd "\\t" TRIPLET       # column 14: terminator field
  cmd = cmd "\\t%l"             # column 15: object of symbolic link
  cmd = cmd "\\t" TRIPLET       # column 16: terminator field
  cmd = cmd "\\n' > '" outFile "'"
  BIN_BASH
  print "set -e"
  if ( 0 == noProgress ) {
    XTRACE_ON
  }
  print cmd
}
AWKPARSER

if [ ${noProgress} -eq 0 ]; then
  echo
  echo "ANALYZING ${sourceDirTerm} AND ${backupDirTerm}"
  echo "==========================================="
fi

start_progress "Parsing"

${awk} -f "${f106}"                            \
       -v sourceBackup="L"                     \
       -v startPoint="${metaDirAwk}"           \
       -v followSLinks=0                       \
       -v findOps="${findLastRunOpsFinalAwk}"  \
       -v tripletDSepV="${metaDirPattAwk}"     \
       -v outFile="${f300Awk}"                 \
       -v noProgress=${noProgress}             > "${f200}"

${awk} -f "${f106}"                            \
       -v sourceBackup="S"                     \
       -v startPoint="${sourceDirAwk}"         \
       -v followSLinks=${followSLinksS}        \
       -v findOps="${findSourceOpsFinalAwk}"   \
       -v tripletDSepV="${sourceDirPattAwk}"   \
       -v outFile="${f310Awk}"                 \
       -v noProgress=${noProgress}             > "${f210}"

${awk} -f "${f106}"                            \
       -v sourceBackup="B"                     \
       -v startPoint="${backupDirAwk}"         \
       -v followSLinks=${followSLinksB}        \
       -v findOps="${findBackupOpsFinalAwk}"   \
       -v tripletDSepV="${backupDirPattAwk}"   \
       -v outFile="${f320Awk}"                 \
       -v noProgress=${noProgress}             > "${f220}"

stop_progress

if [ ${noLastRun} -eq 0 ]; then

  bash "${f200}" | ${awkNoBuf} -f "${f102}" -v color=${color}

  fLastRun="${f300}"

else

  file_not_prepared "${f300}"

  fLastRun="/dev/null"

fi

if [ ${noFindSource} -eq 0 ]; then

  bash "${f210}" | ${awkNoBuf} -f "${f102}" -v color=${color}

else

  if [ ! -f "${f310}" ]; then
    error_exit "The externally supplied CSV metadata file 310 does not exist"
  fi

  if [ ! "${f310}" -nt "${f999}" ]; then
    error_exit "The externally supplied CSV metadata file 310 is not newer than the last run of Zaloha"
  fi

fi

if [ ${noFindBackup} -eq 0 ]; then

  bash "${f220}" | ${awkNoBuf} -f "${f102}" -v color=${color}

else

  if [ ! -f "${f320}" ]; then
    error_exit "The externally supplied CSV metadata file 320 does not exist"
  fi

  if [ ! "${f320}" -nt "${f999}" ]; then
    error_exit "The externally supplied CSV metadata file 320 is not newer than the last run of Zaloha"
  fi

fi

###########################################################
${awk} -f "${f100}" << 'AWKCLEANER' > "${f110}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB   # FSTAB or TAB, because fields are separated both by tabs produced by FIND as well as by tabs contained in filenames
  OFS = FSTAB
  fin = 1      # field index in output record
  fpr = 0      # flag field in progress (for fin 13 or 15)
  fne = 0      # flag field not empty
  rec = ""     # output record
}
function add_fragment_to_field( fragment, verbatim ) {
  if ( "" != fragment ) {
    fne = 1
  }
  if (( 13 == fin ) && ( 0 == verbatim )) {             #  (in field 13, convert slashes to TRIPLETS's)
    gsub( SLASHREGEX, TRIPLETS, fragment )
  }
  rec = rec fragment
}
{
  if (( 1 == fin ) && ( 16 == NF ) && ( TRIPLET == $1 ) && ( TRIPLET == $16 )) {   #### the unproblematic case performance-optimized
    if ( "" != $13 ) {
      $13 = $13 SLASH                                   #  (if field 13 is not empty, append slash and convert slashes to TRIPLETS's)
      gsub( SLASHREGEX, TRIPLETS, $13 )
    }
    print
  } else {                                                                         #### full processing otherwise
    if ( 0 == NF ) {                                    ### blank input line
      if ( 1 == fpr ) {                                 ## blank input line while fin 13 or 15 in progress (= newline in file name)
        add_fragment_to_field( TRIPLETN, 1 )
      } else {                                          ## blank input line otherwise
        error_exit( "Unexpected blank line in raw output of FIND" )
      }
    } else {                                            ### non-blank input line
      if (( TRIPLET == $1 ) && (( 1 != fin ) || ( 0 != fpr ))) {
        error_exit( "AWK cleaner in unexpected state at begin of new record" )
      }
      for ( i = 1; i <= NF; i++ ) {
        if ( 1 == fpr ) {                               ## fin 13 or 15 in progress
          if ( TRIPLET == $i ) {                        # TRIPLET terminator found
            if (( 13 == fin ) && ( 1 == fne )) {        #  (append TRIPLETS to field 13 (if field 13 is not empty))
              add_fragment_to_field( TRIPLETS, 1 )
            }
            rec = rec FSTAB TRIPLET
            fin = fin + 2
            fpr = 0
            fne = 0
          } else if ( 1 == i ) {                        # fin 13 or 15 in progress continues on next line (= newline in file name)
            add_fragment_to_field( TRIPLETN, 1 )
            add_fragment_to_field( $i, 0 )
          } else {                                      # fin 13 or 15 in progress continues in next field (= tab in file name)
            add_fragment_to_field( TRIPLETT, 1 )
            add_fragment_to_field( $i, 0 )
          }
        } else {                                        ## normal case (= fin 13 or 15 not in progress)
          if ( 1 == fin ) {                             # field 1 starts a record
            add_fragment_to_field( $i, 0 )
            fin = 2
            fne = 0
          } else if (( 13 == fin ) || ( 15 == fin )) {  # fields 13 and 15 are terminator-delimited: start progress
            rec = rec FSTAB
            add_fragment_to_field( $i, 0 )
            fpr = 1
          } else {                                      # other fields are regular
            rec = rec FSTAB
            add_fragment_to_field( $i, 0 )
            fin = fin + 1
            fne = 0
          }
        }
      }
      if (( TRIPLET == $NF ) && (( 17 != fin ) || ( 0 != fpr ))) {
        error_exit( "AWK cleaner in unexpected state at end of record" )
      }
      if ( 17 < fin ) {
        error_exit( "AWK cleaner in unexpected state at end of input line" )
      }
    }
    if ( 17 == fin ) {                                  ### output record is complete (17 = index of last field + 1)
      print rec
      rec = ""
      fin = 1
    }
  }
}
END {
  if (( 1 != fin ) || ( 0 != fpr )) {
    error_exit( "AWK cleaner in unexpected state at end of file" )
  }
}
AWKCLEANER

start_progress "Cleaning"

${awk} -f "${f110}" "${f310}" > "${f330}"

optim_csv_after_use "${f310}"

${awk} -f "${f110}" "${f320}" > "${f340}"

optim_csv_after_use "${f320}"

stop_progress

###########################################################
${awk} -f "${f100}" << 'AWKCHECKER' > "${f130}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  ldp = 0    # 3x directory depth of last record
  ltp = ""   # file's type of last record
}
{
  if ( 16 != NF ) {
    error_exit( "Unexpected, cleaned CSV file does not contain 16 columns" )
  }
  if ( $1 != TRIPLET ) {
    error_exit( "Unexpected, column 1 of cleaned file is not leading field" )
  }
  if ( $2 !~ /[LSB]/ ) {
    error_exit( "Unexpected, column 2 of cleaned file contains invalid value" )
  }
  if ( $3 !~ /[dflpscbD]/ ) {
    error_exit( "Unexpected, column 3 of cleaned file contains invalid value" )
  }
  if ( $4 !~ /^[0123456789]+(;.*)?$/ ) {
    error_exit( "Unexpected, column 4 (till eventual ;) of cleaned file is not numeric" )
  }
  if ( $5 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 5 of cleaned file is not numeric" )
  }
  if (( $5 ~ ZEROREGEX ) && ( "f" == $3 )) {
    error_exit( "Unexpected, column 5 of cleaned file is zero for a file" )
  }
  if ( $7 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 7 of cleaned file is not numeric" )
  }
  if ( $8 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 8 of cleaned file is not numeric" )
  }
  if ( $9 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 9 of cleaned file is not numeric" )
  }
  if ( $9 ~ ZEROREGEX ) {
    error_exit( "Unexpected, column 9 of cleaned file is zero" )
  }
  if ( $10 == "" ) {
    error_exit( "Unexpected, column 10 of cleaned file is empty" )
  }
  if ( $11 == "" ) {
    error_exit( "Unexpected, column 11 of cleaned file is empty" )
  }
  if ( $12 !~ NUMBERREGEX ) {
    error_exit( "Unexpected, column 12 of cleaned file is not numeric" )
  }
  if (( $13 == "" ) && ( 1 != FNR )) {
    error_exit( "Unexpected, column 13 of cleaned file is empty" )
  }
  if ( $14 != TRIPLET ) {
    error_exit( "Unexpected, column 14 of cleaned file is not terminator field" )
  }
  if (( $15 == "" ) && ( "l" == $3 )) {
    error_exit( "Unexpected, column 15 of cleaned file is empty for symbolic link" )
  }
  if (( $15 != "" ) && ( "l" != $3 )) {
    error_exit( "Unexpected, column 15 of cleaned file is not empty" )
  }
  if ( $16 != TRIPLET ) {
    error_exit( "Unexpected, column 16 of cleaned file is not terminator field" )
  }
  pt = $13
  gsub( TRIPLETSREGEX, SLASH, pt )
  cdp = length( $13 ) - length( pt )  # 3x directory depth of current record
  if ( cdp > ldp + 3 ) {
    pt = substr( pt, 1, length( pt ) - 1 )
    error_exit( "Unexpected: directory level(s) skipped before: " pt )
  } else if (( cdp > ldp ) && ( "d" != ltp )) {
    pt = substr( pt, 1, length( pt ) - 1 )
    error_exit( "Unexpected: Parent of this object is not a directory: " pt )
  }
  ldp = cdp
  ltp = $3
}
AWKCHECKER

start_progress "Checking"

${awk} -f "${f130}" "${fLastRun}" "${f330}" "${f340}"

stop_progress

###########################################################
${awk} -f "${f100}" << 'AWKHLINKS' > "${f150}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  tp = ""
}
{
  # hardlink detection only for files
  # device and inode numbers prepended by "M" to enforce string comparisons (numbers would overflow)
  if ( ( "f" == tp ) && ( "f" == $3 )                     \
    && ( $7 !~ ZEROREGEX ) && (( "M" dv ) == ( "M" $7 ))  \
    && ( $8 !~ ZEROREGEX ) && (( "M" id ) == ( "M" $8 ))  \
  ) {
    hcn = hcn + 1
    if ( $9 < hcn ) {
      error_exit( "Unexpected, detected hardlink count is higher than number of hardlinks to file" )
    }
    if (( "M" sz ) != ( "M" $4 )) {
      error_exit( "Unexpected falsely detected hardlink (size differs)" )
    }
    if (( "M" tm ) != ( "M" $5 )) {
      error_exit( "Unexpected falsely detected hardlink (modification time differs)" )
    }
    if ( nh != $9 ) {
      error_exit( "Unexpected falsely detected hardlink (number of hardlinks differs)" )
    }
    if ( us != $10 ) {
      error_exit( "Unexpected falsely detected hardlink (user name differs)" )
    }
    if ( gr != $11 ) {
      error_exit( "Unexpected falsely detected hardlink (group name differs)" )
    }
    if ( md != $12 ) {
      error_exit( "Unexpected falsely detected hardlink (mode differs)" )
    }
    $3 = "h"    # hardlink
    $15 = pt    # object of hardlink
    if ( "" != $15 ) {
      gsub( TRIPLETSREGEX, SLASH, $15 )
      $15 = substr( $15, 1, length( $15 ) - 1 )
    }
  } else {
    hcn = 1     # detected hardlink count
    tp = $3     # previous record's column  3: file's type (d = directory, f = file, [h = hardlink], l = symbolic link, p/s/c/b/D = other)
    sz = $4     # previous record's column  4: file's size in bytes
    tm = $5     # previous record's column  5: file's last modification time, seconds since 01/01/1970
    dv = $7     # previous record's column  7: device number the file is on
    id = $8     # previous record's column  8: file's inode number
    nh = $9     # previous record's column  9: number of hardlinks to file
    us = $10    # previous record's column 10: file's user name
    gr = $11    # previous record's column 11: file's group name
    md = $12    # previous record's column 12: file's permission bits (in octal)
    pt = $13    # previous record's column 13: file's path with <sourceDir> or <backupDir> stripped
  }
  print
}
AWKHLINKS

if [ ${hLinks} -eq 1 ]; then

  start_progress "Sorting (1)"

  LC_ALL=C sort -t "${FSTAB}" -k7,7 -k8,8 -k13,13 "${f330}" > "${f350}"

  optim_csv_after_use "${f330}"

  stop_progress

  start_progress "Hardlinks detecting"

  ${awk} -f "${f150}" "${f350}" > "${f360}"

  optim_csv_after_use "${f350}"

  stop_progress

  fAfterHLinks="${f360}"

else

  fAfterHLinks="${f330}"

  file_not_prepared "${f350}"
  file_not_prepared "${f360}"

fi

###########################################################
${awk} -f "${f100}" << 'AWKDIFF' > "${f170}"
DEFINE_ERROR_EXIT
DEFINE_WARNING
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  lru = 0     # time of the last run of Zaloha
  xkp = ""    # occupied namespace: not possible to KEEP objects only in <backupDir>
  prr = 0     # flag previous record remembered (= unprocessed)
  slc = 0     # count of symbolic links in <sourceDir>
  idc = 0     # count of identical object(s) (inodes) in <sourceDir> and <backupDir>
  idp = ""    # path of first identical object (inode) in <sourceDir> and <backupDir>
  if ( 1 == ok3600s ) {
    tof = 3600     # tolerated offset +/- 3600 seconds
  } else {
    tof = 0
  }
  sb = ""
}
function get_tolerance() {
  if (( ft ~ FATREGEX ) || ( $6 ~ FATREGEX ) || ( 1 == ok2s )) {
    tol = 2        # additional tolerance +/- 2 seconds due to FAT rounding to nearest 2 seconds
  } else {
    tol = 0
  }
}
function print_previous( acode ) {
  print TRIPLET, acode, tp, sz, tm, ft, dv, id,    ";" nh, us, gr, md, pt, TRIPLET, ol, TRIPLET
}
function print_prev_curr( acode ) {
  print TRIPLET, acode, tp, sz, tm, ft, dv, id, $9 ";" nh, us, gr, md, pt, TRIPLET, ol, TRIPLET
}
function print_current( acode ) {
  print TRIPLET, acode, $3, $4, $5, $6, $7, $8, $9 ";"   , $10, $11, $12, $13, TRIPLET, $15, TRIPLET
}
function print_curr_prev( acode ) {
  print TRIPLET, acode, $3, $4, $5, $6, $7, $8, $9 ";" nh, $10, $11, $12, $13, TRIPLET, $15, TRIPLET
}
function remove( unavoidable ) {
  if ( "d" == tp ) {
    print_previous( unavoidable "RMDIR" )
  } else if ( "f" == tp ) {
    if (( 0 != lru ) && ( lru < tm )) {
      print_previous( unavoidable "REMOVE.!" )
    } else {
      print_previous( unavoidable "REMOVE" )
    }
  } else {
    print_previous( unavoidable "REMOVE." tp )
  }
}
function keep_or_remove( no_remove ) {
  if ( 1 == no_remove ) {
    print_previous( "KEEP" )
  } else {
    remove( "" )
  }
}
function try_to_keep_or_remove( no_remove ) {
  if ( "" == xkp ) {
    keep_or_remove( no_remove )
  } else if ( 1 == index( pt, xkp )) {
    remove( "u" )                              #  (unavoidable removal)
  } else {
    keep_or_remove( no_remove )
    xkp = ""
  }
}
function update_file() {
  if (( 0 == noUnlink ) && ( 1 != nh )) {
    bac = "unl.UP"
  } else {
    bac = "UPDATE"
  }
  if (( 0 != lru ) && ( lru < tm )) {
    print_curr_prev( bac ".!" )
  } else {
    if ( tdi <= tof + tol ) {
      print_curr_prev( bac ".?" )
    } else {
      print_curr_prev( bac )
    }
  }
}
function rev_up_file() {
  if (( 0 != lru ) && ( lru < tof + $5 )) {
    print_prev_curr( "REV.UP.!" )
  } else {
    print_prev_curr( "REV.UP" )
  }
}
function attributes_or_ok() {
  atr = ""
  if (( 1 == pUser ) && ( $10 != us )) {
    atr = atr "u"
  }
  if (( 1 == pGroup ) && ( $11 != gr )) {
    atr = atr "g"
  }
  if (( 1 == pMode ) && ( $12 != md )) {
    atr = atr "m"
  }
  if ( "" != atr ) {
    print_curr_prev( "ATTR:" atr )
  } else {
    print_curr_prev( "OK" )
  }
}
function process_previous_record() {
  if ( "S" == sb ) {
    if ( "d" == tp ) {                         # directory only in <sourceDir> (case 21)
      print_previous( "MKDIR" )
    } else if ( "f" == tp ) {                  # file only in <sourceDir> (case 22)
      print_previous( "NEW" )
    } else if ( "l" == tp ) {                  # symbolic link only in <sourceDir> (case 24)
      print_previous( "OK" )                   #  (OK record needed for the restore scripts)
      slc = slc + 1
    } else {                                   # hardlink or other object only in <sourceDir> (cases 23,25)
      print_previous( "OK" )                   #  (OK record needed for the restore scripts)
    }
  } else {
    if ( "d" == tp ) {                         # directory only in <backupDir> (case 26)
      try_to_keep_or_remove( noRemove )
    } else if ( "f" == tp ) {                  # file only in <backupDir> (case 27)
      if (( 1 == revNew ) && ( 0 != lru ) && ( lru < tm )) {
        if ( "" == xkp ) {
          print_previous( "REV.NEW" )
        } else if ( 1 == index( pt, xkp )) {
          remove( "u" )                        #  (unavoidable removal)
        } else {
          print_previous( "REV.NEW" )
          xkp = ""
        }
      } else {
        try_to_keep_or_remove( noRemove )
      }
    } else if ( "l" == tp ) {                  # symbolic link only in <backupDir> (case 28)
      try_to_keep_or_remove( noRemove )
    } else {                                   # other object only in <backupDir> (case 29)
      try_to_keep_or_remove( 1 )
    }
  }
}
{
  if (( sb == $2 ) && ( pt == $13 )) {
    error_exit( "Unexpected, duplicate record" )
  }
  if ( "L" == $2 ) {
    if ( 1 != NR ) {
      error_exit( "Unexpected, misplaced L record" )
    }
    if ( "f" != $3 ) {
      error_exit( "Unexpected, L record is not a file" )
    }
    lru = $5
  } else {
    if ( 1 == prr ) {
      if ( pt == $13 ) {                       ### same path in <sourceDir> and <backupDir>
        if (( 0 == noIdentCheck )                              \
         && ( $7 !~ ZEROREGEX ) && (( "M" dv ) == ( "M" $7 ))  \
         && ( $8 !~ ZEROREGEX ) && (( "M" id ) == ( "M" $8 ))) {
           if ( 0 == idc ) {
             idp = pt
           }
           idc = idc + 1
        }
        if ( "d" == $3 ) {                     ## directory in <sourceDir>
          if ( "d" == tp ) {                   # directory in <sourceDir>, directory in <backupDir> (case 1)
            attributes_or_ok()
          } else {                             # directory in <sourceDir>, file, symbolic link or other object in <backupDir> (cases 2,3,4)
            remove( "u" )                      #  (unavoidable removal)
            print_current( "MKDIR" )
          }
        } else if ( "f" == $3 ) {              ## file in <sourceDir>
          if ( "d" == tp ) {                   # file in <sourceDir>, directory in <backupDir> (case 5)
            xkp = pt                           #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
            remove( "u" )                      #  (unavoidable removal)
            print_current( "NEW" )
          } else if ( "f" == tp ) {            # file in <sourceDir>, file in <backupDir> (case 6)
            oka = 0
            if ( "M" $4 == "M" sz ) {
              if ( "M" $5 == "M" tm ) {
                oka = 1
              } else {
                tdi = $5 - tm                  #  (time difference <sourceDir> file minus <backupDir> file)
                tda = tdi                      #  (time difference absolute value)
                if ( tda < 0 ) {
                  tda = - tda
                }
                if ( 0 == tda ) {
                  error_exit( "Unexpected, numeric overflow occurred" )
                }
                get_tolerance()
                if ( tda <= tol ) {
                  oka = 1
                } else if (( 0 != tof ) && ( tof - tol <= tda ) && ( tda <= tof + tol )) {
                  oka = 1
                }
              }
            } else {
              tdi = $5 - tm
              get_tolerance()
            }
            if ( 1 == oka ) {
              attributes_or_ok()
            } else {
              if ( 1 == revUp ) {
                if ( tdi < - tof - tol ) {
                  rev_up_file()
                } else {
                  update_file()
                }
              } else {
                update_file()
              }
            }
          } else {                             # file in <sourceDir>, symbolic link or other object in <backupDir> (cases 7,8)
            remove( "u" )                      #  (unavoidable removal)
            print_current( "NEW" )
          }
        } else if ( "h" == $3 ) {              ## hardlink in <sourceDir> (cases 9,10,11,12)
          xkp = pt                             #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
          remove( "u" )                        #  (unavoidable removal, see Corner Cases section)
          print_current( "OK" )                #  (OK record needed for the restore scripts)
        } else if ( "l" == $3 ) {              ## symbolic link in <sourceDir>
          if ( "l" == tp ) {                   # symbolic link in <sourceDir>, symbolic link in <backupDir> (case 15)
            print_previous( "KEEP" )           #  ( keep the symbolic link in <backupDir>, but do not change it)
          } else {                             # symbolic link in <sourceDir>, directory, file or other object in <backupDir> (cases 13,14,16)
            xkp = pt                           #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
            remove( "u" )                      #  (unavoidable removal, see Corner Cases section)
          }
          print_current( "OK" )                #  (OK record needed for the restore scripts)
          slc = slc + 1
        } else {                               ## other object in <sourceDir>
          if ( tp ~ /[dfl]/ ) {                # other object in <sourceDir>, directory, file or symbolic link in <backupDir> (cases 17,18,19)
            xkp = pt                           #  (not possible to KEEP objects only in <backupDir> down from here due to occupied namespace)
            remove( "u" )                      #  (unavoidable removal, see Corner Cases section)
          } else {                             # other object in <sourceDir>, other object in <backupDir> (case 20)
            print_previous( "KEEP" )           #  ( keep the other object in <backupDir>, but do not change it)
          }
          print_current( "OK" )                #  (OK record for keeping in metadata)
        }
        prr = 0
      } else {                                 ### different path in <sourceDir> and <backupDir>
        process_previous_record()
        prr = 1
      }
    } else {
      prr = 1
    }
  }
  sb = $2     # previous record's column  2: S = <sourceDir>, B = <backupDir>, L = last run record
  tp = $3     # previous record's column  3: file's type (d = directory, f = file, [h = hardlink], l = symbolic link, p/s/c/b/D = other)
  sz = $4     # previous record's column  4: file's size in bytes
  tm = $5     # previous record's column  5: file's last modification time, seconds since 01/01/1970
  ft = $6     # previous record's column  6: type of the filesystem the file is on
  dv = $7     # previous record's column  7: device number the file is on
  id = $8     # previous record's column  8: file's inode number
  nh = $9     # previous record's column  9: number of hardlinks to file
  us = $10    # previous record's column 10: file's user name
  gr = $11    # previous record's column 11: file's group name
  md = $12    # previous record's column 12: file's permission bits (in octal)
  pt = $13    # previous record's column 13: file's path with <sourceDir> or <backupDir> stripped
  ol = $15    # previous record's column 15: object of symbolic link
}
END {
  if ( 1 == prr ) {
    process_previous_record()
  }
  if (( 0 == noWarnSLinks ) && ( 0 != slc )) {
    if ( 1 == followSLinksS ) {
      warning( slc " broken symbolic link(s) in <sourceDir>" )
    } else {
      warning( slc " symbolic link(s) in <sourceDir> that are neither followed nor synchronized to <backupDir>" )
    }
  }
  if ( 0 != idc ) {
    if ( "" == idp ) {
      warning( idc " identical object(s) (inodes) in <sourceDir> and <backupDir>, first are <sourceDir> and <backupDir> themselves" )
    } else {
      gsub( TRIPLETSREGEX, SLASH, idp )
      idp = substr( idp, 1, length( idp ) - 1 )
      warning( idc " identical object(s) (inodes) in <sourceDir> and <backupDir>, path of first case: " idp )
    }
  }
  if (( 0 == noLastRun ) && ( 0 == lru )) {
    warning( "No last run of Zaloha found (this is OK if this is the first run)" )
  }
}
AWKDIFF

start_progress "Sorting (2)"

LC_ALL=C sort -t "${FSTAB}" -k13,13 -k2,2 "${fAfterHLinks}" "${f340}" > "${f370}"

optim_csv_after_use "${fAfterHLinks}"

optim_csv_after_use "${f340}"

stop_progress

start_progress "Differences processing"

${awk} -f "${f170}"                       \
       -v noRemove=${noRemove}            \
       -v revNew=${revNew}                \
       -v revUp=${revUp}                  \
       -v ok2s=${ok2s}                    \
       -v ok3600s=${ok3600s}              \
       -v noUnlink=${noUnlink}            \
       -v pUser=${pUser}                  \
       -v pGroup=${pGroup}                \
       -v pMode=${pMode}                  \
       -v followSLinksS=${followSLinksS}  \
       -v noWarnSLinks=${noWarnSLinks}    \
       -v noLastRun=${noLastRun}          \
       -v noIdentCheck=${noIdentCheck}    \
       "${fLastRun}" "${f370}"            > "${f380}"

optim_csv_after_use "${f370}"

stop_progress

###########################################################
${awk} -f "${f100}" << 'AWKPOSTPROC' > "${f190}"
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  gsub( TRIPLETBREGEX, BSLASH, f510 )
  gsub( TRIPLETBREGEX, BSLASH, f540 )
  printf "" > f510
  if ( 0 == noRemove ) {
    printf "" > f540
  }
  lrn = ""    # path of last file to REV.NEW
  lkp = ""    # path of last object to KEEP only in <backupDir>
}
{
  if ( $2 ~ /^REV\.NEW/ ) {
    lrn = $13                # remember path of last file to REV.NEW
  } else if ( $2 ~ /^KEEP/ ) {
    if (( "d" == $3 ) && ( 1 == index( lrn, $13 ))) {
      $2 = "REV.MKDI"        # convert KEEP to REV.MKDI on parent directory of a file to REV.NEW
    } else {
      lkp = $13              # remember path of last object to KEEP only in <backupDir>
    }
  } else if ( $2 ~ /^RMDIR/ ) {
    if ( 1 == index( lrn, $13 )) {
      $2 = "REV.MKDI"        # convert RMDIR to REV.MKDI on parent directory of a file to REV.NEW
    } else if ( 1 == index( lkp, $13 )) {
      $2 = "KEEP"            # convert RMDIR to KEEP on parent directory of an object to KEEP only in <backupDir>
    }
  } else if ( "d" == $3 ) {  # encountered a directory with neither KEEP nor RMDIR: safe to forget lrn and lkp
    lrn = ""
    lkp = ""
  }
  # modifications done, split off 510 and 540 data, output remaining data
  if ( $2 ~ /^(uRMDIR|uREMOVE)/ ) {
    $2 = substr( $2, 2 )
    if ( "" != $13 ) {
      gsub( TRIPLETSREGEX, SLASH, $13 )
      $13 = substr( $13, 1, length( $13 ) - 1 )
    }
    print > f510
  } else if ( $2 ~ /^(RMDIR|REMOVE)/ ) {
    if ( "" != $13 ) {
      gsub( TRIPLETSREGEX, SLASH, $13 )
      $13 = substr( $13, 1, length( $13 ) - 1 )
    }
    print > f540
  } else {
    print
  }
}
END {
  if ( 0 == noRemove ) {
    close( f540 )
  }
  close( f510 )
}
AWKPOSTPROC

start_progress "Sorting (3)"

LC_ALL=C sort -t "${FSTAB}" -k13r,13 -k2,2 "${f380}" > "${f390}"

optim_csv_after_use "${f380}"

stop_progress

if [ ${noRemove} -eq 0 ]; then

  start_progress "Post-processing and splitting off Exec1 and Exec4"

else

  start_progress "Post-processing and splitting off Exec1"

  file_not_prepared "${f540}"

fi

${awk} -f "${f190}"             \
       -v f510="${f510Awk}"     \
       -v f540="${f540Awk}"     \
       -v noRemove=${noRemove}  \
       "${f390}"                > "${f500}"

optim_csv_after_use "${f390}"

stop_progress

###########################################################
${awk} -f "${f100}" << 'AWKSELECT23' > "${f405}"
BEGIN {
  FS = FSTAB
  OFS = FSTAB
  gsub( TRIPLETBREGEX, BSLASH, f520 )
  gsub( TRIPLETBREGEX, BSLASH, f530 )
  printf "" > f520
  if (( 1 == revNew ) || ( 1 == revUp )) {
    printf "" > f530
  }
}
{
  if ( "" != $13 ) {
    gsub( TRIPLETSREGEX, SLASH, $13 )
    $13 = substr( $13, 1, length( $13 ) - 1 )
  }
  if ( $2 ~ /^(MKDIR|NEW|UPDATE|unl\.UP|ATTR)/ ) {
    print > f520
  } else if ( $2 ~ /^(REV\.MKDI|REV\.NEW|REV\.UP)/ ) {
    print > f530
  }
  print
}
END {
  if (( 1 == revNew ) || ( 1 == revUp )) {
    close( f530 )
  }
  close( f520 )
}
AWKSELECT23

if [ ${revNew} -eq 1 ] || [ ${revUp} -eq 1 ]; then

  start_progress "Sorting (4) and selecting Exec2 and Exec3"

else

  start_progress "Sorting (4) and selecting Exec2"

  file_not_prepared "${f530}"

fi

LC_ALL=C sort -t "${FSTAB}" -k13,13 -k2,2 "${f500}" | ${awk} -f "${f405}"  \
    -v f520="${f520Awk}"  \
    -v f530="${f530Awk}"  \
    -v revNew=${revNew}   \
    -v revUp=${revUp}     > "${f505}"

optim_csv_after_use "${f500}"

stop_progress

###########################################################

if [ ${byteByByte} -eq 1 ]; then

  start_progress_by_chars "Byte by byte comparing files that appear identical"

  exec {fd550}> "${f550}"
  exec {fd555}> "${f555}"

  while IFS="${FSTAB}" read -r -a tmpRec   # split record to array (hint: first field has index 0)
  do
    if [ "${tmpRec[2]}" == "f" ]; then
      if [ "${tmpRec[1]}" == "OK" ] || [ "${tmpRec[1]:0:4}" == "ATTR" ]; then

        tmpVal="${tmpRec[12]}"    # file's path with <sourceDir> or <backupDir> stripped
        tmpVal="${tmpVal//${TRIPLETN}/${NLINE}}"
        tmpVal="${tmpVal//${TRIPLETT}/${TAB}}"

        cmp -s "${sourceDir}${tmpVal}" "${backupDir}${tmpVal}" && tmpVal=$? || tmpVal=$?

        if [ ${tmpVal} -eq 0 ]; then
          tmpRec[1]="OK.b"
          progress_char "."

        elif [ ${tmpVal} -eq 1 ]; then

          tmpVal="${tmpRec[8]}"   # number of hardlinks <sourceDir> ; number of hardlinks <backupDir>

          if [ ${noUnlink} -eq 0 ] && [ ${tmpVal#*;} -ne 1 ]; then
            tmpRec[1]="unl.UP.b"
          else
            tmpRec[1]="UPDATE.b"
          fi
          IFS="${FSTAB}" echo_args_with_ifs "${tmpRec[@]}" >&${fd550}
          progress_char "#"

        else
          error_exit "command CMP failed while comparing files byte by byte"
        fi

        IFS="${FSTAB}" echo_args_with_ifs "${tmpRec[@]}" >&${fd555}
      fi
    fi
  done < "${f505}"

  exec {fd555}>&-
  exec {fd550}>&-

  stop_progress

else

  file_not_prepared "${f550}"
  file_not_prepared "${f555}"

fi

###########################################################
${awk} -f "${f100}" << 'AWKEXEC1' > "${f410}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  if ( 0 == noExecHdr ) {
    BIN_BASH
    print "backupDir='" backupDir "'"
    print "RMDIR='rmdir'"
    print "RM" ONE_TO_MAXPARALLEL "='rm -f'"
    print "set -u"
    if ( 0 == noExec ) {
      print "set -e"
      XTRACE_ON
    }
  }
  SECTION_LINE
}
{
  pt = $13
  gsub( QUOTEREGEX, QUOTEESC, pt )
  gsub( TRIPLETNREGEX, NLINE, pt )
  gsub( TRIPLETTREGEX, TAB, pt )
  b = "\"${backupDir}\"'" pt "'"
  if ( $2 ~ /^RMDIR/ ) {
    print "${RMDIR} " b
  } else if ( $2 ~ /^REMOVE/ ) {
    print "${RM" pin "} " b
    if ( MAXPARALLEL <= pin ) {
      pin = 1
    } else {
      pin = pin + 1
    }
  } else {
    error_exit( "Unexpected action code" )
  }
}
END {
  SECTION_LINE
}
AWKEXEC1

start_progress "Preparing shellscript for Exec1"

${awk} -f "${f410}"                    \
       -v backupDir="${backupDirAwk}"  \
       -v noExec=${noExec}             \
       -v noExecHdr=${noExec1Hdr}      \
       "${f510}"                       > "${f610}"

stop_progress

###########################################################
${awk} -f "${f100}" << 'AWKEXEC2' > "${f420}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, sourceDir )
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, sourceDir )
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  if ( 0 == noExecHdr ) {
    BIN_BASH
    print "sourceDir='" sourceDir "'"
    print "backupDir='" backupDir "'"
    print "MKDIR='mkdir'"
    if ( 1 == touch ) {
      print "CP" ONE_TO_MAXPARALLEL "='cp'"
      print "TOUCH" ONE_TO_MAXPARALLEL "='touch -r'"
    } else {
      print "CP" ONE_TO_MAXPARALLEL "='cp --preserve=timestamps'"
    }
    if ( 0 == noUnlink ) {
      print "UNLINK" ONE_TO_MAXPARALLEL "='rm -f'"
    }
    if ( 1 == pUser ) {
      print "CHOWN_DIR='chown'"
      print "CHOWN" ONE_TO_MAXPARALLEL "='chown'"
    }
    if ( 1 == pGroup ) {
      print "CHGRP_DIR='chgrp'"
      print "CHGRP" ONE_TO_MAXPARALLEL "='chgrp'"
    }
    if ( 1 == pMode ) {
      print "CHMOD_DIR='chmod'"
      print "CHMOD" ONE_TO_MAXPARALLEL "='chmod'"
    }
    print "set -u"
    if ( 0 == noExec ) {
      print "set -e"
      XTRACE_ON
    }
  }
  SECTION_LINE
}
function apply_attr_dir() {
  if ( 1 == pUser ) {
    print "${CHOWN_DIR} " u " " b
  }
  if ( 1 == pGroup ) {
    print "${CHGRP_DIR} " g " " b
  }
  if ( 1 == pMode ) {
    print "${CHMOD_DIR} " m " " b
  }
}
function copy_file() {
  print "${CP" pin "} " s " " b
  if ( 1 == touch ) {
    print "${TOUCH" pin "} " s " " b
  }
}
function apply_attr() {
  if ( 1 == pUser ) {
    print "${CHOWN" pin "} " u " " b
  }
  if ( 1 == pGroup ) {
    print "${CHGRP" pin "} " g " " b
  }
  if ( 1 == pMode ) {
    print "${CHMOD" pin "} " m " " b
  }
}
function next_pin() {
  if ( MAXPARALLEL <= pin ) {
    pin = 1
  } else {
    pin = pin + 1
  }
}
{
  us = $10
  gr = $11
  md = $12
  pt = $13
  gsub( QUOTEREGEX, QUOTEESC, us )
  gsub( QUOTEREGEX, QUOTEESC, gr )
  gsub( QUOTEREGEX, QUOTEESC, pt )
  gsub( TRIPLETNREGEX, NLINE, pt )
  gsub( TRIPLETTREGEX, TAB, pt )
  u = "'" us "'"
  g = "'" gr "'"
  m = "'" md "'"
  s = "\"${sourceDir}\"'" pt "'"
  b = "\"${backupDir}\"'" pt "'"
  if ( $2 ~ /^MKDIR/ ) {
    print "${MKDIR} " b
    apply_attr_dir()
  } else if ( $2 ~ /^NEW/ ) {
    copy_file()
    apply_attr()
    next_pin()
  } else if ( $2 ~ /^UPDATE/ ) {
    copy_file()
    apply_attr()
    next_pin()
  } else if ( $2 ~ /^unl\.UP/ ) {
    print "${UNLINK" pin "} " b
    copy_file()
    apply_attr()
    next_pin()
  } else if ( $2 ~ /^ATTR/ ) {
    if ( $2 ~ /u/ ) {
      print "${CHOWN" pin "} " u " " b
    }
    if ( $2 ~ /g/ ) {
      print "${CHGRP" pin "} " g " " b
    }
    if ( $2 ~ /m/ ) {
      print "${CHMOD" pin "} " m " " b
    }
    next_pin()
  } else {
    error_exit( "Unexpected action code" )
  }
}
END {
  SECTION_LINE
}
AWKEXEC2

start_progress "Preparing shellscript for Exec2"

${awk} -f "${f420}"                    \
       -v sourceDir="${sourceDirAwk}"  \
       -v backupDir="${backupDirAwk}"  \
       -v noExec=${noExec}             \
       -v noUnlink=${noUnlink}         \
       -v touch=${touch}               \
       -v pUser=${pUser}               \
       -v pGroup=${pGroup}             \
       -v pMode=${pMode}               \
       -v noExecHdr=${noExec2Hdr}      \
       "${f520}"                       > "${f620}"

stop_progress

###########################################################
${awk} -f "${f100}" << 'AWKEXEC3' > "${f430}"
DEFINE_ERROR_EXIT
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, sourceDir )
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, sourceDir )
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  if ( 0 == noExecHdr ) {
    BIN_BASH
    print "sourceDir='" sourceDir "'"
    print "backupDir='" backupDir "'"
    print "function rev_exists_err {"
    XTRACE_OFF
    print "  echo \"Zaloha: Object exists in <sourceDir> (masked by <findSourceOps> ?): ${1}\" >&2"
    if ( 0 == noExec ) {
      print "  exit 1"
    }
    print "}"
    print "TEST_DIR='['"
    print "REV_EXISTS_ERR_DIR='rev_exists_err'"
    print "MKDIR='mkdir'"
    print "TEST" ONE_TO_MAXPARALLEL "='['"
    print "REV_EXISTS_ERR" ONE_TO_MAXPARALLEL "='rev_exists_err'"
    if ( 1 == touch ) {
      print "CP" ONE_TO_MAXPARALLEL "='cp'"
      print "TOUCH" ONE_TO_MAXPARALLEL "='touch -r'"
    } else {
      print "CP" ONE_TO_MAXPARALLEL "='cp --preserve=timestamps'"
    }
    if ( 1 == pRevUser ) {
      print "CHOWN_DIR='chown'"
      print "CHOWN" ONE_TO_MAXPARALLEL "='chown'"
    }
    if ( 1 == pRevGroup ) {
      print "CHGRP_DIR='chgrp'"
      print "CHGRP" ONE_TO_MAXPARALLEL "='chgrp'"
    }
    if ( 1 == pRevMode ) {
      print "CHMOD_DIR='chmod'"
      print "CHMOD" ONE_TO_MAXPARALLEL "='chmod'"
    }
    print "set -u"
    if ( 0 == noExec ) {
      print "set -e"
      XTRACE_ON
    }
  }
  SECTION_LINE
}
function rev_check_nonex_dir() {
  print "${TEST_DIR} ! -e " s " ] || ${REV_EXISTS_ERR_DIR} '" ptt "'"
}
function rev_apply_attr_dir() {
  if ( 1 == pRevUser ) {
    print "${CHOWN_DIR} " u " " s
  }
  if ( 1 == pRevGroup ) {
    print "${CHGRP_DIR} " g " " s
  }
  if ( 1 == pRevMode ) {
    print "${CHMOD_DIR} " m " " s
  }
}
function rev_check_nonex() {
  print "${TEST" pin "} ! -e " s " ] || ${REV_EXISTS_ERR" pin "} '" ptt "'"
}
function rev_copy_file() {
  print "${CP" pin "} " b " " s
  if ( 1 == touch ) {
    print "${TOUCH" pin "} " b " " s
  }
}
function rev_apply_attr() {
  if ( 1 == pRevUser ) {
    print "${CHOWN" pin "} " u " " s
  }
  if ( 1 == pRevGroup ) {
    print "${CHGRP" pin "} " g " " s
  }
  if ( 1 == pRevMode ) {
    print "${CHMOD" pin "} " m " " s
  }
}
function next_pin() {
  if ( MAXPARALLEL <= pin ) {
    pin = 1
  } else {
    pin = pin + 1
  }
}
{
  us = $10
  gr = $11
  md = $12
  pt = $13
  gsub( QUOTEREGEX, QUOTEESC, us )
  gsub( QUOTEREGEX, QUOTEESC, gr )
  gsub( QUOTEREGEX, QUOTEESC, pt )
  ptt = pt
  gsub( TRIPLETNREGEX, NLINE, pt )
  gsub( TRIPLETTREGEX, TAB, pt )
  gsub( CNTRLREGEX, TRIPLETC, ptt )
  u = "'" us "'"
  g = "'" gr "'"
  m = "'" md "'"
  s = "\"${sourceDir}\"'" pt "'"
  b = "\"${backupDir}\"'" pt "'"
  if ( $2 ~ /^REV\.MKDI/ ) {
    rev_check_nonex_dir()
    print "${MKDIR} " s
    rev_apply_attr_dir()
  } else if ( $2 ~ /^REV\.NEW/ ) {
    rev_check_nonex()
    rev_copy_file()
    rev_apply_attr()
    next_pin()
  } else if ( $2 ~ /^REV\.UP/ ) {
    rev_copy_file()
    rev_apply_attr()
    next_pin()
  } else {
    error_exit( "Unexpected action code" )
  }
}
END {
  SECTION_LINE
}
AWKEXEC3

if [ ${revNew} -eq 1 ] || [ ${revUp} -eq 1 ]; then

  start_progress "Preparing shellscript for Exec3"

  ${awk} -f "${f430}"                    \
         -v sourceDir="${sourceDirAwk}"  \
         -v backupDir="${backupDirAwk}"  \
         -v noExec=${noExec}             \
         -v touch=${touch}               \
         -v pRevUser=${pRevUser}         \
         -v pRevGroup=${pRevGroup}       \
         -v pRevMode=${pRevMode}         \
         -v noExecHdr=${noExec3Hdr}      \
         "${f530}"                       > "${f630}"

  stop_progress

else

  file_not_prepared "${f630}"

  if [ -e "${f530}" ]; then
    error_exit "Unexpected, REV actions prepared although neither --revNew nor --revUp options given"
  fi

fi

###########################################################

if [ ${noRemove} -eq 0 ]; then

  start_progress "Preparing shellscript for Exec4"

  ${awk} -f "${f410}"                    \
         -v backupDir="${backupDirAwk}"  \
         -v noExec=${noExec}             \
         -v noExecHdr=${noExec4Hdr}      \
         "${f540}"                       > "${f640}"

  stop_progress

else

  file_not_prepared "${f640}"

  if [ -e "${f540}" ]; then
    error_exit "Unexpected, avoidable removals prepared although --noRemove option given"
  fi

fi

###########################################################

if [ ${byteByByte} -eq 1 ]; then

  start_progress "Preparing shellscript for Exec5"

  ${awk} -f "${f420}"                    \
         -v sourceDir="${sourceDirAwk}"  \
         -v backupDir="${backupDirAwk}"  \
         -v noExec=${noExec}             \
         -v noUnlink=${noUnlink}         \
         -v touch=${touch}               \
         -v pUser=${pUser}               \
         -v pGroup=${pGroup}             \
         -v pMode=${pMode}               \
         -v noExecHdr=${noExec5Hdr}      \
         "${f550}"                       > "${f650}"

  stop_progress

else

  file_not_prepared "${f650}"

  if [ -e "${f550}" ]; then
    error_exit "Unexpected, copies resulting from byte by byte comparing prepared although --byteByByte option not given"
  fi

fi

###########################################################
${awk} -f "${f100}" << 'AWKTOUCH' > "${f490}"
BEGIN {
  gsub( TRIPLETBREGEX, BSLASH, metaDir )
  gsub( QUOTEREGEX, QUOTEESC, metaDir )
  BIN_BASH
  print "metaDir='" metaDir "'"
  print "TOUCH='touch -r'"
  print "set -u"
  SECTION_LINE
  print "${TOUCH} \"${metaDir}\"" f000Base \
                " \"${metaDir}\"" f999Base
  SECTION_LINE
}
AWKTOUCH

start_progress "Preparing shellscript to touch file 999"

${awk} -f "${f490}"                \
       -v metaDir="${metaDirAwk}"  \
       -v f000Base="${f000Base}"   \
       -v f999Base="${f999Base}"   > "${f690}"

stop_progress

###########################################################
${awk} -f "${f100}" << 'AWKRESTORE' > "${f700}"
BEGIN {
  FS = FSTAB
  pin = 1         # parallel index
  gsub( TRIPLETBREGEX, BSLASH, backupDir )
  gsub( TRIPLETBREGEX, BSLASH, restoreDir )
  gsub( TRIPLETBREGEX, BSLASH, f800 )
  gsub( TRIPLETBREGEX, BSLASH, f810 )
  gsub( TRIPLETBREGEX, BSLASH, f820 )
  gsub( TRIPLETBREGEX, BSLASH, f830 )
  gsub( TRIPLETBREGEX, BSLASH, f840 )
  gsub( TRIPLETBREGEX, BSLASH, f850 )
  gsub( TRIPLETBREGEX, BSLASH, f860 )
  gsub( QUOTEREGEX, QUOTEESC, backupDir )
  gsub( QUOTEREGEX, QUOTEESC, restoreDir )
  if ( 0 == noR800Hdr ) {
    BIN_BASH > f800
    print "restoreDir='" restoreDir "'" > f800
    print "MKDIR='mkdir'" > f800
    print "set -u" > f800
  }
  if ( 0 == noR810Hdr ) {
    BIN_BASH > f810
    print "backupDir='" backupDir "'" > f810
    print "restoreDir='" restoreDir "'" > f810
    print "CP" ONE_TO_MAXPARALLEL "='cp'" > f810
    print "TOUCH" ONE_TO_MAXPARALLEL "='touch -r'" > f810
    print "set -u" > f810
  }
  if ( 0 == noR820Hdr ) {
    BIN_BASH > f820
    print "restoreDir='" restoreDir "'" > f820
    print "LNSYMB='ln -s --'" > f820
    print "set -u" > f820
  }
  if ( 0 == noR830Hdr ) {
    BIN_BASH > f830
    print "restoreDir='" restoreDir "'" > f830
    print "LNHARD='ln'" > f830
    print "set -u" > f830
  }
  if ( 0 == noR840Hdr ) {
    BIN_BASH > f840
    print "restoreDir='" restoreDir "'" > f840
    print "CHOWN_DIR='chown'" > f840
    print "CHOWN" ONE_TO_MAXPARALLEL "='chown'" > f840
    print "CHOWN_LNSYMB='chown -h'" > f840
    print "set -u" > f840
  }
  if ( 0 == noR850Hdr ) {
    BIN_BASH > f850
    print "restoreDir='" restoreDir "'" > f850
    print "CHGRP_DIR='chgrp'" > f850
    print "CHGRP" ONE_TO_MAXPARALLEL "='chgrp'" > f850
    print "CHGRP_LNSYMB='chgrp -h'" > f850
    print "set -u" > f850
  }
  if ( 0 == noR860Hdr ) {
    BIN_BASH > f860
    print "restoreDir='" restoreDir "'" > f860
    print "CHMOD_DIR='chmod'" > f860
    print "CHMOD" ONE_TO_MAXPARALLEL "='chmod'" > f860
    print "set -u" > f860
  }
  SECTION_LINE > f800
  SECTION_LINE > f810
  SECTION_LINE > f820
  SECTION_LINE > f830
  SECTION_LINE > f840
  SECTION_LINE > f850
  SECTION_LINE > f860
}
{
  if ( $2 !~ /^KEEP/ ) {
    us = $10
    gr = $11
    md = $12
    pt = $13
    ol = $15
    gsub( QUOTEREGEX, QUOTEESC, us )
    gsub( QUOTEREGEX, QUOTEESC, gr )
    gsub( QUOTEREGEX, QUOTEESC, pt )
    gsub( QUOTEREGEX, QUOTEESC, ol )
    gsub( TRIPLETNREGEX, NLINE, pt )
    gsub( TRIPLETNREGEX, NLINE, ol )
    gsub( TRIPLETTREGEX, TAB, pt )
    gsub( TRIPLETTREGEX, TAB, ol )
    u = "'" us "'"
    g = "'" gr "'"
    m = "'" md "'"
    b = "\"${backupDir}\"'" pt "'"
    r = "\"${restoreDir}\"'" pt "'"
    o = "\"${restoreDir}\"'" ol "'"
    if ( "d" == $3 ) {
      print "${MKDIR} " r > f800
      print "${CHOWN_DIR} " u " " r > f840
      print "${CHGRP_DIR} " g " " r > f850
      print "${CHMOD_DIR} " m " " r > f860
    } else if ( "f" == $3 ) {
      print "${CP" pin "} " b " " r > f810
      print "${TOUCH" pin "} " b " " r > f810
      print "${CHOWN" pin "} " u " " r > f840
      print "${CHGRP" pin "} " g " " r > f850
      print "${CHMOD" pin "} " m " " r > f860
      if ( MAXPARALLEL <= pin ) {
        pin = 1
      } else {
        pin = pin + 1
      }
    } else if ( "l" == $3 ) {
      print "${LNSYMB} '" ol "' " r > f820
      print "${CHOWN_LNSYMB} " u " " r > f840
      print "${CHGRP_LNSYMB} " g " " r > f850
    } else if ( "h" == $3 ) {
      print "${LNHARD} " o " " r > f830
    }
  }
}
END {
  SECTION_LINE > f860
  SECTION_LINE > f850
  SECTION_LINE > f840
  SECTION_LINE > f830
  SECTION_LINE > f820
  SECTION_LINE > f810
  SECTION_LINE > f800
  close( f860 )
  close( f850 )
  close( f840 )
  close( f830 )
  close( f820 )
  close( f810 )
  close( f800 )
}
AWKRESTORE

if [ ${noRestore} -eq 0 ]; then

  start_progress "Preparing shellscripts for case of restore"

  ${awk} -f "${f700}"                     \
         -v backupDir="${backupDirAwk}"   \
         -v restoreDir="${sourceDirAwk}"  \
         -v f800="${f800Awk}"             \
         -v f810="${f810Awk}"             \
         -v f820="${f820Awk}"             \
         -v f830="${f830Awk}"             \
         -v f840="${f840Awk}"             \
         -v f850="${f850Awk}"             \
         -v f860="${f860Awk}"             \
         -v noR800Hdr=${noR800Hdr}        \
         -v noR810Hdr=${noR810Hdr}        \
         -v noR820Hdr=${noR820Hdr}        \
         -v noR830Hdr=${noR830Hdr}        \
         -v noR840Hdr=${noR840Hdr}        \
         -v noR850Hdr=${noR850Hdr}        \
         -v noR860Hdr=${noR860Hdr}        \
         "${f505}"

  stop_progress

else

  file_not_prepared "${f800}"
  file_not_prepared "${f810}"
  file_not_prepared "${f820}"
  file_not_prepared "${f830}"
  file_not_prepared "${f840}"
  file_not_prepared "${f850}"
  file_not_prepared "${f860}"

fi

###########################################################

# now all preparations are done, start executing ...

if [ ${noExec} -eq 1 ]; then
  exit 0
fi

if [ -s "${f510}" ]; then
  echo
  echo "UNAVOIDABLE REMOVALS FROM ${backupDirTerm}"
  echo "==========================================="

  ${awk} -f "${f104}" -v color=${color} "${f510}"

  if [ ${noRemove} -eq 1 ]; then
    echo
    echo "WARNING: Unavoidable removals prepared regardless of the --noRemove option"
  fi
  echo
  read -p "Execute above listed removals from ${backupDirTerm} ? [Y/y=Yes, other=do nothing and abort]: " tmpVal
  if [ "Y" == "${tmpVal/y/Y}" ]; then
    echo
    bash "${f610}" | ${awkNoBuf} -f "${f102}" -v color=${color}
  else
    error_exit "User requested Zaloha to abort"
  fi
fi

echo
echo "TO BE COPIED TO ${backupDirTerm}"
echo "==========================================="

${awk} -f "${f104}" -v color=${color} "${f520}"

if [ -s "${f520}" ]; then
  echo
  read -p "Execute above listed copies to ${backupDirTerm} ? [Y/y=Yes, other=do nothing and abort]: " tmpVal
  if [ "Y" == "${tmpVal/y/Y}" ]; then
    echo
    bash "${f620}" | ${awkNoBuf} -f "${f102}" -v color=${color}
  else
    error_exit "User requested Zaloha to abort"
  fi
fi

if [ ${revNew} -eq 1 ] || [ ${revUp} -eq 1 ]; then
  echo
  echo "TO BE REVERSE-COPIED TO ${sourceDirTerm}"
  echo "==========================================="

  ${awk} -f "${f104}" -v color=${color} "${f530}"

  if [ -s "${f530}" ]; then
    echo
    read -p "Execute above listed reverse-copies to ${sourceDirTerm} ? [Y/y=Yes, other=do nothing and abort]: " tmpVal
    if [ "Y" == "${tmpVal/y/Y}" ]; then
      echo
      bash "${f630}" | ${awkNoBuf} -f "${f102}" -v color=${color}
    else
      error_exit "User requested Zaloha to abort"
    fi
  fi
fi

if [ ${noRemove} -eq 0 ]; then
  echo
  echo "TO BE REMOVED FROM ${backupDirTerm}"
  echo "==========================================="

  ${awk} -f "${f104}" -v color=${color} "${f540}"

  if [ -s "${f540}" ]; then
    echo
    read -p "Execute above listed removals from ${backupDirTerm} ? [Y/y=Yes, other=do nothing and abort]: " tmpVal
    if [ "Y" == "${tmpVal/y/Y}" ]; then
      echo
      bash "${f640}" | ${awkNoBuf} -f "${f102}" -v color=${color}
    else
      error_exit "User requested Zaloha to abort"
    fi
  fi
fi

if [ ${byteByByte} -eq 1 ]; then
  echo
  echo "FROM BYTE BY BYTE COMPARING: TO BE COPIED TO ${backupDirTerm}"
  echo "==========================================="

  ${awk} -f "${f104}" -v color=${color} "${f550}"

  if [ -s "${f550}" ]; then
    echo
    read -p "Execute above listed copies to ${backupDirTerm} ? [Y/y=Yes, other=do nothing and abort]: " tmpVal
    if [ "Y" == "${tmpVal/y/Y}" ]; then
      echo
      bash "${f650}" | ${awkNoBuf} -f "${f102}" -v color=${color}
    else
      error_exit "User requested Zaloha to abort"
    fi
  fi
fi

bash "${f690}"       # touch the file 999_mark_executed

###########################################################

# end
