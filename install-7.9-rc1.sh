#!/bin/bash
install -m 755 src/gross.sh $1/usr/bin/gross
install -m 755 src/service.sh $1/usr/sbin/service
install -m 644 config/gross.sh $1/etc/gross
mkdir -pv $1/usr/share/bootscripts
cp -rv bootscripts/* $1/usr/share/bootscripts/
rm -vrf /tmp/bootscripts /tmp/bootscripts.tar.bz2
mkdir -pv $1/var/lib/gross/db
cp -rv ports-7.9-rc1/* $1/var/lib/gross/db/
