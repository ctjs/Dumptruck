#!/bin/sh

####################################################################################
#
# setSearchDomains.sh
# 
# Created:  2014-05-12
# Modified: 2014-05-12
#
# jschripsema@expedia.com
#
# This script sets the search domains on every interface.
#
# Priority: Before
# Category: Management Tools - No SS
#
# One required variable input:
#     searchDomains: $4
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

if [ -n "${4}" ]; then
	searchDomains="${4}"
else
	echo 'This script requires a list of search domains.'
	exit 1
fi

interfaceArray=()
while read line; do
	interfaceArray+=("${line}")
done <<< "$(/usr/sbin/networksetup -listallnetworkservices | tail +2 | tr -d '*')"

# Loops through the list of network services
for i in "${interfaceArray[@]}"; do
	/usr/sbin/networksetup -setsearchdomains "${i}" ${searchDomains}
done