# LFS-util
This package contains some useful tools for Linux From Scratch.
## Contents
- service - a simple tool to manage SysVInit services using BLFS bootscripts
- gross - package manager for Linux From Scratch. Supports installing, removing, upgrading, dependencies, syncing with Subversion LFS/BLFS repository

## How to install
In Chapter 6, just before chrooting, run

    # ./install.sh $LFS

## Files
- /usr/bin/gross - Gross
- /usr/sbin/service - serivce
- /usr/share/bootscripts - BLFS Bootscripts
- /var/lib/gross/db - Ports
