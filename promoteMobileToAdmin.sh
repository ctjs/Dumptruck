#!/bin/bash

##### HEADER BEGINS #####
#
# promoteMobileToAdmin.sh
# 
# Created:  2014-05-15
# Modified: 2014-05-15
#
# jschripsema@expedia.com
#
# Priority: After
# Category: User Accounts - No SS
#
# This script will promote all "mobile" users to administrators.
#
##### HEADER ENDS #####

userArray=()
while read line; do
	userArray+=("${line}")
done <<< "$(jamf listUsers | awk -F '[<>]' '/<name>/ { print $3 }')"

for i in "${userArray[@]}"; do
	i="$(tr '[:upper:]' '[:lower:]' <<< "${i}")"

	# Check to see if it is a domain/mobile account.
	if [ "$(dscl . -read /Users/${i} AuthenticationAuthority | grep -ic 'LocalCachedUser')" -gt '0' ]; then
		/usr/sbin/dseditgroup -o edit -a "${i}" -t user admin
	fi
done