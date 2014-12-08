#!/bin/bash

####################################################################################
#
# removeApplications.sh
# 
# Created:  2014-05-01
# Modified: 2014-05-01
#
# joshua.schripsema@expedia.com
#
# This script removes specified applications from /Applications.
#
# Priority: Before
# Category: Management Tools - No SS
#
# Eight Parameters:
#	Application: $4
#	Application: $5
#	Application: $6
#	Application: $7
#	Application: $8
#	Application: $9
#	Application: $10
#	Application: $11
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

for i in "${@:4}"; do
	if [ -d "${mountPoint}/Applications/${i}" ] && [ -n "${i}" ]; then
		printf 'Removing Application: %s\n' "${mountPoint}/Applications/${i}"
		rm -rf "${mountPoint}/Applications/${i}"
	fi
done