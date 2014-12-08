#!/bin/bash

##### HEADER BEGINS #####
#
# com.expedia.jamf.FirstRun.has.sh
# 
# Created:  2014-04-04
# Modified: 2014-04-04
#
# jschripsema@expedia.com
#
# Priority: At Reboot
# Category: Management Tools - No SS
#
# This script writes the key/value 'FirstRun'='has' to the plist /Library/Preferences/com.expedia.jamf.plist
#
##### HEADER ENDS #####

# Set the mountpoint passed by Casper.
mountPoint="$1"

# Set the computername passed by Casper.
computerName="$2"

# Set the username passed by Casper.
username="$3"

# Make an array of all the FileVault enabled users.
userArray=()
while read line; do
	[ -z "${line}" ] && continue
	userArray+=("${line}")
done <<< "$(fdesetup list 2>/dev/null | cut -d, -f1)"

# If no FileVault enabled users, assume new machine. Display provisioning dialog.
if [ "${#userArray[@]}" -eq '0' ]; then
	jamfHelperApp='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
	jamfIcon='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/Resources/Message.png'
	yesButtonLabel='Okay'
	
	killall "$(basename "${jamfHelperApp}")"
	"${jamfHelperApp}" -windowType utility -title 'Initial Configuration Complete' -description 'Initial configuration complete. Please proceed with provisioning.' -icon "${jamfIcon}" -button1 "${yesButtonLabel}" -defaultButton 1 -startlaunchd >/dev/null 2>&1 &
fi

defaults write /Library/Preferences/com.expedia.jamf FirstRun -string 'has'