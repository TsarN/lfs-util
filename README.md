# LFS-util
This package contains some useful tools for Linux From Scratch.
## Contents
- service - a simple tool to manage SysVInit services using BLFS bootscripts
- gross - package manager for Linux From Scratch. Supports installing, removing, upgrading, dependencies, syncing with Subversion LFS repository

## How to install
In Chapter 6, just before chrooting, run

    # ./install-<LFS version>.sh $LFS

## Files
- /usr/bin/gross - Gross
- /usr/sbin/service - serivce
- /usr/share/bootscripts - BLFS Bootscripts
- /var/lib/gross/db - LFS SVN build scripts (2016-02-09)

## Supported versions:
- LFS 7.9-rc1
- LFS 7.9-rc2
