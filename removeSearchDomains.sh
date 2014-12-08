#!/bin/bash

####################################################################################
#
# removeSearchDomains.sh
# 
# Created:  2014-07-24
# Modified: 2014-07-24
#
# jschripsema@expedia.com
#
# This script removes specified search domains for every interface.
#
# Priority: Before
# Category: Management Tools - No SS
#
# One required variable input:
#     excludeSearchDomains: $4
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

if [ -n "${4}" ]; then
	excludeSearchDomains="${4}"
else
	echo 'This script requires a list of search domains.'
	exit 1
fi

# Build an array of the interfaces.
interfaceArray=()
while read line; do
	interfaceArray+=("${line}")
done <<< "$(/usr/sbin/networksetup -listallnetworkservices | tail +2 | tr -d '*')"

# Loop through the list of network services, setting the existing settings with the
# excluded domains... excluded.
for i in "${interfaceArray[@]}"; do
	searchDomains=''
	while read line; do
		if [ "$(grep -c " ${line} " <<< " ${excludeSearchDomains} ")" -eq '0' ]; then
			searchDomains="${searchDomains} ${line}"
		fi
	done <<< "$(/usr/sbin/networksetup -getsearchdomains "${i}")"
	/usr/sbin/networksetup -setsearchdomains "${i}" ${searchDomains}
done