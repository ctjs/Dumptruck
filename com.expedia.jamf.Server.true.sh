#!/bin/bash

##### HEADER BEGINS ################################################################
# com.expedia.jamf.Server.true.sh
# 
# Created:  2014-04-04
# Modified: 2014-04-04
#
# jschripsema@expedia.com
#
# Priority: At Reboot
# Category: Management Tools - No SS
#
# This script writes the key/value 'Server'='true' to the plist /Library/Preferences/com.expedia.jamf.plist
#
##### HEADER ENDS ##################################################################

# Set the mountpoint passed by Casper.
mountPoint="$1"

# Set the computername passed by Casper.
computerName="$2"

# Set the username passed by Casper.
username="$3"

####################################################################################

defaults write /Library/Preferences/com.expedia.jamf Server -string 'true'