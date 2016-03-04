# LFS-util
This package contains some useful tools for Linux From Scratch.
## Contents
- service - a simple tool to manage SysVInit services using BLFS bootscripts
- gross - package manager for Linux From Scratch. Supports installing, removing, upgrading, dependencies, syncing with Subversion LFS/BLFS repository

## How to install
In Chapter 6, just before chrooting, run

    # ./install.sh $LFS
    
## Dependencies

### Required
`bash`, `coreutils`, `grep`, `sed`, `tar`, `gzip`, `bzip2`, `xz` - all provided by LFS

### Recommended
`wget` - for downloading packages

`sudo` - for building packages as not priviligied user

`vim` - for editing packages

### Optional
`subversion` - for downloading packages from SVN

`git` - for downloading packages from Git

`unzip`, `unrar`, `cabextract` - for unpacking packages


## Files
- /usr/bin/gross - Gross
- /usr/sbin/service - serivce
- /usr/share/bootscripts - BLFS Bootscripts
- /var/lib/gross/db - Ports
