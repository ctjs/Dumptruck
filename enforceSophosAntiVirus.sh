#!/bin/bash

##### HEADER BEGINS #######################################################
#
# enforceSophosAntiVirus.sh
# 
# Created:  2014-06-18
# Modified: 2014-06-18
#
# jschripsema@expedia.com
#
# Priority: At Reboot
# Category: Applications - No SS
#
# Info: This script checks to see if Sophos AntiVirus is installed, running the custom event 'AVInstall' to kickoff the install policy if needed. It also checks for minimum versions and forces an update if needed.
#
# Three optional variable inputs:
#     minAppOrInstall: $4
#     minAppOrUpdate: $5
#     minDefOrUpdate: $6
#     
##### HEADER ENDS #########################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

############################## Get Variables ##############################

# The minimum version of the application. If not met, will trigger an install.
if [ -n "${4}" ]; then
	minAppOrInstall="${4}"
else
	minAppOrInstall=''
fi

# The minimum version of the application. If not met, will trigger an update.
if [ -n "${5}" ]; then
	minAppOrUpdate="${5}"
else
	minAppOrUpdate=''
fi

# The minimum version of the definitions. If not met, will trigger an update.
if [ -n "${6}" ]; then
	minDefOrUpdate="${6}"
else
	minDefOrUpdate=''
fi

########################### Required Functions ############################

# Compare version numbers.
versioncompare () {
	if [[ "${1}" == "${2}" ]]; then
		return 0 # =
	fi
	local IFS='.'
	local i version1=(${1}) version2=(${2})

	# fill empty fields in version1 with zeros
	for ((i="${#version1[@]}"; i<"${#version2[@]}"; i++)); do
		version1[i]=0
	done
   
	for ((i=0; i<"${#version1[@]}"; i++)); do
		if [[ -z "${version2[i]}" ]]; then
			# fill empty fields in version2 with zeros
			version2[i]=0
		fi
		if [ "${version1[i]}" -gt "${version2[i]}" ]; then
			return 1 # >
		fi
		if [ "${version1[i]}" -lt "${version2[i]}" ]; then
			return 2 # <
		fi
	done
	return 0 # =
}

############################## Begin Script ###############################

if [ -f '/Library/Sophos Anti-Virus/product-info.plist' ]; then
	appVersion="$( defaults read '/Library/Sophos Anti-Virus/product-info.plist' ProductVersion )"
elif [ -f '/Applications/Sophos Anti-Virus.app/Contents/Info.plist' ]; then
    appVersion="$( defaults read '/Applications/Sophos Anti-Virus.app/Contents/Info.plist' CFBundleShortVersionString )"
else
	appVersion='0'
fi

versioncompare "${appVersion}" "${minAppOrInstall}"
case "${?}" in
	0) # Versions are equal, do nothing.
		;;
	1) # Application version is greater than minimum. Do nothing.
		;;
	2) # Application version is less than minimum. Kickoff install policy.
		/usr/sbin/jamf policy -event AVInstall
		;;
	*) # Unknown error. Log and exit
		printf 'Error: %s %s\n' 'Unknown error with versioncompare function comparing app version with minimum or install. Function call was: ' "versioncompare \"${appVersion}\" \"${minAppOrInstall}\""
		;;
esac

versioncompare "${appVersion}" "${minAppOrUpdate}"
case "${?}" in
	0) # Versions are equal, do nothing.
		;;
	1) # Application version is greater than minimum. Do nothing.
		;;
	2) # Application version is less than minimum. Kickoff install policy.
		printf '%s' 'Application version too old. Running sophosupdate.'
		/usr/bin/sophosupdate &
		exit 0
		;;
	*) # Unknown error. Log and exit
		printf 'Error: %s %s\n' 'Unknown error with versioncompare function comparing app version with minimum or update. Function call was: ' "versioncompare \"${appVersion}\" \"${minAppOrUpdate}\""
		;;
esac

if [ -f "/usr/bin/sweep" ]; then
	sweepResult="$(/usr/bin/sweep -v)"
	defVersion="$(grep "Virus data version" <<< "${sweepResult}" | awk '{print $5}')"
#	defDate="$(/bin/date -j -f "%b %d %Y" "$(grep "Released"  <<< "${sweepResult}" | awk '{print $4, $3, $5}')" "+%Y-%m-%d")"
else
	defVersion='0'
#	defDate='Not installed'
fi

versioncompare "${defVersion}" "${minDefOrUpdate}"
case "${?}" in
	0) # Versions are equal, do nothing.
		;;
	1) # Application version is greater than minimum. Do nothing.
		;;
	2) # Application version is less than minimum. Kickoff install policy.
		printf '%s' 'Definitions version too old. Running sophosupdate.'
		/usr/bin/sophosupdate &
		exit 0
		;;
	*) # Unknown error. Log and exit
		printf 'Error: %s %s\n' 'Unknown error with versioncompare function comparing app version with minimum or update. Function call was: ' "versioncompare \"${appVersion}\" \"${minDefOrUpdate}\""
		;;
esac

exit 0