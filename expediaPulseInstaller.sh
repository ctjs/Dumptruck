#!/bin/bash

##########################################################################################
#
# expediaPulseInstaller.sh
# 
# Created:  2014-06-23
# Modified: 2014-11-10
# Version:  1.31
#
# jschripsema@expedia.com
#
# This script prompts to install the pulse configuration that is desired. As part
# of this, it does verify that the Junos Pulse.app application is installed. If it
# isn't, it will run the custom policy event 'pulseInstall'.
#
# Relies on special comments in the configurations to determine behavior:
# ; Name : <name>
#     The <name> must be unique to a given profile. Displayed in the drop-down field.
# ; Description: <description>
#     <description> of the profile. Displayed below the drop-down field.
# ; Group Membership: <group names>, <separated>, <by>, <commas>
#     A list of comma-separated <group names>. If any of them match a group name
#     that the user belonged to at the time of the last group crawl (typically last
#     JAMF recon while on the corporate network), it will display this profile as
#     available. However, if you pre-pend ^ to the group name, this will be
#     evaluated as "not" this group. These are evaluated sequentially, last matching
#     group overrides previous value. Case sensitive. Special groups 'All' and '^All',
#     will always match.
#
# Priority: Before
# Category: Network/VPN - No SS
#
##########################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

# Define temporary file locations.
tempConfig="/tmp/expediaPulseConfig${RANDOM}.jnprpreconfig"

# Define static locations.
cocoaDialogApp='/usr/local/bin/cocoaDialog'
jamfBinary='/usr/sbin/jamf'
jamCommand='/Applications/Junos Pulse.app/Contents/Plugins/JamUI/jamCommand'
groupMembershipCache='/Library/Application Support/JAMF/Receipts/GroupMembershipCache'
groupCacheKerberosFolder='/Library/Application Support/JAMF/Receipts/GroupMembershipKerberosCache'

# Define the configurations.
pulseConfigurationArray=()

############################### Connect Using Credentials ################################

pulseConfigurationArray+=('; Name: SEA Credentials
; Description: Allows you to connect to the Expedia network using your SEA domain username and password.
; Group Membership: All, ^Production Datacenter Users Security

schema version {
    version: "1"
}

machine settings {
    version: "16"
    guid: "87fe0cdc-1638-4dca-8e97-6b1510e008ec"
    connection-source: "preconfig"
    server-id: "3313f3e8-6150-4ca2-b95d-bc7be0b69aae"
    allow-save: "false"
    user-connection: "true"
    splashscreen-display: "false"
    dynamic-trust: "true"
    dynamic-connection: "false"
    wireless-suppression: "false"
}

ive "072cb70c-a303-4fd7-95ae-4161a324d1c3" {
    friendly-name: "SEA Credentials"
    version: "3"
    guid: "072cb70c-a303-4fd7-95ae-4161a324d1c3"
    server-id: "3313f3e8-6150-4ca2-b95d-bc7be0b69aae"
    connection-source: "preconfig"
    connection-policy-override: "true"
    use-for-secure-meetings: "false"
    use-for-connect: "true"
    this-server: "false"
    uri: "vpn.expedia.biz"
    connection-identity: "user"
    client-certificate-location-system: "false"
}')

################################ Connect Using Two-Factor ################################

pulseConfigurationArray+=('; Name: Connect Using Two-Factor
; Description: Allows you to connect to the Expedia network using your SEA domain username and password along with a token or a certificate. Please see https://trail.expedia.biz/selfserve for information on obtaining a token. If you do not have a certificate, you can generate one while on the Expedia network, in the office, by using the Self Service policy "Generate Certificate".
; Group Membership: All

schema version {
    version: "1"
}

machine settings {
    version: "16"
    guid: "87fe0cdc-1638-4dca-8e97-6b1510e008ec"
    connection-source: "preconfig"
    server-id: "3313f3e8-6150-4ca2-b95d-bc7be0b69aae"
    allow-save: "false"
    user-connection: "true"
    splashscreen-display: "false"
    dynamic-trust: "true"
    dynamic-connection: "false"
    wireless-suppression: "false"
}

ive "7dc4760e-42b6-4f60-9ae4-c93ab43fb2da" {
    friendly-name: "Two Factor - Certificate"
    version: "3"
    guid: "7dc4760e-42b6-4f60-9ae4-c93ab43fb2da"
    server-id: "3313f3e8-6150-4ca2-b95d-bc7be0b69aae"
    connection-source: "preconfig"
    connection-policy-override: "true"
    use-for-secure-meetings: "false"
    use-for-connect: "true"
    this-server: "false"
    uri: "vpn.expedia.biz/cert"
    connection-identity: "user"
    client-certificate-location-system: "false"
}

ive "7d1efa93-3e19-40ec-9090-3d4be8f03a44" {
    friendly-name: "Two Factor - Token"
    version: "4"
    guid: "7d1efa93-3e19-40ec-9090-3d4be8f03a44"
    server-id: "3313f3e8-6150-4ca2-b95d-bc7be0b69aae"
    connection-source: "preconfig"
    connection-policy-override: "true"
    use-for-secure-meetings: "false"
    use-for-connect: "true"
    this-server: "false"
    uri: "vpn.expedia.biz/token"
    connection-identity: "user"
    client-certificate-location-system: "false"
}')

##################################### SmartConnect ######################################

pulseConfigurationArray+=('; Name: SmartConnect
; Description: Allows you to dynamically and transparently connect to the Expedia corporate network on an as needed basis when corporate resources are accessed. This does require that you have a certificate installed on your machine. If you do not have a certificate, you can generate one while on the Expedia network, in the office or on VPN using a different configuration, by using the Self Service policy "Generate Certificate".
; Group Membership: ^All, eIT All, Corporate_Technology_Engineering, EIS_Operations_Team, jss_tech_services, ^Production Datacenter Users Security

schema version {
    version: "1"
}

machine settings {
    version: "89"
    guid: "feaa2b1d-3d24-4cfe-8e02-aba6282158e2"
    connection-source: "preconfig"
    server-id: "0284M6RC10FWV1O7S"
    allow-save: "false"
    user-connection: "true"
    splashscreen-display: "false"
    dynamic-trust: "true"
    dynamic-connection: "true"
    FIPSClient: "false"
    wireless-suppression: "false"
}

ive "57e689a9-2569-46f7-a337-86e60720a637" {
    friendly-name: "Smart Connect"
    version: "61"
    guid: "57e689a9-2569-46f7-a337-86e60720a637"
    server-id: "0284M6RC10FWV1O7S"
    connection-source: "preconfig"
    connection-policy-override: "true"
    use-for-secure-meetings: "false"
    use-for-connect: "true"
    this-server: "false"
    uri: "https://smartconnect.expedia.biz/alwayson"
    connection-identity: "user"
    connection-policy: " not dns-server(physical, 172.30.217.49 172.30.217.47 172.30.217.45 172.30.217.48 172.30.217.46 172.16.216.115 172.17.70.12 172.17.70.13 10.184.77.33 10.184.77.34 10.184.77.25 10.184.77.23 10.184.77.24 10.184.134.31 10.184.77.29 10.184.77.26 10.184.77.20 10.184.1.166 10.184.1.167 172.16.2.10 10.128.48.8 10.128.48.12 172.26.58.50 172.20.17.90 172.16.224.62 172.16.224.61 172.16.210.59 172.21.170.14 172.21.170.5 172.21.37.10 172.16.220.106 172.21.47.16 172.31.9.13 172.31.9.12 172.20.32.165 10.203.224.22 10.203.224.23 172.21.17.88 172.21.60.9 172.17.16.84 172.17.16.80 172.17.16.87 172.19.0.166 172.19.129.20 172.26.141.40 172.26.128.166 172.31.197.51 172.31.197.52 172.16.236.100 172.16.232.114 172.16.232.115 172.16.228.45)"
    client-certificate-location-system: "false"
}')

############################### SmartConnect Connect using SEA Credentials ################################

pulseConfigurationArray+=('; Name: SmartConnect using SEA Credentials
; Description: Allows you to connect to the Expedia network using your SEA domain username and password.
; Group Membership: ^All, eIT All, Corporate_Technology_Engineering, EIS_Operations_Team, jss_tech_services, ^Production Datacenter Users Security

schema version {
    version: "1"
}

machine settings {
    version: "22"
    guid: "c23b9547-2175-43d8-8091-bcbddcc9e08a"
    connection-source: "preconfig"
    server-id: "aa82557d-ba9e-4f03-9d47-ae9185daf7d4"
    allow-save: "false"
    user-connection: "true"
    splashscreen-display: "false"
    dynamic-trust: "true"
    dynamic-connection: "true"
    FIPSClient: "false"
    wireless-suppression: "false"
}

ive "8f0fefd6-f4e2-430e-80c6-bda77d53ad51" {
    friendly-name: "SmartConnect for Personal Machines"
    version: "12"
    guid: "8f0fefd6-f4e2-430e-80c6-bda77d53ad51"
    server-id: "aa82557d-ba9e-4f03-9d47-ae9185daf7d4"
    connection-source: "preconfig"
    connection-policy-override: "true"
    use-for-secure-meetings: "false"
    use-for-connect: "true"
    this-server: "false"
    uri: "https://smartconnect.expedia.biz/byod"
    connection-identity: "user"
    client-certificate-location-system: "false"
}')

################################ SmartConnect Connect Using Two-Factor ################################

pulseConfigurationArray+=('; Name: SmartConnect Connect Using Two-Factor
; Description: Allows you to connect to the Expedia network using your SEA domain username and password along with a token or a certificate. Please see https://trail.expedia.biz/selfserve for information on obtaining a token. If you do not have a certificate, you can generate one while on the Expedia network, in the office, by using the Self Service policy "Generate Certificate".
; Group Membership: ^All, eIT All, Corporate_Technology_Engineering, EIS_Operations_Team, jss_tech_services

schema version {
    version: "1"
}

machine settings {
    version: "38"
    guid: "41e20235-6e5c-45cd-838a-9694ed44ebc1"
    connection-source: "preconfig"
    server-id: "aa82557d-ba9e-4f03-9d47-ae9185daf7d4"
    allow-save: "false"
    user-connection: "true"
    splashscreen-display: "false"
    dynamic-trust: "true"
    dynamic-connection: "true"
    FIPSClient: "false"
    wireless-suppression: "false"
}

ive "23982edb-8902-4600-bf71-7e9a4c221f76" {
    friendly-name: "Two Factor - Certificate"
    version: "7"
    guid: "23982edb-8902-4600-bf71-7e9a4c221f76"
    server-id: "aa82557d-ba9e-4f03-9d47-ae9185daf7d4"
    connection-source: "preconfig"
    connection-policy-override: "true"
    use-for-secure-meetings: "false"
    use-for-connect: "true"
    this-server: "false"
    uri: "https://smartconnect.expedia.biz/cert"
    connection-identity: "user"
    client-certificate-location-system: "false"
}

ive "91ec4cfb-9003-46c9-bf7f-f57dcb74832e" {
    friendly-name: "Two Factor - Token"
    version: "2"
    guid: "91ec4cfb-9003-46c9-bf7f-f57dcb74832e"
    server-id: "aa82557d-ba9e-4f03-9d47-ae9185daf7d4"
    connection-source: "preconfig"
    connection-policy-override: "true"
    use-for-secure-meetings: "false"
    use-for-connect: "true"
    this-server: "false"
    uri: "https://smartconnect.expedia.biz/token"
    connection-identity: "user"
    client-certificate-location-system: "false"
}')

##################################### Script Begins ######################################

# Build an array of the names based on group membership.
configurationNames=()
for i in "${pulseConfigurationArray[@]}"; do
	# Get the comma-separated group string.
	configGroups="$(awk -F'; Group Membership: ' '/; Group Membership: / { print $NF; exit }' <<< "${i}")"
	# Default to not showing any profile, unless matches.
	addItem='false'
	# Convert comma-separated to newline separated.
	# 'read' in each line, which strips off leading and trailing whitespace.
	while read line; do
		# Always match 'All', otherwise evaluate if group is in groupMembershipCache.
		if [ "${line}" == 'All' ] || [ -f "${groupMembershipCache}/${line}" ] || [ -f "${groupCacheKerberosFolder}/${line}" ]; then
			addItem='true'
			continue
		fi
		# Always match '^All', otherwise evaluate if group is in groupMembershipCache.
		if [ "${line::1}" == '^' ] && [ "${line}" == '^All' -o -f "${groupMembershipCache}/$(cut -c 2- <<< ${line})" -o -f "${groupCacheKerberosFolder}/$(cut -c 2- <<< ${line})" ]; then
			addItem='false'
			continue
		fi
	done <<< "$(tr ',' '\n' <<< "${configGroups}")"
	# If false, check next configuration item.
	[ "${addItem}" == 'false' ] && continue
	# Otherwise, copy in the name.
	configurationNames+=("$(awk -F'; Name: ' '/; Name: / { print $NF; exit }' <<< "${i}")")
done

# Determine action based on number of available configurations.
case "${#configurationNames[@]}" in
	0) # If no available configurations, display an error and exit.
		printf '%s\n' "No available configurations. Exiting."
		"${cocoaDialogApp}" msgbox --title 'Error Occurred' --text 'An error occurred.' --label 'Please update your inventory information, while on the corporate network, and try again.' --icon 'notice' --button1 'Okay' > /dev/null &
		exit 0
		;;
	1) # If only one available configuration, automatically select that one.
		for i in "${pulseConfigurationArray[@]}"; do
			if [ -n "$(grep -o -m 1 "; Name: ${configurationNames[0]}" <<< "${i}")" ]; then
				selectedConfig="${i}"
				buttonClicked='1'
				break
			fi
		done
		;;
	*) # Multiple options. Set the defaults for nameArray and buttonClicked so that no choice has been made.
		nameArray=("${configurationNames[@]}")
		buttonClicked='4'
		;;
esac

# While there are options, loop the choose your configuration dialog.
while [ "${buttonClicked}" -eq '4' ]; do
	# Get the dialogText
	for i in "${pulseConfigurationArray[@]}"; do
		if [ -n "$(grep -o -m 1 "; Name: ${nameArray[0]}" <<< "${i}")" ]; then
			dialogText="$(awk -F'; Description: ' '/; Description: / { print $NF; exit }' <<< "${i}")"
			dialogPadding="$(echo "(${#dialogText}*1.2)/1" | bc)"
			break
		fi
	done
	
	# Pad the dialog text so it displays properly, cocoaDialog bug with dropdown options.
	while [ "${#dialogText}" -lt "${dialogPadding}" ]; do
		dialogText="${dialogText}^                                                  "
	done
	
	# Display the dialog.
	temp="$("${cocoaDialogApp}" standard-dropdown --title 'Choose VPN Configuration' --text "$(tr '^' '\n' <<< "^^^^${dialogText} ")" --exit-onchange --items "${nameArray[@]}")"
	# Determine which button was clicked and which selection was made.
	buttonClicked="$(head -n 1 <<< "${temp}")"
	currentSelection="$(tail -n 1 <<< "${temp}")"
	
	case "${buttonClicked}" in
		4) # If no choice was made, build a new nameArray.
			nameArray=("${nameArray["${currentSelection}"]}")
			for i in "${configurationNames[@]}"; do
				[ "${i}" != "${nameArray["0"]}" ] && nameArray+=("${i}")
			done
			;;
		2) # If 'cancel' was chosen, exit out.
			printf '%s\n' "User Cancelled"
			exit 0
			;;
		1) # If 'ok' was chosen, set the selectedConfig and continue.
			for i in "${pulseConfigurationArray[@]}"; do
				if [ -n "$(grep -o -m 1 "; Name: ${nameArray[0]}" <<< "${i}")" ]; then
					selectedConfig="${i}"
					break
				fi
			done
			;;
		*) # Unknown return, exit out.
			printf '%s\n' "Unknown option chosen. Exiting."
			"${cocoaDialogApp}" msgbox --title 'Error Occurred' --text 'An error occurred.' --label 'Please update your inventory information, while on the corporate network, and try again.' --icon 'notice' --button1 'Okay' > /dev/null &
			exit 0
			;;
	esac
done

# Write the configuration file.
printf '%s' "${selectedConfig}" > "${tempConfig}"

# If the application is already installed, import the configuration. Otherwise, trigger
# an install via a policy 'event' (Casper 9+ only).
if [ -f "${jamCommand}" ] ; then
	"${jamCommand}" -importFile "${tempConfig}"
	printf '%s\n' 'Pulse Client Already Installed. Configuration Imported.'
else
	"${jamfBinary}" policy -event pulseInstall
	if [ ! -f "${jamCommand}" ]; then
		printf '%s\n' 'Pulse Client Installation Failed'
		rm -f "${tempConfig}"
		exit 1
	fi
	"${jamCommand}" -importFile "${tempConfig}"
	printf '%s\n' 'Pulse Client Installed. Configuration Imported.'
fi

# Notify the user.
"${cocoaDialogApp}" msgbox --title 'Installation Finished' --text 'VPN successfully installed and configured.' --label "Your VPN software was successfully installed and configured with configuration: $(awk -F'; Name: ' '/; Name: / { print $NF; exit }' <<< "${selectedConfig}")." --icon 'notice' --button1 'Okay' > /dev/null &

# Cleanup
rm -f "${tempConfig}"
exit 0