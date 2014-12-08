#!/bin/bash

####################################################################################
#
# reimageDisk.sh
# 
# Created:  2014-09-15
# Modified: 2014-09-15
#
# jschripsema@expedia.com
#
# This script needs to be run using 'Casper Imaging.app'. This will flatten the
# drive and then use the ASR command to restore from the web CasperShare.
#
# To-Do: Pop up a dialog if the latest ASR has multiple builds.
#
# Priority: Before
# Category: Operating System - No SS
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

# The version compare function, used to determine latest ASR.
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

# Flatten the disk.
diskutil partitionDisk "/dev/disk0" 1 gpt jhfs+ "Macintosh HD" 100%

# Determine JDS server in use.
httpLocation="$(df 2>/dev/null | awk -F/ '/CasperShareDAV/ && /http/ { print $1"/"$2"/"$3 }')"

# Determine latest ASR.
latestVersion='0'
asrArray=('/Volumes/CasperShareDAV/m_'*'_asr.dmg')
for i in "${asrArray[@]}"; do
	iVersion="$(awk -F '_' ' { print $2 }' <<< "${i}")"
	versioncompare "${latestVersion}" "${iVersion}"
	if [ "${?}" -eq '2' ]; then
		latestVersion="${iVersion}"
	fi
done

# ASR restore.
asr restore --source "${httpLocation}/CasperShare/m_${latestVersion}_asr.dmg" --target /dev/disk0s2 --erase --noprompt

# Ensure .AppleSetupDone is created.
for i in "/Volumes/"*; do
    if [ -d "${i}/private/var/db/" ]; then
        /usr/bin/touch "${i}/private/var/db/.AppleSetupDone"
    fi
done