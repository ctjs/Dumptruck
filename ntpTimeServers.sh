#!/bin/bash

##### HEADER BEGINS #####
#
# ntpTimeServers.sh
#
# Created 20140428 by Joshua Schripsema
# jschripsema@expedia.com
# Modified 20140428 by Joshua Schripsema
#
# Priority: After
# Category: Management Tools - No SS
#
# This script will take a specified list of time servers, sort the list by ping time,
# "closest" ones first, and set the machine up to use network time. If it cannot contact
# any specified server, it will not make any changes to the local machine.
#
# Variable Inputs:
# $1 - mountPoint, auto-passed by Casper Suite.
# $2 - computerName, auto-passed by Casper Suite.
# $3 - username, auto-passed by Casper Suite.
#
##### HEADER ENDS #####


# List of available NTP Servers
ntpArray=()
ntpArray+=('10.128.55.30') # Dublin
ntpArray+=('10.185.42.35') # Chandler
ntpArray+=('10.203.0.80') # Phoenix

# Lab Infoblox
labInfoblox='10.111.1.81'

# Fallback to Apple's NTP server.
ntpFallback='time.apple.com'

# Port number for NTP
ntpPort='123'

# A very large number used for sorting if can't reach the server.
inaccessiblePing='10000000000'
serverAvailable='0'

# The ntp.conf file.
ntpConfFile='/private/etc/ntp.conf'

# Check to see if the lab infoblox server is available.
nc -z -G 2 "${labInfoblox}" "${ntpPort}"
if [ "${?}" -ne '0' ]; then
	labInfoblox=''
else
	serverAvailable='1'
fi

# Make an array of ping values prepended to the IP addresses.
pingArray=()
for i in "${ntpArray[@]}"; do
	pingResult=$(ping -c 3 -q "${i}"); pingExit=$?
	if [ "${pingExit}" -ne '0' ]; then
		pingArray+=("${inaccessiblePing} ${i}")
	else
		serverAvailable='1'
		pingArray+=("$(printf '%s' "${pingResult}" | tail -1 | awk -F '/' '{ print $5 }') ${i}")
	fi
done

# Check to see if at least one server was reachable.
if [ "${serverAvailable}" -eq '0' ]; then
	# No servers available, not resetting NTP order.
	echo 'No time servers were reachable. No settings were changed.'
	exit 1
fi

# Tack the lab infoblox server on the front if it is available.
if [ -n "${labInfoblox}" ]; then
	ntpArray=("${labInfoblox}")
else
	ntpArray=()
fi

# Sort the array, removing the ping value, and write it back to the ntpArray.
ntpArray+=($(for i in "${pingArray[@]}";
	do echo "${i}"
done | sort -n | awk '{ print $NF }'))

# Tack the fallback address on the end.
if [ -n "${ntpFallback}" ]; then
	ntpArray+=("${ntpFallback}")
fi

# Set the time servers.
for i in "${ntpArray[@]}"; do
	if [ "${i}" == "${ntpArray[0]}" ]; then
		/usr/sbin/systemsetup -setnetworktimeserver "${i}"
	else
		printf 'server %s\n' "${i}" >> "${ntpConfFile}"
	fi
done

# Turn on network time synchronization and update the time.
launchctl load -w /System/Library/LaunchDaemons/org.ntp.ntpd.plist
/usr/sbin/ntpd -g -q