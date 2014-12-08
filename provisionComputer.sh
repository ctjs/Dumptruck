#!/bin/bash

####################################################################################
#
# provisionComputer.sh
# 
# Created:  2014-04-15
# Modified: 2014-04-15
#
# jschripsema@expedia.com
#
# This script interactively names a computer, binds it to the domain, sets the
# assigned user, and sets up FileVault 2. It can be run automatically, not
# not requiring any interactivity, if both optional values are set. Otherwise, it
# will prompt for any required information. This script is very site specific and
# relies on the following jamf custom events to be setup and functional:
#     ADBind - Binds the machine.
#     ADUnbind - Unbinds the machine, removes computer record.
#     FVEnable - Enables FileVault 2. Also installs a LaunchDaemon which kicks off
#         FVEnableEncrypt - Enables the 'Encrypt' user account for FileVault 2.
#
# Priority: After
#
# Two optional variable inputs:
#     computerName: $4
#     endUsername: $5
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

# Build the site code array.
siteCodeArray=()
siteCodeArray+=('Bangkok - BAN')
siteCodeArray+=('Barcelona - BCN')
siteCodeArray+=('Beijing - BEI')
siteCodeArray+=('Bellevue - BEL')
siteCodeArray+=('Berlin - BER')
siteCodeArray+=('Brazil - BRZ')
siteCodeArray+=('Brussels - BRU')
siteCodeArray+=('Cancun - CCC')
siteCodeArray+=('Chandler - CHC')
siteCodeArray+=('Chicago - ORD')
siteCodeArray+=('Dallas - DAL')
siteCodeArray+=('Denver - DEN')
siteCodeArray+=('Detroit - DTW')
siteCodeArray+=('Dublin - DUB')
siteCodeArray+=('Fort Lauderdale - FLL')
siteCodeArray+=('Geneva - GEN')
siteCodeArray+=('Glacier Park - FCA')
siteCodeArray+=('Gurgaon - DEL')
siteCodeArray+=('Hong Kong - HKG')
siteCodeArray+=('Jemmapes - QDJ')
siteCodeArray+=('Kuala Lumpur - KUL')
siteCodeArray+=('Las Vegas - CCX')
siteCodeArray+=('Lille - LIL')
siteCodeArray+=('London - LON')
siteCodeArray+=('Lyon - LYS')
siteCodeArray+=('Madrid - MAD')
siteCodeArray+=('Manchester - MHT')
siteCodeArray+=('Marseille - MRS')
siteCodeArray+=('Mexico - MEX')
siteCodeArray+=('Milan - MIL')
siteCodeArray+=('Minneapolis - MSP')
siteCodeArray+=('Mississauga - MIS')
siteCodeArray+=('Montreal - YUL')
siteCodeArray+=('Munich (Egencia) - MUC')
siteCodeArray+=('Munich - MUC')
siteCodeArray+=('Nantes - NTE')
siteCodeArray+=('Newark - EWR')
siteCodeArray+=('Orlando - ORL')
siteCodeArray+=('Paris - PAR')
siteCodeArray+=('Post Falls - IAD')
siteCodeArray+=('Prague - PRG')
siteCodeArray+=('Rome - ROM')
siteCodeArray+=('San Francisco - SFO')
siteCodeArray+=('San Jose - SJC')
siteCodeArray+=('Shanghai - SHA')
siteCodeArray+=('Shenzhen - SZE')
siteCodeArray+=('Singapore - SIN')
siteCodeArray+=('Springfield - SGF')
siteCodeArray+=('Sydney - SYD')
siteCodeArray+=('Tokyo - TOK')
siteCodeArray+=('Toronto - YYZ')
siteCodeArray+=('Tourcoing - TCG')
siteCodeArray+=('Vancouver - YVR')

# Determine if drive is encrypted.
eGrepString=''
csDeviceCount="$(diskutil cs list | awk -F '[ ()]' '/^CoreStorage logical volume groups/ {print $6}')"
if [ "${csDeviceCount}" -ne '1' ]; then
	eGrepString="^\| *"
fi
encryptionExtents="$(diskutil cs list | grep -E "${eGrepString}\Has Encrypted Extents" | sed -e's/\|//' | awk '{print $4}')"

cocoaDialogApp='/usr/local/bin/cocoaDialog'
jamfBinary='/usr/sbin/jamf'
expediaPlist='/Library/Preferences/com.expedia.jamf'
tempFile="/tmp/provisionTemp${RANDOM}.plist"

# The function used to determine if actively able to poll AD with a given username.
function checkMembership {
	id "${1}" 1> /dev/null
	result="${?}"
	echo "${result}"; return "${result}"
}

# This function returns the computer name from the local Active Directory record.
# Returns empty computer name if not set.
function getComputerName {
	local computerName
	# Dump config info to a temp file.
	dsconfigad -show -xml >> "${tempFile}"
	
	computerName="$(/usr/libexec/PlistBuddy -c "Print :General\ Info:Computer\ Account" "${tempFile}")"
	if [ "${?}" -ne '0' ]; then
		computerName=''
	else
		computerName="$(tr '[:lower:]' '[:upper:]' <<< ${computerName} | tr -d '$')"
	fi
	
	# Clean up and return the computer name.
	rm -f "${tempFile}"
	echo "${computerName}"; return 0
}



# Gather the server address to check if available.
if [ -n "${4}" ]; then
	computerName="${4}"
	autoRebind='1'
else
	unset computerName
	autoRebind='0'
fi

# Gather the server port to check if available.
if [ -n "${5}" ] && [ "$(checkMembership "${5}")" -eq '0' ]; then
	endUsername="${5}"
	autoAssign='1'
else
	unset endUsername
	autoAssign='0'
fi

# Check for some required files.
if [ ! -f "${jamfBinary}" ]; then
	printf 'JAMF Binary not installed in %s. Unable to continue.\n' "${jamfBinary}"
	exit 2
fi
if [ ! -f "${cocoaDialogApp}" ]; then
	if [ "${autoRebind}" -eq '0' ] || [ "${autoAssign}" -eq '0' ]; then
		printf 'Unable to find cocoaDialog in %s. Not completely automated install. Unable to continue.\n' "${cocoaDialogApp}"
		exit 2
	else
		printf 'Unable to find cocoaDialog in %s. Completely automated install.\n' "${cocoaDialogApp}"
		unset cocoaDialogApp
	fi
fi

# Check to see if we're automatically rebinding the machine.
if [ "${autoRebind}" -gt '0' ]; then
	# Computer name provided. Change if necessary.
	if [ "${computerName}" != "$(getComputerName)" ]; then
		"${jamfBinary}" policy -event 'ADUnbind'
		"${jamfBinary}" setComputerName -name "${computerName}"
		"${jamfBinary}" policy -event 'ADBind'
		computerName="$(getComputerName)"
	fi
else
	# Get the existing AD computer name.
	computerName="$(getComputerName)"
	# If already bound, prompt to unbind.
	if [ -n "${computerName}" ]; then
		temp="$("${cocoaDialogApp}" yesno-msgbox --title 'Bound to Active Directory' --text "Bound as '${computerName}'" --informative-text "This computer is already bound to Active Directory. Would you like to change the binding name?" --no-cancel --float)"
		if [ "${temp}" -eq '1' ]; then
			"${jamfBinary}" policy -event 'ADUnbind'
			computerName="$(getComputerName)"
		fi
	fi
fi

unset siteCode
customCode=''
# Determine a valid site code if setting the computer name.
while [ -z "${siteCode}" ] && [ -z "${computerName}" ]; do
	# Prompting for a custom code, or dropdown?
	if [ -n "${customCode}" ]; then
		temp="$("${cocoaDialogApp}" inputbox --title 'Site/Airport Code' --informative-text 'Enter the site/airport code this computer will be deployed to. Do *not* use this to deploy using non-standard site codes.' --button1 'Ok' --button2 'Cancel' --button3 'Show Me Options' --float)"
		button="$(head -n 1 <<< "${temp}")"
		case "${button}" in
			1)
				siteCode="$(tail -n 1 <<< "${temp}" | tr -cd '[:alpha:]' | tr '[:lower:]' '[:upper:]')"
				if [ "${#siteCode}" -ne '3' ] && [ -n "${customCode}" ]; then
					"${cocoaDialogApp}" ok-msgbox --title 'Invalid Site/Airport Code' --text "Invalid Site/Airport Code: ${siteCode}" --informative-text "Site code specified does not meet the requirements. Please try again." --icon 'x' --no-cancel --float
					siteCode=''
				else
					customCode="${siteCode}"
				fi
			;;
			2)
				echo 'Operation Cancelled'
				exit 0
			;;
			3)
				customCode=''
			;;	
		esac
	else
		temp="$("${cocoaDialogApp}" dropdown --title 'Site/Airport Code' --text "$(tr '^' '\n' <<< "^^^^Choose the site/airport code this computer will be deployed to.")" --items "${siteCodeArray[@]}" --button1 'Ok' --button2 'Cancel' --button3 'Other' --float)"
		button="$(head -n 1 <<< "${temp}")"
		case "${button}" in
			1)
				siteCode="$(awk '{ print $NF }' <<< "${siteCodeArray["$(tail -n 1 <<< "${temp}")"]}" | tr '[:lower:]' '[:upper:]')"
			;;
			2)
				echo 'Operation Cancelled'
				exit 0
			;;
			3)
				customCode='1'
			;;	
		esac
	fi
	
done

# If no computer name setup, create a valid computer name.
if [ -z "${computerName}" ]; then
	serialNumber="$(ioreg -c IOPlatformExpertDevice -d 2 | awk '/IOPlatformSerialNumber/ { print $NF }' | tr -d '"' | tr '[:lower:]' '[:upper:]')"
	computerName="$(printf '%s%s' "${siteCode}" "${serialNumber}" | cut -c 1-15 | tr -cd '[:alnum:]')"
	"${jamfBinary}" setComputerName -name "${computerName}"
	"${jamfBinary}" policy -event 'ADBind'
fi

# Make sure the computer is able to communicate with AD before continuing.
if [ "$(checkMembership 's-deploy')" -ne '0' ]; then
	echo 'Unable to communicate with AD. Exiting.'
	exit 1
fi

# Write the computer name to a couple locations for future reference.
printf '%s' "${computerName}" > /Library/Receipts/cname.txt
defaults write "${expediaPlist}" ComputerName -string "${computerName}"
if [ -n "${customCode}" ]; then
	defaults write "${expediaPlist}" CustomSiteCode -string "${customCode}"
else
	defaults delete "${expediaPlist}" CustomSiteCode 2> /dev/null
fi

# Prompt for a valid username to assign this computer to.
while [ -z "${endUsername}" ]; do
	temp="$("${cocoaDialogApp}" standard-inputbox --title 'Assigned Username' --informative-text 'Enter the assigned username this computer will be deployed to:' --float)"
	button="$(head -n 1 <<< "${temp}")"
	if [ "${button}" -ne '1' ]; then
		echo 'Operation Cancelled'
		exit 0
	fi
	endUsername="$(tail -n 1 <<< "${temp}")"
	if [ "$(checkMembership "${endUsername}")" -ne '0' ]; then
		if [ "$(checkMembership 's-deploy')" -ne '0' ]; then
			"${cocoaDialogApp}" ok-msgbox --title 'Error Validating Username' --text "Error Validating Username: ${endUsername}" --informative-text 'Lost contact with Active Directory while attempting to validate username. Please try again later.' --icon 'x' --no-cancel --float
			echo 'Unable to communicate with AD. Exiting.'
			exit 1
		else
			"${cocoaDialogApp}" ok-msgbox --title 'Invalid Username' --text "Invalid Username: ${endUsername}" --informative-text 'Unable to retrieve information for provided username. Please verify and try again.' --icon 'x' --no-cancel --float
			endUsername=''
		fi
	fi
done

# Write the assigned username for future reference.
defaults write "${expediaPlist}" AssignedUsername -string "${endUsername}"

# Grab the uid and gid values for the endUsername.
endUsernameUID="$(id -u "${endUsername}")"
endUsernameGID="$(id -g "${endUsername}")"

# Fix ownership on the user's directory if it already exists.
if [ -d "/Users/${endUsername}" ] && [ "${endUsernameUID}" -gt '1000' ] && [ "${endUsernameGID}" -gt '1000' ]; then
	chown -R  "${endUsernameUID}:${endUsernameGID}" "/Users/${endUsername}"
fi

# If cocoaDialog is available, display an informative dialog.
if [ -n "${cocoaDialogApp}" ]; then
	"${cocoaDialogApp}" ok-msgbox --title 'Enabling Encryption' --text "Setting Up FileVault 2" --informative-text 'Finishing up some last minute tasks and then setting up FileVault 2. If the machine needs to be encrypted, it should reboot shortly. Please login to the "Administrator" account to finalize setup.' --no-cancel --float &
fi

# Enable FileVault 2
"${jamfBinary}" policy -event 'FVEnable'

# Add this user to the 'admin' group.
/usr/sbin/dseditgroup -o edit -a "${endUsername}" -t user admin

# Finish up by doing a final Recon and write the username to the JSS.
"${jamfBinary}" recon -endUsername "${endUsername}"

# Remove the informative dialog.
if [ -n "${cocoaDialogApp}" ]; then
	killall "$(basename "${cocoaDialogApp}")"
fi

# Check if already encrypted with FileVault 2.
if [ "${encryptionExtents}" == 'Yes' ]; then
	if [ -n "${cocoaDialogApp}" ]; then
		"${cocoaDialogApp}" ok-msgbox --title 'FileVault Encryption' --text "FileVault 2 Encryption Appears to Be Enabled" --informative-text 'Either FileVault 2 is already enabled, or some other issue prevented automatic enabling of encryption. Attempting to add assigned user to the list of FileVault 2 enabled users. Please verify that it is setup correctly and manually remediate if necessary.' --icon 'x' --no-cancel --float &
	fi
	launchctl load /Library/LaunchDaemons/com.expedia.daemonfilevault.plist
else
	shutdown -r now
fi