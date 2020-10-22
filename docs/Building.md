How to Build Open Network Linux 
============================================================

Before Start
------------------------------------------------------------

This FHGW repository was created according to the suggestion of
"Open Network Linux - A Programmers View.pdf" page #15:

  STATEGIES FOR ROLLING YOUR OWN DISTRO

  1. Add the ONL repo as a submodule to your existing code
  2. Create a your-pkgs.yml file with custom package lists
    - Mix and match with existing  ONL packages as desired
    - Optionally transitively include existing lists, e.g., $arch-common.yml
  3. Call the $ONL/tools/onlrfs.py tool to make the root file system
  4. Convert the root file system into an ONIE shar (using ONL tools)
  5. Possibly re-use existing Makefile magic from $ONL/make

All implementation of FHGW are organized similar as ONL, puls add ONL repo
as a submodule with below notes:

  1. All FHGW packages stored at our own "builds" and "packages" folders
     like ONL did.

  2. Due to FHGW platform code not push to OCP yet, it must copy under
     FHGW repo now and hope we can move it to ONL repo soon.

  3. Due to onlp-x86-64-pegatron-fm-6609-bn-ff-r0:amd64 build issue that
     it can't build successful outside ONL repo, FHGW platforms code are
     temporarily move to tools/platforms folder and add symobolic link to
     ONL repo accordingly.

  4. Other packages like SDK etc... located at packages/platforms-closed folder

  5. We try don't touch ONL repo, however, some of changes have been made due to:

    - We need to disable ONL's "upgrade" and "onl-kernel-4.19-lts-x86-64-all"
      packages because we want to use our own.

    - Due to FHGW platform code are symbolic link to ONL repo, some of python
      utilies need to modify to prevent os.walk not walk through into by default.

    - Below environment variable can be set (if you have local mirror) for
      faster local builds:

      . ONL_APT_ONL_SITE: ONL APT repository mirror
      . K_ARCHIVE_SITE:   Linux kernel local archives

    
Build FHGW Summary
------------------------------------------------------------

    #> git clone https://github.com/PegaSwitch/FHGW.git
    #> cd FHGW

    #> git submodule init
    #> git submodule update      # you need to get ONL repo as submodule firstly

    #> OpenNetworkLinux/docker/tools/onlbuilder (-8) # enter the docker workspace
    #> source setup.env          # pull in necessary environment variables
                                 # $ONL assigned to ONL repo now, and new
                                 # $ONLBASE was created to refer to FGHW repo
    #> apt-cacher-ng
    #> make amd64                # make onl for amd64 $platform

The resulting ONIE installers are in $ONLBASE/RELEASE/$SUITE/$ARCH folder


NOTE
-----------------------------------------------------------

 1. Refer to OpenNetworkLinux/docs/Building.md for more build detail

 2. Some of patched are applied on ONL repo during "source setup.env",
    to recovery it, use tools/cleanup-submodules.sh

