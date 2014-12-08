#!/bin/bash

##### HEADER BEGINS ######################################################################
#
# printerChooser.sh
#     Printer Chooser
#
# Created:  2014-08-06
# Modified: 2014-08-06
#
# jschripsema@expedia.com
#
# Info: This script grabs a list of all printers stored in the JSS and presents a chooser.
#
# Two optional variable inputs:
#     JSS_PRINTER_API_USER: $4
#     JSS_PRINTER_API_PASS: $5
#
# Priority: At Reboot
# Category: Tools
#
Version=1.0
##### HEADER ENDS ########################################################################

[ -z "${code}" ] && code="/var/root/local-client-management"
[ -z "${modules}" ] && modules="${code}/modules"

# Set the API user statically.
JSS_PRINTER_API_USER='svc_readprinter'

# Set the API user using parameter $4, first variable passed from Casper.
if [ -n "${4}" ]; then
	JSS_PRINTER_API_USER="${4}"
fi

# Set the API password statically.
JSS_PRINTER_API_PASS='U?MZ(h9Kx8JjwY'

# Set the API password using parameter $5, second variable passed from Casper.
if [ -n "${5}" ]; then
	JSS_PRINTER_API_PASS="${5}"
fi

# Both an API username and password must be specified to use printer chooser.
if [ -z "${JSS_PRINTER_API_USER}" ]; then
	printf '%s\n' 'An API user must be specified in order to use the printer chooser.'
	exit 1
fi

if [ -z "${JSS_PRINTER_API_PASS}" ]; then
	printf '%s\n' 'An API password must be specified in order to use printer chooser.'
	exit 1
fi

PRINTER_CACHE_LOCATION='/Library/Application Support/JAMF/Receipts/PrinterChooserCache'
COCOA_DIALOG_APP='/usr/local/bin/cocoaDialog'
EXPEDIA_JAMF_PLIST='/Library/Preferences/com.expedia.jamf'
PRINTER_PREFERENCE='PrinterChooserClosest'

Main () {
	# Get jss server information and validate that the server is reachable.
	jssServer="$(get_jss_server)"
	#jssServer="https://chcxjamfgis001.sea.corp.expecn.com:8443"
	if [ "${?}" -ne '0' ]; then
		printf '%s.\n' 'Error communicating with JSS'
		return 1
	fi
	
	# Update the printer chooser cache, if necessary.
	update_printer_chooser_cache "${jssServer}" "${JSS_PRINTER_API_USER}" "${JSS_PRINTER_API_PASS}"
	
	# Determine where the chooser should start.
	printerID="$(defaults read "${EXPEDIA_JAMF_PLIST}" "${PRINTER_PREFERENCE}"; exit "${?}")"
	if [ "${?}" -eq '0' ]; then
		# Get detailed printer information.
		singleXML="$(cat "$(grep -R "<id>${printerID}</id>" "${PRINTER_CACHE_LOCATION}" | awk -F: '{ print $1; exit }')")"
		# Determine which address was tested.
		printerURI="$(get_single_xml_item '/printer' "1=1" 'uri' "${singleXML}")"
		printerServer="$(awk -F/ '{ print $3 }' <<< "${printerURI}")"
		# Start the menu location where this printer is.
		menuLocation="$(dirname "$(grep -R "<id>${printerID}</id>" "${PRINTER_CACHE_LOCATION}" | awk -F: '{ print $1; exit }')" | cut -c "$(expr ${#PRINTER_CACHE_LOCATION} + 1)-")"
		# Threshold is 90% of printers with this server specified.
		totalNumber="$(grep -R "<uri>.*${printerServer}.*</uri>" "${PRINTER_CACHE_LOCATION}" | grep -v 'INVALID' | wc -l)"
		thresholdNumber="$(expr ${totalNumber} \* 95 / 100)"
		# Get less and less specific, until the value is over the threshold.
		while [ "$(grep -R "<uri>.*${printerServer}.*</uri>" "${PRINTER_CACHE_LOCATION}${menuLocation}" | grep -v 'INVALID' | wc -l)" -lt "${thresholdNumber}" ]; do
			menuLocation="$(awk -F/ 'sub(FS $NF,x)' <<< "${menuLocation}")"
		done
	else
		# Initially, start at the "top".
		menuLocation='/'
	fi
	
	buttonClicked='0'
	while [ "${buttonClicked}" -ne '1' ]; do
		# Split the path information.
		IFS='/' read -a pathItems <<< "${menuLocation}"
		#		menuDepth="${#pathItems[@]}"
		# Initialize the menu items and path information.
		menuItems=()
		currentDirectory='/'

		# Loop through each path item, building intermediate paths.
		for i in "${pathItems[@]}"; do
			# If not a directory, try next location.
			[ -d "${PRINTER_CACHE_LOCATION}${currentDirectory}${i}" ] || continue

			# If it's not null value, add the item to the current directory with a trailing /
			[ -n "${i}" ] && currentDirectory="${currentDirectory}${i}/"

			# If this entry already exists, skip it.
			(is_in_array menuItems "${currentDirectory}") && continue

			# Add the item to the array.
			menuItems+=("${currentDirectory}")
		done

		# Add in a separator.
		menuItems+=('--- --- --- --- --- --- --- --- --- ---')

		# Initialize some dialog variables.
		dialogButton2=''
		dialogPrinterNames=''

		# Build all contained items.
		for i in "${PRINTER_CACHE_LOCATION}${currentDirectory}"*; do
			if [ -d "${i}" ] && [ "$(basename "${i}")" != 'INVALID' ]; then
				menuItems+=("$(cut -c "$(expr ${#PRINTER_CACHE_LOCATION} + 1)-" <<< "${i}")/")
			elif [ -f "${i}" ]; then
				if [ -n "${dialogPrinterNames}" ]; then
					dialogPrinterNames="${dialogPrinterNames}, $(basename "${i}")"
				else
					dialogPrinterNames="$(basename "${i}")"
				fi
				dialogButton2='Add All'
				menuItems+=("• $(basename "${i}") •")
			fi
		done

		# Get the dialog text and padding.
		if [ -n "${dialogPrinterNames}" ]; then
			dialogText="Current Location: ${currentDirectory}^^^^Choose a printer from the drop-down list to set it up on your system. You may also choose a different location.^^Available printers: ${dialogPrinterNames}"
		else
			dialogText="Current Location: ${currentDirectory}^^^^Choose a location from the drop-down list to navigate to available printers."
		fi

		dialogPadding="$(echo "(${#dialogText}*1.2)/1" | bc)"
		while [ "${#dialogText}" -lt "${dialogPadding}" ]; do
			dialogText="${dialogText}^                                                  "
		done

		# Display the dialog.
		temp="$("${COCOA_DIALOG_APP}" dropdown --title 'Choose a Printer' --button1 'Done' --button2 "${dialogButton2}" --button3 'Refresh Printer List' --text "$(tr '^' '\n' <<< "${dialogText} ")" --exit-onchange --items "${menuItems[@]}")"
		# Determine which button was clicked and which selection was made.
		buttonClicked="$(head -n 1 <<< "${temp}")"
		currentSelection="$(tail -n 1 <<< "${temp}")"

		case "${buttonClicked}" in
			1) # Done
				break
				;;
			2) # Add All
				for i in "${menuItems[@]}"; do
					# Get the printer name, stripping off the • characters and leading/trailing spaces.
					printerName="$(tr -d '•' <<< "${i}" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')"
					# If this name doesn't map to a printer, skip this entry.
					[ -f "${PRINTER_CACHE_LOCATION}${currentDirectory}${printerName}" ] || continue
					install_printer "${currentDirectory}${printerName}"
				done
				;;
			3) # Force Update Printer List
				touch "${PRINTER_CACHE_LOCATION}/forceupdate"
				update_printer_chooser_cache "${jssServer}" "${JSS_PRINTER_API_USER}" "${JSS_PRINTER_API_PASS}"
				rm -f "${PRINTER_CACHE_LOCATION}/forceupdate"
				# If a printer is found, update the printer location.
				printerID="$(defaults read "${EXPEDIA_JAMF_PLIST}" "${PRINTER_PREFERENCE}"; exit "${?}")"
				if [ "${?}" -eq '0' ]; then
					# Get detailed printer information.
					singleXML="$(cat "$(grep -R "<id>${printerID}</id>" "${PRINTER_CACHE_LOCATION}" | awk -F: '{ print $1; exit }')")"
					# Determine which address was tested.
					printerURI="$(get_single_xml_item '/printer' "1=1" 'uri' "${singleXML}")"
					printerServer="$(awk -F/ '{ print $3 }' <<< "${printerURI}")"
					# Start the menu location where this printer is.
					menuLocation="$(dirname "$(grep -R "<id>${printerID}</id>" "${PRINTER_CACHE_LOCATION}" | awk -F: '{ print $1; exit }')" | cut -c "$(expr ${#PRINTER_CACHE_LOCATION} + 1)-")"
					# Threshold is 90% of printers with this server specified.
					totalNumber="$(grep -R "<uri>.*${printerServer}.*</uri>" "${PRINTER_CACHE_LOCATION}" | wc -l)"
					thresholdNumber="$(expr ${totalNumber} \* 95 / 100)"
					# Get less and less specific, until the value is over the threshold.
					while [ "$(grep -R "<uri>.*${printerServer}.*</uri>" "${PRINTER_CACHE_LOCATION}${menuLocation}" | wc -l)" -lt "${thresholdNumber}" ]; do
						menuLocation="$(awk -F/ 'sub(FS $NF,x)' <<< "${menuLocation}")"
					done
				fi
				;;
			*)
				dialogSelection="$(tr -d '•' <<< "${menuItems[${currentSelection}]}" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')"
				if [ -f "${PRINTER_CACHE_LOCATION}${currentDirectory}${dialogSelection}" ]; then
					install_printer "${currentDirectory}${dialogSelection}"
				elif [ -d "${PRINTER_CACHE_LOCATION}${dialogSelection}" ]; then
					menuLocation="${dialogSelection}"
				fi
				;;
		esac
	done
}

function update_printer_chooser_cache () {
	local jssServer="${1}"
	local jssUsername="${2}"
	local jssPassword="${3}"
	local resourceXML singleXML
	local numMatches numPrinters printerPath printerName printerID
	local tempFile="/tmp/printerping${RANDOM}"
	
	# Get the basic information for every item of this resouce. Usually just ID's and names.
	resourceXML="$(get_jss_resource_xml "${jssServer}" 'printers' "${jssUsername}" "${jssPassword}")"
	if [ "${?}" -ne '0' ]; then
		printf '%s\n' "${resourceXML}"
		return 1
	fi
	
	numPrinters="$(awk -F'<size>|</size>' '/<size>/ { print $2 }' <<< "${resourceXML}")"
	
	# Validate that the local printer cache contains all the printers
	while read line; do
		numMatches="$(find "${PRINTER_CACHE_LOCATION}" -name "${line}" -type f | wc -l)"
		[ "${numMatches}" -eq '0' ] && break
	done <<< "$(awk -F'<name>|</name>' '/<name>/ { print $2 }' <<< "${resourceXML}")"
	
	# If numMatches is non-zero here, all printers exist. Validate the size is equal to the number of printers.
	[ "${numMatches}" -gt '0' ] && [ "$(find "${PRINTER_CACHE_LOCATION}" -type f | wc -l)" -eq "${numPrinters}" ] && return 0
	
	# Archive the current cache.
	if [ -d "${PRINTER_CACHE_LOCATION}" ]; then
		rm -rf "/tmp/$(awk -F'/' '{ print $NF }' <<< "${PRINTER_CACHE_LOCATION}").bak"
		mv "${PRINTER_CACHE_LOCATION}" "/tmp/$(awk -F'/' '{ print $NF }' <<< "${PRINTER_CACHE_LOCATION}").bak"
	fi
	
	# Initialize the progress meter.
	progressPipe="/tmp/hpipe${RANDOM}"
	rm -f "${progressPipe}"
	mkfifo "${progressPipe}"
	numMatches='0'
	
	# Kick off cocoaDialog
	"${COCOA_DIALOG_APP}" progressbar --title 'Rebuilding Printer Cache' --percent '0' --text 'Rebuilding Printer Cache...' < "${progressPipe}" &
	# Open the FIFO for writing.
	exec 3<> "${progressPipe}"
	
	# Create a new cache.
	while read line; do
		let "numMatches++"
		# Get printer's detailed information.
		singleXML="$(get_jss_resource_xml "${jssServer}" "printers/id/${line}" "${jssUsername}" "${jssPassword}")"
		if [ "${?}" -ne '0' ]; then
			printf '%s\n' "${singleXML}"
			return 1
		fi
		
		# Grab the path and printer name.
		printerPath="$(get_single_xml_item '/printer' "id=${line}" 'notes' "${singleXML}" | head -n 1)"
		printerName="$(get_single_xml_item '/printer' "id=${line}" 'name' "${singleXML}")"
		printerURI="$(get_single_xml_item '/printer' "id=${line}" 'uri' "${singleXML}")"
		
		printf '%s %s\n' "$(expr 100 \* ${numMatches} / ${numPrinters})" "Adding: ${printerName}" >&3
		
		# The path needs to start with a '/' to be valid and the printer must be deployable.
		if [ "${printerPath:0:1}" == '/' ]; then
			# Ping this printer to determine closest one.
			printer_ping "${printerURI}" "${line}" "${tempFile}" &
			
			# Write the printer information to this directory.
			mkdir -p "${PRINTER_CACHE_LOCATION}/${printerPath}"
			printf '%s' "${singleXML}" > "${PRINTER_CACHE_LOCATION}/${printerPath}/${printerName}"
		else
			# Printer information not valid. Write to directory to avoid constant re-caching.
			mkdir -p "${PRINTER_CACHE_LOCATION}/INVALID"
			printf '%s' "${singleXML}" > "${PRINTER_CACHE_LOCATION}/INVALID/${printerName}"
		fi
	done <<< "$(awk -F'<id>|</id>' '/<id>/ { print $2 }' <<< "${resourceXML}")"

	# Cleanup after progress meter.
	printf '%s %s\n' '100' 'Finishing Pending Tasks.' >&3
	exec 3>&-
	wait
	rm -f "${progressPipe}"
	
	# Write the results of the pings to the Expedia preferences file.
	if [ -f "${tempFile}" ]; then
		printerID="$(sort -n "${tempFile}" | awk '{ print $2; exit }')"
		defaults write "${EXPEDIA_JAMF_PLIST}" "${PRINTER_PREFERENCE}" "${printerID}"
		rm -f "${tempFile}"
	fi
	
	return 0
}

# This is the ping function which is used to determine the lowest latency ping result.
function printer_ping () {
	local printerURI="${1}"
	local printerID="${2}"
	local resultFile="${3}"
	local pingResult=''
	local pingExit=''
	local ipAddress="$(awk -F/ '{ print $3 }' <<< "${printerURI}")"
	
	# Ping the given address 5 times.
	pingResult="$(ping -c 5 -q "${ipAddress}")"; pingExit="${?}"
	# On error, exit out. Server probably unreachable so just ignore this server.
	if [ "${pingExit}" -ne '0' ]; then
		return 0
	fi
	
	# Append the average ping result, the type of server and the id to a results file.
	printf '%s %s\n' "$(tail -1 <<< "${pingResult}" | awk -F '/' '{ print $5 }')" "${printerID}" >> "${resultFile}"
	return 0
}

function install_printer () {
	local singleXML="$(cat "${PRINTER_CACHE_LOCATION}${1}")"
	local printerID="$(awk -F'<id>|</id>' '/<id>/ { print $2 }' <<< "${singleXML}")"
	local printerName="$(get_single_xml_item '/printer' "id=${printerID}" 'name' "${singleXML}")"
	local printerNotes="$(get_single_xml_item '/printer' "id=${printerID}" 'notes' "${singleXML}")"
	local driverTestFile="$(sed -n '2{p;q;}' <<< "${printerNotes}")"
	local printerJamfEvent="$(sed -n '3{p;q;}' <<< "${printerNotes}")"
	
	# Initialize the progress meter.
	progressPipe="/tmp/hpipe${RANDOM}"
	rm -f "${progressPipe}"
	mkfifo "${progressPipe}"
	numMatches='0'
	
	# Kick off cocoaDialog
	"${COCOA_DIALOG_APP}" progressbar --title 'Installing Printer' --indeterminate --text "${printerName}" < "${progressPipe}" &
	# Open the FIFO for writing.
	exec 3<> "${progressPipe}"
	
	# For old versions of the Casper Suite, use -action. Otherwise, -event.
	case "$(/usr/sbin/jamf version | awk -F '[=.]' '{ print $2 }')" in
		[0-8]) jamfEvent='-action'
		;;
		*) jamfEvent='-event'
		;;
	esac
	
	if [ ! -e "${driverTestFile}" ] && [ -n "${printerJamfEvent}" ]; then
		printf '%s %s\n' '0' "Installing Driver: ${printerName}" >&3
		/usr/sbin/jamf policy "${jamfEvent}" "${printerJamfEvent}"
	fi
	
	printf '%s %s\n' '0' "Installing Printer: ${printerName}" >&3
	/usr/sbin/jamf mapPrinter -id "${printerID}"
	
	exec 3>&-
	wait
	rm -f "${progressPipe}"
	
	return 0
}

. "${modules}/start.sh"; start
Main 2>&1
finish