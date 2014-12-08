#!/bin/bash

####################################################################################
#
# loginAssignUser.sh
# 
# Created:  2014-07-02
# Modified: 2014-10-29
#
# jschripsema@expedia.com
#
# This script assigns a machine and then, if the user that it is assigned to is
# logged in, generates a login event for that user. If machine is already assigned
# in the JSS, make sure it is assigned the same locally - no login event.
#
# Two required variable inputs:
#     apiAccount: $4
#     apiPassword: $5
#
# Priority: Before
# Category: User Accounts - No SS
#
####################################################################################

[ -z "${code}" ] && code="/var/root/local-client-management"
[ -z "${modules}" ] && modules="${code}/modules"

# File locations.
jamfBinary='/usr/sbin/jamf'
loginFile='/Library/Expedia/.login'
expediaPlist='/Library/Preferences/com.expedia.jamf'

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

if [ -n "${4}" ]; then
	apiAccount="${4}"
else
	echo 'This script requires an api account.'
	exit 1
fi

if [ -n "${5}" ]; then
	apiPassword="${5}"
else
	echo 'This script requires an api password.'
	exit 1
fi

Main () {
	# Serial number, uppercase, and JSS server information.
	serialNumber="$(ioreg -c IOPlatformExpertDevice -d 2 | awk '/IOPlatformSerialNumber/ { print $NF }' | tr -d '"' | tr '[:lower:]' '[:upper:]')"
	jssServer="$(get_jss_server)"

	# Check if there is an assigned user in the JSS.
	xmlResult="$(get_jss_resource_xml "${jssServer}" "computers/serialnumber/${serialNumber}/subset/location" "${apiAccount}" "${apiPassword}")"
	jssAssignedUser="$(get_single_xml_item '/computer/location' '1=1' 'username' "${xmlResult}")"
	# If assigned in the JSS, make sure it is assigned locally the same and exit out.
	if [ -n "${jssAssignedUser}" ]; then
		defaults write "${expediaPlist}" AssignedUsername -string "${jssAssignedUser}"
		"${jamfBinary}" recon >/dev/null
		exit 0
	fi
	
	# If the locally assigned user exists and is a domain account, assign this user in the JSS.
	assignUser="$(defaults read "${expediaPlist}" AssignedUsername)"
	if [ "$(dscl . -read /Users/${assignUser} AuthenticationAuthority | grep -ic 'LocalCachedUser')" -eq '0' ]; then
		assignUser=''
	fi
	
	# If user found, assign and generate a login event.
	assign_user_and_do_login "${assignUser}"
	
	# Build array of FileVault enabled domain users.
	fvUserArray=()
	while read line; do
		# Validate that the value is not null.
		[ -z "${line}" ] && continue
		# Ignore case.
		line="$(tr '[:upper:]' '[:lower:]' <<< "${line}")"
		# Verify that it is a domain account.
		[ "$(dscl . -read /Users/${line} AuthenticationAuthority | grep -ic 'LocalCachedUser')" -eq '0' ] && continue
		fvUserArray+=("${line}")
	done <<< "$(fdesetup list 2>/dev/null | cut -d, -f1)"
	
	# If there is only one domain account enabled for FileVault, assign to that one.
	if [ "${#fvUserArray[@]}" -eq '1' ]; then
		assignUser="${fvUserArray[0]}"
	fi
	
	# If user found, assign and generate a login event.
	assign_user_and_do_login "${assignUser}"
	
	# Loop through the most recent login attempts.
	while read line; do
		# If domain accounts are enabled for FileVault, assign to the first account that is also FileVault enabled.
		if [ "${#fvUserArray[@]}" -ne '0' ] && (is_in_array fvUserArray "${line}"); then
			assignUser="${line}"
		# If domain accounts are not enabled for FileVault, assign to the first domain account found in the login history.
		elif [ "${#fvUserArray[@]}" -eq '0' ] && [ "$(dscl . -read /Users/${line} AuthenticationAuthority | grep -ic 'LocalCachedUser')" -gt '0' ]; then
			assignUser="${line}"
		fi
		# If  assigned, no reason to keep searching.
		[ -n "${assignUser}" ] && break
	done <<< "$(last | awk '{ print $1 }')"
	
	# If user found, assign and generate a login event.
	assign_user_and_do_login "${assignUser}"
	
	# No user could be located to assign this machine to.
	printf '%s\n' 'Error: No user could be found to assign machine to.'
	exit 1
}

assign_user_and_do_login () {
	local assignUser="${1}"
	
	# Check if user passed to assign to. If not, resume searching.
	[ -z "${assignUser}" ] && return 0
	
	# Assign the user locally.
	defaults write "${expediaPlist}" AssignedUsername -string "${assignUser}"
	
	# Assign the machine in the JSS. If this user is not logged in, or not already running a login trigger, nothing else to do.
	if [ -z "$(who | awk "/console/ && /${assignUser}/")" ] || [ "$(ps ax | grep -c '[j]amf policy -event login')" -eq '0' ]; then
		"${jamfBinary}" recon -endUsername "${assignUser}" >/dev/null
		printf '%s %s. %s\n' 'Assigned to user:' "${assignUser}" 'Not logged in or not running login trigger.'
		exit 0
	fi
	
	# If they are logged in, write the user back to the JSS
	"${jamfBinary}" recon -endUsername "${assignUser}" >/dev/null
	
	# Validate they're still logged in, and generate a login event.
	if [ -n "$(who | awk "/console/ && /${assignUser}/")" ]; then
		printf '%s %s. %s\n' 'Assigned to user:' "${assignUser}" 'Login event generated.'
		printf '%s\n' "${assignUser}" >> "${loginFile}"
		exit 0
	fi
}

. "${modules}/start.sh"; start
Main 2>&1
finish