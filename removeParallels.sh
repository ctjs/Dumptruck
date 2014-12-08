#!/bin/bash

##### HEADER BEGINS ######################################################################
#
# removeParallels.sh
# 
# Created:  2014-07-03
# Modified: 2014-07-03
#
# jschripsema@expedia.com
#
# Priority: Before
# Category: Management Tools - No SS
#
# This script deserializes and completely removes Parallels Desktop.
#
##### HEADER ENDS ########################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

# Deactivate the Parallels license.
/usr/bin/prlsrvctl deactivate-license

# Kill all the processes.
for i in $(ps aux | awk '/Parallels\ Desktop.app/ { print $2 }'); do
	kill -KILL "${i}"
done

# Unload all the kexts.
for i in $(kextstat | awk '/parallels/ { print $6 }'); do
	kextunload -b "${i}" > /dev/null 2>&1
done

# Remove any kexts that might be lingering from an old install.
[ -e /System/Library/Extensions/prl_hid_hook.kext ] && rm -rf /System/Library/Extensions/prl_hid_hook.kext
[ -e /System/Library/Extensions/prl_hypervisor.kext ] && rm -rf /System/Library/Extensions/prl_hypervisor.kext
[ -e /System/Library/Extensions/prl_netbridge.kext ] && rm -rf /System/Library/Extensions/prl_netbridge.kext
[ -e /System/Library/Extensions/prl_usb_connect.kext ] && rm -rf /System/Library/Extensions/prl_usb_connect.kext
[ -e /System/Library/Extensions/prl_vnic.kext ] && rm -rf /System/Library/Extensions/prl_vnic.kext

# Remove any symbolic links to command line programs.
for i in $(ls -la /usr/bin/ | awk '/Parallels Desktop.app/ { print $9 }'); do
	rm -f "/usr/bin/${i}"
done

# Remove any symbolic links to the man pages.
for i in $(ls -lad /usr/share/man/*/* | awk '/Parallels Desktop.app/ { print $9 }'); do
	[ "$(dirname "$(dirname "${i}")")" == '/usr/share/man' ] && rm -f "${i}"
done

# Delete the application itself.
rm -rf '/Applications/Parallels Desktop.app'

echo "Parallels has been removed"
exit 0