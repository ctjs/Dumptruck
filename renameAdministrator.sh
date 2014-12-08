#!/bin/bash

##### HEADER BEGINS #####
#
# renameAdministrator.sh
#
# Created 20140430 by Joshua Schripsema
# jschripsema@expedia.com
# Modified 20140430 by Joshua Schripsema
#
# This script will search for a user with the Real/Full Name 'administrator', case
# insensitive. If the Short Name is not also 'administrator', it will set the Real Name
# to be the same as the Short Name. This is to resolve issues creating the management
# account due to an account already existing with that name.
#
# Priority: Before
# Category: Management Tools - No SS
#
# Variable Inputs:
# $1 - mountPoint, auto-passed by Casper Suite.
# $2 - computerName, auto-passed by Casper Suite.
# $3 - username, auto-passed by Casper Suite.
#
##### HEADER ENDS #####

administratorUser="$(sudo jamf listUsers | grep -i -B 1 '<realname>administrator</realname>')"
if [ -z "${administratorUser}" ]; then
	exit 0
fi

realName="$(awk -F '[<>]' '/<realname>/ { print $3 }' <<< "${administratorUser}")"
shortName="$(awk -F '[<>]' '/<name>/ { print $3 }' <<< "${administratorUser}")"

if [ "$(grep -i -c 'administrator' <<< "${shortName}")" -ne '1' ]; then
	dscl . -change "/Users/${shortName}" RealName "${realName}" "${shortName}"
fi