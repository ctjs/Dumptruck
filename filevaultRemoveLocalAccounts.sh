#!/bin/bash

####################################################################################
#
# filevaultRemoveLocalAccounts.sh
# 
# Created:  2014-05-08
# Modified: 2014-07-07
#
# jschripsema@expedia.com
#
# Priority: Before
# Category: User Accounts - No SS
#
# This script removes all local users, other than 'administrator', from FileVault.
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

# Make an array of all the FileVault enabled users.
userArray=()
while read line; do
	[ -z "${line}" ] && continue
	userArray+=("${line}")
done <<< "$(fdesetup list | cut -d, -f1)"

# A list of local users and mobile users.
localUserArray=()
mobileUserArray=()
for i in "${userArray[@]}"; do
    # Ignore case.
	i=$(tr '[:upper:]' '[:lower:]' <<< "${i}")
	# Ignore administrator
	[ "${i}" == 'administrator' ] && continue
	
	# Add this account to be removed if it is a non-mobile account.
	if [ "$(dscl . -read /Users/${i} AuthenticationAuthority | grep -ic 'LocalCachedUser')" -gt '0' ]; then
		mobileUserArray+=("${i}")
	else
		localUserArray+=("${i}")
	fi
done

if [ "${#mobileUserArray[@]}" -gt '0' ]; then
	for i in "${localUserArray[@]}"; do
		fdesetup remove -verbose -user "${i}"
		printf '%s %s\n' 'Disabled local user:' "${i}"
	done
	exit 0
else
	printf '%s\n' 'Error: No mobile accounts are FileVault enabled.'
	exit 1
fi