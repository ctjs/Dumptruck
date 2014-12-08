#!/bin/bash

##### HEADER BEGINS #####
# suppressSetupAssistant.sh
#
# Created 20140623 by Joshua Schripsema
# jschripsema@expedia.com
# Modified 20140623 by Joshua Schripsema
#
# Category: Management Tools - No SS
# Info: This script suppresses the Setup Assistants.
# Priority: At Reboot
#
##### HEADER ENDS #####

# Set the mountpoint passed by Casper.
mountPoint="$1"

# Set the computername passed by Casper.
computerName="$2"

# Set the username passed by Casper.
username="$3"

userFolder="/Users/"
osVersion="$(sw_vers -productVersion)"

# Remove iCloud and Gestures Mini Setup
# Set user template settings. 
for i in "/System/Library/User Template/"*; do
	defaults write "${i}"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
	defaults write "${i}"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
	defaults write "${i}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${osVersion}"
done

# Set for all Users as well
for i in "${userFolder}"*; do
	if [ -d "${i}/Library/Preferences" ] && [ "${i}" != 'Shared' ]; then
		userID="$(basename "${i}")"
		userUID="$(id -u "${userID}")"
		userGID="$(id -g "${userID}")"
	
		printf '%s %s\n' 'Setting Prefs for User: ' "${userID}"
		defaults write "${i}"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
		defaults write "${i}"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
		defaults write "${i}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${osVersion}"
		chown "${userUID}:${userGID}" "${i}"/Library/Preferences/com.apple.SetupAssistant.plist
	fi
done