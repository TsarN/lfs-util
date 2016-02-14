#!/bin/bash
install -m 755 src/gross.sh $1/usr/bin/gross
install -m 755 src/service.sh $1/usr/sbin/service
mkdir -pv $1/usr/share/bootscripts
cp -rv bootscripts/* $1/usr/share/bootscripts/
rm -vrf /tmp/bootscripts /tmp/bootscripts.tar.bz2
mkdir -pv $1/var/lib/gross/db
cp -rv ports/* $1/var/lib/gross/db/
