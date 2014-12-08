#!/bin/bash

####################################################################################
#
# killPolicyNoServer.sh
# 
# Created:  2014-04-14
# Modified: 2014-04-14
#
# jschripsema@expedia.com
#
# This script checks to see if a server is available. If not, it will kill the 
# policy. Optionally displaying a message to the user using cocoaDialog or
# jamfHelper. Only really useful if run "Before" anything else executes.
#
# Priority: Before
# Category: Management Tools - No SS
#
# Three required variable inputs:
#    ! serverAddr: $4
#    ! serverPort: $5
#    ! policyID: $6
#
# Two optional variable inputs:
#     userNotification: $7
#     notificationProgram: $8
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

cocoaDialogApp='/usr/local/bin/cocoaDialog'
jamfHelperApp='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
dialogTitle='Could Not Connect'
notificationProgram='cocoa'
cocoaIcon='caution'
cocoaHeader='Could not connect to a required resource.'
jamfIcon='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/Resources/Message.png'
yesButton='Ok'

# Gather the server address to check if available.
if [ -n "${4}" ]; then
	serverAddr="${4}"
else
	printf '%s\n' 'A server must be specified in order to use this script.'
	exit 1
fi

# Gather the server port to check if available.
if [ -n "${5}" ]; then
	serverPort="${5}"
else
	printf '%s\n' 'A server port must be specified in order to use this script.'
	exit 1
fi

# Gather the JAMF policy ID to kill in the event of a server being unavailable.
if [ -n "${6}" ]; then
	policyID="${6}"
else
	printf '%s\n' 'A JAMF policy ID must be specified in order to use this script.'
	exit 1
fi

# Get the, optional, user notification message.
if [ -n "${7}" ]; then
	userNotification="${7}"
else
	userNotification=''
	printf '%s\n' 'No user notification specified. User will not be notified.'
fi

# Get the, optional, preferred notification program. If unspecified, default to 'cocoa'.
if [ -n "${8}" ]; then
	notificationProgram="${8}"
else
	printf '%s %s\n' 'No preferred notification program specified. Defaulting to:' "${notificationProgram}"
fi

# Validate that notificationProgram is either 'jamf' or 'cocoa'.
if [ "${notificationProgram}" != 'cocoa' ] && [ "${notificationProgram}" != 'jamf' ]; then
	notificationProgram='cocoa'
fi

# Make sure that some notification program is on the system, or clear the notification.
if [ ! -f "${cocoaDialogApp}" ] && [ ! -f "${jamfHelperApp}" ]; then
	printf '%s\n' 'No notification program found. User will not be notified.'
	userNotification=''
fi

# If 'cocoa' is specified, but cocoaDialog is not available, default to jamfHelper.
if [ "${notificationProgram}" == 'cocoa' ] && [ ! -f "${cocoaDialogApp}" ]; then
	notificationProgram='jamf'
fi

# If 'jamf' is specified, but jamfHelper is not available, default to cocoaDialog.
if [ "${notificationProgram}" == 'jamf' ] && [ ! -f "${jamfHelperApp}" ]; then
	notificationProgram='cocoa'
fi

# Check the server:
nc -z "${serverAddr}" "${serverPort}"

if [ "$?" -eq "0" ]; then
	# Server is reachable.
	printf '%s\n' 'Server reachable. Continuing.'
	exit 0
else
	# Server is not reachable. Notify...
	if [ -n "${userNotification}" ]; then
		if [ "${notificationProgram}" == 'cocoa' ]; then
			"${cocoaDialogApp}" msgbox --title "${dialogTitle}" --text "${cocoaHeader}" --icon "${cocoaIcon}" --informative-text "${userNotification}" --button1 "${yesButton}" &
		else
			"${jamfHelperApp}" -windowType 'utility' -title "${dialogTitle}" -icon "${jamfIcon}" -description "${userNotification}" -button1 "${yesButton}" -defaultButton 1 -startlaunchd &
		fi
		# If notifying, assume Self Service install. Kill the 'Self Service' application.
		killall 'Self Service'
	fi
	
	# ... and shut it down.
	for i in $(ps -axj | grep -v -e 'grep' -e 'awk' | awk "/jamf/ && /${policyID}/ {print \$2}"); do
		kill -9 "${i}"
		rm "/private/tmp/${i}.tmp"
	done
	
	
	
	printf '%s\n' 'Server is not reachable. Killing policy.'
	exit 1
fi