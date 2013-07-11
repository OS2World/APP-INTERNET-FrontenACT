FRONTENACT - RELEASE NOTES
VERSION 0.50 (2010-09-11)

  FrontenACT is a graphical front-end for the "Enhanced CTorrent" BitTorrent
  client for OS/2.  It allows you to:

   - Open torrent files and start downloading or seeding.
   - Monitor and manage (stop, start, delete, or alter) these torrent files
     subsequently.
   - Monitor active CTorrent processes running on a different system on the
     local network, if they were started with the appropriate parameters.

  The advantage of FrontenACT is that it lets you monitor and/or manage multiple
  torrents from a single window, instead of having to keep track of several
  different CTorrent instances.  It also lets you run CTorrent detached, thus
  not cluttering up your desktop and/or window list.

  The name 'FrontenACT' is a reference to Frontenac, the name of my home county
  in Canada.  It's also, obviously, a play on 'Front-End for (A)CTorrent'.



REQUIREMENTS

  FrontenACT requires the following:

   * An OS/2 port of Enhanced CTorrent.  I recommend using ACT.EXE, available
     at: http://www.os2site.com/sw/internet/peer_peer/index.html
     However, you can also other OS/2 ports such as the older CTORRENT9.EXE.

   * A 32-bit TCP/IP stack (MPTS 5.3/WR*8600 or higher)

   * The VX-REXX 2.1D runtime library (VROBJ.DLL)



HOW TO USE

  1. Installation and Configuration

  Currently, installation is manual.  Copy PMFACT.EXE to a location of your
  choice, and create a program object for it.

  The first time you start FrontenACT, you should open the 'CTorrent'
  configuration dialog under the Settings menu, and verify that the name (and
  path, if necessary) of the Enhanced CTorrent executable are correct.  You can
  adjust the other options on this dialog as well (hopefully they are fairly
  self-explanatory), although it's generally safe to leave them at their
  defaults values.

  Next, go into the 'Directories' item in the same menu, and review and/or
  modify the configured directories as you see fit.  There are four directories
  to be defined:
    - A directory for 'running' (actively downloading) torrent files.
    - A directory for 'seeding' (complete but active) torrent files.
    - A directory for 'removed' torrent files (that you have chosen to
      remove from FrontenACT using either 'Selected -> Remove' or the
      Delete key).
    - A default directory for downloading the actual torrent contents to.
  These directories can have whatever names and locations you like, as long
  as they are (a) writable, (b) support long filenames, and (c) support
  extended attributes.  (This generally means they must be located on an HPFS,
  JFS, or possibly FAT32 filesystem).  By default they are set to sub-
  directories of whatever directory PMFACT.EXE is located in.

  NOTE: The directories need not exist - FrontenACT will create them if
  necessary the first time it tries to access them - but their PARENT
  directory (or directories) must exist already if this is to work.

  You may also want to adust the settings under the 'Preferences' menu item,
  but this is not generally required in order for FrontenACT to operate
  successfully.

  Note that starting PMFACT.EXE with a '/d' argument will cause debug output
  to be shown, which may be useful if you encounter unexpected problems.


  2. Opening and Managing Torrents

  The operation is fairly straight-forward.  The File menu offers two open
  options: one for opening a single file, and one for opening multiple files
  simultaneously.  In either case, simply select the BitTorrent file or files
  (which should have a name ending in '.torrent') using the standard PM file
  dialog.

  What exactly happens when a file is opened depends on how you have configured
  FrontenACT's preferences.  The following behaviours are possible:

   A. The "start automatically" option is set to "Never".
      --> The torrent file is simply added to the torrent list.  It is not 
          started automatically; it is up to you to configure and start the
          download manually.

   B. The "start automatically" option is set to something other than "Never",
      and the "show options dialog" checkbox is checked.
      --> The Torrent Options dialog is opened, allowing you to configure the
          specific behaviour of that torrent download.  The actual torrent
          download is started from this dialog.

   C. The "start automatically" option is set to something other than "Never",
      and the "show options dialog" checkbox is UNchecked.
      --> The torrent download is started immediately, without showing the 
          Torrent Options dialog.  Default options are used for the torrent.

  If you configure FrontenACT for (B) or (C), you have the option of allowing
  this behaviour when multiple torrents are opened, or of limiting it to when
  only a single torrent is opened at one time (depending on the value of the
  "start automatically" drop-down).

  The default behaviour is (B), applied to single torrent files only.

  Except for the case described as (C) above, the Torrent Options dialog will
  always be displayed when you choose to start a torrent IF no options have
  previously been set for that torrent.  (Generally, this only applies the
  first time a torrent is started after it is added to FrontenACT.)  Once a
  torrent has had its options set, however, the Torrent Options dialog will
  not be displayed when you choose to (re)start the torrent.  (If you need to
  change a torrent's options subsequently, you can select the 'Set options'
  item from the Selected menu; this is only possible if the torrent is NOT
  currently active.)

  The Torrent Options dialog allows you to customize the parameters specific
  to the particular torrent.  These include:
   - Which tracker to use (if more than one is defined in the torrent),
   - Which files to download (for multi-file torrents)
   - How to handle foreign characters in filenames
   - What directory to save the downloaded files into

  Once a torrent is active, you can stop it using the eponymous item under
  the Selected menu while the torrent is highlighted.

  To remove a torrent from FrontenACT, highlight it and select 'Remove'
  from the Selected menu.

  You can select multiple torrents simultanously by using standard 'swipe
  selection' (or Shift+Up/Down).


  3. Monitoring Separately Started Torrents

  You can also manage torrents which were started with CTorrent manually (i.e.
  from outside FrontenACT), IF you specified the '-S localhost:2780' on the
  CTorrent command line.  (If you changed the CTCS port used by FrontenACT,
  substitute the appropriate value for 2780.)

  If you have other computers on the network, you can run CTorrent on those
  systems as well, and monitor them using FrontenACT.  Simply replace
  "localhost" in the parameter with the IP address of the system where
  FrontnACT is running.  For example:
    act.exe -S 192.168.1.1:2780 somefile.torrent
  where 192.168.1.1 is the IP address of the computer running FrontenACT.

  You can view or stop torrents started in this way.  However, you cannot
  change their options, or restart them once stopped (as they will disappear
  from the FrontenACT list as soon as they are stopped).

  Separately started torrents will normally keep running without incident if 
  FrontenACT is stopped or (re)started (unless you configure FrontenACT to
  stop all torrents on shutdown).


  4. Status Icons

  Each torrent shown has a coloured status icon.  The meaning of each icon
  appearance is as follows:
    Green: active local torrent
    Blue:  active remote torrent
    Grey:  inactive local torrent
    Red:   torrent which is still active but whose CTorrent process has 
           stopped sending updates
    Half green & half grey with a superimposed hourglass:
           A local torrent which is currently being started or stopped



IMPLEMENTATION NOTES

  FrontenACT's internal management of torrent files works as follows.

   - When a torrent file is opened, it is copied to the configured directory
     for 'running' torrents.  This copy of the file is used subsequently for
     all processing.  The original file is not altered in any way; once the
     torrent has been loaded into FrontenACT, therefore, you can move, rename,
     or delete the original as you wish.  (You can, however, configure 
     FrontenACT to delete the file automatically after opening.)

   - When a torrent finishes downloading, it is marked as complete.  The next
     time FrontenACT starts up it performs a validation check on all torrent
     files; complete torrents will be moved to the configured directory for
     'seeding' torrents.

   - The list of (local) torrents in the FrontenACT GUI corresponds to the
     contents of both the 'running' and 'seeding' directories.

   - When torrents in the 'seeding' directory are started, CTorrent's standard
     hash check is skipped, in order to reduce CPU load.

   - When you choose to remove an inactive torrent, the torrent file is removed
     from the 'running' or 'seeding' directory (whichever one it resides in)
     and moved to the configured directory for 'removed' torrents.  This
     directory consequently acts as kind of a trash can for torrent files.
     You should manually delete the files from this directory once you are
     sure you no longer want them.

   - Torrent options and completion status are stored in the extended attributes
     (EAs) of the torrent file.



BUGS AND LIMITATIONS

   - There seems to be a problem in how container controls are handled by the
     GUI library.  If either half of the torrent container is scrolled to the
     right (such that part of any column disappears off the left side), whenever
     the torrent list is refreshed the current view will 'snap back' to the 
     left-hand edge of whatever column is visible on the left-most side of the 
     viewing area.  This is apparently an inherent limitation of the development
     environment (VX-REXX).

   - You should not expect a very high degree of accuracy from the 'ETA' field,
     especially as the download approaches completion; it is only a rough
     estimate based on the total amount downloaded, measured against an average
     download speed calculated from the last ten values reported by CTorrent.

   - One major feature from the old PM CTorrent Manager program has not yet been
     implemented: the ability to view torrent details (like individual files and
     peers) in a separate window.

  FrontenACT is an extremely complex program, and there will probably be still-
  undiscovered bugs in additional to what is documented here.  Please report
  any you find to the author (contact information below).



HISTORY

  0.50  (2010-9-11)
   - First public release

  0.5p3 (2010-8-8)
  0.5p2 (2010-6-23)
  0.5p1 (2010-6-11)
   - Private beta releases.



GENEOLOGY

  FrontenACT is the successor product to an experimental program I previously
  wrote, known as PM CTorrent Manager.  Compared to the older program, it has
  a much more robust and reliable internal design, and considerably more
  features.  General improvements over the older program include (but are not
  necessarily limited to):
   - The ability to open multiple torrents files at a time.
   - The ability to start torrents automatically without an options dialog,
     using (more sophisticated) default options.
   - A more streamlined threading model and improved scalability in general.
   - Simpler and more reliable status tracking (e.g. not dependent on EAs to 
     identify active torrents).
   - Better synchronization of GUI updates.
   - A 'preferred tracker' list.
   - A new 'ETA' column.
   - More meaningful status icons.
   - More configurable preferences.



LICENSE

  Copyright (C) 2010 Alex Taylor.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

  3. The name of the author may not be used to endorse or promote products
     derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.


--
Alex Taylor - alex at altsan dot org  (<-- almost-usable address)
http://users.socis.ca/~ataylo00/
