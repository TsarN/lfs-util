#!/bin/bash
install -m 755 src/gross.sh /usr/bin/gross
install -m 755 src/service.sh /usr/sbin/service
mkdir -pv /usr/share/bootscripts
cp -rv bootscripts/* /usr/share/bootscripts/
rm -vrf /tmp/bootscripts /tmp/bootscripts.tar.bz2
mkdir -pv /var/lib/gross/db
cp -rv ports/* /var/lib/gross/db/
