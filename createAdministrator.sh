#!/bin/bash

####################################################################################
#
# createAdministrator.sh
# 
# Created:  2014-09-15
# Modified: 2014-09-22
#
# jschripsema@expedia.com
#
# This script creates the 'administrator' account, with a blank password, if it doesn't exist.
#
# Priority: At Reboot
# Category: Management Tools - No SS
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

if [ "$(jamf listUsers | grep -ic '<name>administrator</name>')" -eq '0' ]; then
	/usr/sbin/jamf createAccount -username 'administrator' -realname 'administrator' -passhash '%f8%cb%de%8e%fe%cb%8b%e6' -home '/Users/administrator/' -hint '' -picture '/Library/User Pictures/Nature/Snowflake.tif' -admin
fi