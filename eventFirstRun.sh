#!/bin/bash

##### HEADER BEGINS #####
# eventFirstRun.sh
# 
# Created:  2014-03-17
# Modified: 2014-10-29
#
# jschripsema@expedia.com
#
# Priority: At Reboot
# Category: Management Tools - No SS
#
# This script runs the FirstRun event.
#
##### HEADER ENDS #####

# Make an array of all the FileVault enabled users.
userArray=()
while read line; do
	[ -z "${line}" ] && continue
	userArray+=("${line}")
done <<< "$(fdesetup list 2>/dev/null | cut -d, -f1)"

# If no FileVault enabled users, assume new machine. Display initial configuration dialog.
if [ "${#userArray[@]}" -eq '0' ]; then
	jamfHelperApp='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
	jamfIcon='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/Resources/Message.png'
	yesButtonLabel='Okay'
	
	killall "$(basename "${jamfHelperApp}")"
	"${jamfHelperApp}" -windowType utility -title 'Starting Initial Configuration' -description 'Starting initial configuration. Please wait until you receive notice that all tasks are complete.' -icon "${jamfIcon}" -button1 "${yesButtonLabel}" -defaultButton 1 -startlaunchd >/dev/null 2>&1 &
fi

jamf recon
jamf policy -event FirstRun