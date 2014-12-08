#!/bin/bash

####################################################################################
#
# adUnbind.sh
# 
# Created:  2014-04-21
# Modified: 2014-04-21
#
# jschripsema@expedia.com
#
# This script unbinds a machine. It requires that a username and password be
# specified.
#
# Two required variable inputs:
#     adUsername: $4
#     adPassword: $5
#
# Priority: Before
# Category: Management Tools - No SS
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

if [ -n "${4}" ]; then
	adUsername="${4}"
else
	echo 'This script requires a username.'
	exit 1
fi

if [ -n "${5}" ]; then
	adPassword="${5}"
else
	echo 'This script requires a password.'
	exit 1
fi

dsconfigad -f -r -u "${adUsername}" -p "${adPassword}"
exit "${?}"