#!/bin/bash

####################################################################################
#                                                                                  #
# autoUpdates.sh                                                                   #
#                                                                                  #
# Created:  2013-11-29                                                             #
# Modified: 2014-03-24                                                             #
#                                                                                  #
# jschripsema@expedia.com                                                          #
#                                                                                  #
# Priority: After                                                                  #
# Category: Management Tools - No SS                                               #
#                                                                                  #
# This script is designed to run on every ~15 minutes when a computer "checks-in"  #
# to provide a notification method to end users for required updates. After a      #
# package is cached in JAMF's "Waiting Room", and an xml file is included that     #
# specifies what actions are to be taken, it will begin notifying  after the       #
# "startdate", and will enforce an install after the "deadline".                   #
#                                                                                  #
# Notifications:                                                                   #
# No deadline: No notifications. Will install along with any other installation.   #
# >24 hours away from deadline: Every 4 hours.                                     #
# 1-24 hours: Every hour.                                                          #
# <1 hour: Every 15 minutes.                                                       #
# Past deadline: Yes. Allows for a one-time delay of 1, 5, 10, 15, and 30 minutes. #
#     Note: Displays a 60 second countdown timer during last minute of delay.      #
#                                                                                  #
# XML file must be named "PackageFullName.autoinstall.xml". For example:           #
#    Package: "Google Chrome 33.0.1750.117.dmg"                                    #
#    XML: "Google Chrome 33.0.1750.117.dmg.autoinstall.xml"                        #
#                                                                                  #
# name: The display name of the package.                                           #
# version: The version of this pacakge, used for version checking.                 #
# installedversion: A one-line script used to obtain the installed version.        #
# md5: An optional md5 checksum to determine if the installer is complete.         #
# reboot: If 'true', will notify, only, the end user that a reboot is required.    #
# startdate: The date/time to start allowing this package to be installed.         #
# deadline: The date/time to require installation. Required for notifications.     #
# utctime: If 'true', dates/times will be UTC versus the local timezone.           #
# killall: Specify as many as desired. Will issue 'killall' commands for these.    #
# remove: Specify as many as desired. 'cd /Applications/' then issues 'rm -rf'.    #
#                                                                                  #
# Sample XML File:                                                                 #
#                                                                                  #
# <?xml version="1.0" encoding="UTF-8"?>                                           #
# <autoinstall>                                                                    #
#    <name>Google Chrome</name>                                                    #
#    <version>33.0.1750.117</version>                                              #
#    <installedversion>defaults read "/Applications/Google Chrome.app/Contents/Info" CFBundleShortVersionString</installedversion>
#    <md5>4cef0d5176c089cd02956633f8000520</md5>                                   #
#    <reboot>false</reboot>                                                        #
#    <startdate>2014-02-22T02:00:00</startdate>                                    #
#    <deadline>2014-02-27T05:00:00</deadline>                                      #
#    <utctime>false</utctime>                                                      #
#    <killall>Google Chrome</killall>                                              #
#    <killall>Google Chrome Helper</killall>                                       #
#    <remove>Google Chrome.app</remove>                                            #
# </autoinstall>                                                                   #
#                                                                                  #
####################################################################################


# Initialize the exit code variable.
exitCode='0'

# Preferred notification tool.
notificationTool='cocoaDialog'

# Define some variables.
nowTimestamp="$(date '+%s')"
waitingRoom='/Library/Application Support/JAMF/Waiting Room/'
jamfHelperApp='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
cocoaDialogApp='/usr/local/bin/cocoaDialog'
jamfBinary='/usr/sbin/jamf'
lastNotifyFile='/Library/Application Support/JAMF/Receipts/com.expedia.autoinstall.lastnotify'
if [ -f "${lastNotifyFile}" ]; then
	lastNotifyTime=`cat "${lastNotifyFile}"`
else
	lastNotifyTime='0'
fi

# Determine if only one notification tool is available, or if we can use the preferred.
if [ -f "${jamfHelperApp}" ] && [ ! -f "${cocoaDialogApp}" ]; then
	notificationTool='jamfHelper'
elif [ ! -f "${jamfHelperApp}" ] && [ -f "${cocoaDialogApp}" ]; then
	notificationTool='cocoaDialog'
elif [ ! -f "${jamfHelperApp}" ] && [ ! -f "${cocoaDialogApp}" ]; then
	echo 'Error: No usable notification tool found.'
	exit 1
fi

# The version compare function, used to determine if an associate did the update on their own.
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

# Determine all cached packages that have an "autoinstall" xml file.
unset cachedPackages
SAVEIFS=$IFS
IFS=$'\n'
for i in `ls -1 "${waitingRoom}"`; do
	if [ -f "${waitingRoom}/${i}.autoinstall.xml" ]; then
		cachedPackages=("${cachedPackages[@]}" "${i}");
	fi
done
IFS=$SAVEIFS

# Loop through the cached packages.
unset packageList allKillall allRemove allNames myDeadline myReboot notifyNow installNow
for i in "${cachedPackages[@]}"; do
	# Grab all the data from the xml file.
	xmlName=`awk -F '[<>]' '/<name>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`
	xmlVersion=`awk -F '[<>]' '/<version>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`
	xmlInstalledVersion=`awk -F '[<>]' '/<installedversion>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`
	xmlInstalledVersion=$(printf '%s' "${xmlInstalledVersion}")
	installedVersion="$(eval ${xmlInstalledVersion})"
	xmlMD5=`awk -F '[<>]' '/<md5>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`
	xmlReboot=`awk -F '[<>]' '/<reboot>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml" | tr '[:upper:]' '[:lower:]'`
	xmlStartdate=`awk -F '[<>]' '/<startdate>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`
	xmlDeadline=`awk -F '[<>]' '/<deadline>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`
	xmlUTCTime=`awk -F '[<>]' '/<utctime>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml" | tr '[:upper:]' '[:lower:]'`
	if [ "${xmlUTCTime}" == 'true' ]; then
		dateOptions='-juf'
	else
		dateOptions='-jf'
	fi
	
	# If given an md5 checksum, verify that the package matches.
	if [ -n "${xmlMD5}" ]; then
		packageMD5=`md5 -q "${waitingRoom}/${i}"`
		if [ "${xmlMD5}" != "${packageMD5}" ]; then
			echo "Error: MD5 checksum does not match. Package: ${i}"
			((exitCode++))
			continue
		fi
	fi
	
	# See if start date is provided in '%Y-%m-%dT%H:%M:%S' format.
	startdateTime=`date "${dateOptions}" '%Y-%m-%dT%H:%M:%S' "${xmlStartdate}" '+%s'`
	if [ "${?}" -ne "0" ]; then
		# If not, see if start date is provided in '%Y-%m-%d' format.
		startdateTime=`date "${dateOptions}" '%Y-%m-%dT%H:%M:%S' "${xmlStartdate}T00:00:00" '+%s'`
		if [ "${?}" -ne "0" ]; then
			# Start date in an invalid format.
			echo "Error: Date/Time format is not recognized. Package: ${i}"
			((exitCode++))
			unset startdateTime
		fi 
	fi
	# See if deadline date is provided in '%Y-%m-%dT%H:%M:%S' format.
	deadlineTime=`date "${dateOptions}" '%Y-%m-%dT%H:%M:%S' "${xmlDeadline}" '+%s'`
	if [ "${?}" -ne "0" ]; then
		# If not, see if deadline date is provided in '%Y-%m-%d' format.
		deadlineTime=`date "${dateOptions}" '%Y-%m-%dT%H:%M:%S' "${xmlDeadline}T00:00:00" '+%s'`
		if [ "${?}" -ne "0" ]; then
			# Deadline date in an invalid format.
			echo "Error: Date/Time format is not recognized. Package: ${i}"
			((exitCode++))
			unset deadlineTime
		fi 
	fi
	
	# Make sure we at least have a start date for this package.
	[ -n "${startdateTime}" ] || continue
	
	# Compare the versions.
	versioncompare "${xmlVersion}" "${installedVersion}"
	versionCompareResult="${?}"
	if [ "${versionCompareResult}" -eq '1' ] && [ "${nowTimestamp}" -gt "${startdateTime}" ]; then
		# Time to do "something" with this package. Adding to the lists.
		packageList=("${packageList[@]}" "${i}");
	
		SAVEIFS=$IFS
		IFS=$'\n'
		for j in `awk -F '[<>]' '/killall/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`; do allKillall=("${allKillall[@]}" "${j}"); done
		for j in `awk -F '[<>]' '/remove/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`; do allRemove=("${allRemove[@]}" "${j}"); done
		IFS=$SAVEIFS
	
		if [ -n "${allNames}" ]; then
			allNames="${allNames}, ${xmlName}"
		else
			allNames="${xmlName}"
		fi
		if [ -n "${deadlineTime}" ]; then
			if [ -z "${myDeadline}" ] || [ "${deadlineTime}" -lt "${myDeadline}" ]; then
				myDeadline="${deadlineTime}"
			fi
		fi
		if [ "${xmlReboot}" == 'true' ]; then
			myReboot='true'
		fi
	elif [ "${versionCompareResult}" -ne '1' ]; then
		# Installed version is at, or above, the cached version. Remove the cache.
		rm "${waitingRoom}/${i}.autoinstall.xml"
		rm "${waitingRoom}/${i}.cache.xml"
		rm -rf "${waitingRoom}/${i}"
	fi
done

# I have a deadline, check to see if it's time to notify.
notifyNow='false'
if [ -z "${myDeadline}" ]; then
	# No deadline defined.
	notifyNow='false'
elif [ "${nowTimestamp}" -ge "${myDeadline}" ]; then
	# Past deadline.
	notifyNow='true'
elif [ "$(date -jv '+1H' '+%s')" -ge "${myDeadline}" ]; then
	# Within 1 hour of deadline.
	if [ "$(date -jv '-10M' '+%s')" -ge "${lastNotifyTime}" ]; then
		# Last notification more than 10 minutes ago. Designed to be run on the every15
		# trigger so it should run ~15 minutes. Not checking for 15, otherwise might skip
		# an every15 trigger depending on how long the variable wait time was.
		notifyNow='true'
	fi
elif [ "$(date -jv '+1d' '+%s')" -ge "${myDeadline}" ]; then
	# Within 1 day of deadline.
	if [ "$(date -jv '-1H' '+%s')" -ge "${lastNotifyTime}" ]; then
		# Last notification more than 1 hour ago.
		notifyNow='true'
	fi
else
	# More than 1 day before deadline.
	if [ "$(date -jv '-4H' '+%s')" -ge "${lastNotifyTime}" ]; then
		# Last notification more than 4 hours ago.
		notifyNow='true'
	fi
fi

# Add in the reboot text if rebooting.
rebootTextWarning=''
rebootTextNow=''
if [ "${myReboot}" == 'true' ]; then
	rebootTextWarning="$(tr 'ü' '\n' <<< "üüOne or more updates will require a reboot of your computer after installation.")"
	rebootTextNow="$(tr 'ü' '\n' <<< "üüPlease reboot your computer now.")"
fi

# Is it time to give a notification?
if [ "${notifyNow}" == "true" ]; then
	# Mark a notification as happening now.
	printf '%s' "${nowTimestamp}" > "${lastNotifyFile}"
	installNow='false'
	# Determine what type of notification to give based on if the deadline has passed.
	if [ "${nowTimestamp}" -lt "${myDeadline}" ]; then
		# Deadline has not passed, just give a option to do the updates.
		niceDeadline=`date -jf '%s' "${myDeadline}" '+%A, %e %b %Y, at %I:%M%p'`
		dialogTitle='Updates Available'
		dialogIntroText='Updates Ready to be Installed'
		dialogText="You have updates available for the following application(s): ${allNames}. The deadline to install these updates is ${niceDeadline}. Please close these applications and save all work before beginning the update process, they will be forced to close if left open. Would you like to complete the update now?${rebootTextWarning}"
		yesButton='Update Now'
		noButton='Update Later'
		
		# Display the update dialog. It will timeout, without doing the update, after 5 minutes.
		if [ "${notificationTool}" == 'cocoaDialog' ]; then
			button=`"${cocoaDialogApp}" msgbox --title "${dialogTitle}" --icon 'installer' --text "${dialogIntroText}" --informative-text "${dialogText}" --button1 "${noButton}" --button2 "${yesButton}" --timeout '300'`
			if [ "${button}" -eq '2' ]; then
				# Associate choosing to do the update now.
				installNow='true'
			fi
		else
			button=`"${jamfHelperApp}" -windowType hud -windowPosition lr -title "${dialogTitle}" -description "${dialogText}" -button1 "${noButton}" -button2 "${yesButton}" -cancelButton '1' -timeout '300' -startlaunchd`
			if [ "${button}" -eq '1' ]; then
				button='201'
			elif [ "${button}" -eq '0' ]; then
				button='1'
			elif [ "${button}" -eq '2' ]; then
				# Associate choosing to do the update now.
				installNow='true'
			fi
		fi
	else
		# Deadline has passed, be a little more forceful.
		niceDeadline=`date -jf '%s' "${myDeadline}" '+%A, %e %b %Y, at %I:%M%p'`
		dialogTitle='Updates Installing'
		dialogText="You have updates available for the following application(s): ${allNames}. The deadline to install these updates has passed. Please close these applications and save all work before beginning the update process, they will be forced to close if left open. You may choose to delay this operation once and will receive a notice one minute before installation begins.${rebootTextWarning}"
		yesButton='Update Now'
		delayButton='Delay'

		# Display the dialog. Will remain onscreen for 10 minutes, at which time it will do the update. Optional, one time, delay.
		if [ "${notificationTool}" == 'cocoaDialog' ]; then
			temp=`"${cocoaDialogApp}" dropdown --title "${dialogTitle}" --icon 'installer' --text "$(tr 'ü' '\n' <<< "üüüü${dialogText}")" --button1 "${yesButton}" --button2 "${delayButton}" --items '1 minute' '5 minutes' '10 minutes' '15 minutes' '30 minutes' --timeout '600'`
			read -d '' button temp2 <<< "${temp}"
			case "${temp2}" in
				0)
					delay='60'
				;;
				1)
					delay='300'
				;;
				2)
					delay='600'
				;;
				3)
					delay='900'
				;;
				4)
					delay='1800'
				;;
				*)
					delay='60'
				;;
			esac
		else
			temp=`"${jamfHelperApp}" -windowType utility -windowPosition lr -title "${dialogTitle}" -description "${dialogText}" -button1 "${yesButton}" -button2 "${delayButton}" -cancelButton '2' -showDelayOptions "60, 300, 600, 900, 1800" -timeout '600' -countdown -startlaunchd`
			if [ "${temp}" -eq '1' ]; then
				button='201'
			elif [ "${temp}" -lt '200' ] || [ "${temp}" -gt '300' ]; then
				# This logic will need to be adjusted if a delay of 20-30 seconds is provided.
				# Split the button pressed from the optional delay.
				button=`echo "${temp}" | cut -c "${#temp}"`
				temp2=`expr "${#temp}" - 1`
				delay=`echo "${temp}" | cut -c 1-"${temp2}"`
			else
				button="${temp}"
			fi
 		fi
		
		# Check if a delay was chosen. If so, give them a delay.
		if [ "${button}" -eq '2' ]; then
			# Sleep the desired amount, minus one minute due to onscreen notification.
			sleep `expr "${delay}" - 60`
			dialogTitle='Updates Installing'
			dialogIntroText='Updates Installing Soon'
			dialogText="The following application(s) will be updated when the timer expires: ${allNames}. Please close these applications and save all work before beginning the update process.${rebootTextWarning}"
			yesButton='Update Now'
			
			# One minute onscreen notification. Would like to change the verbiage for "Please make selection in".
			if [ "${notificationTool}" == 'cocoaDialog' ]; then
				temp=`"${cocoaDialogApp}" msgbox --title "${dialogTitle}" --icon 'installer' --text "${dialogIntroText}" --informative-text "${dialogText}" --button1 "${yesButton}" --timeout '60'`
			else
				temp=`"${jamfHelperApp}" -windowType hud -lockHUD -windowPosition lr -title "${dialogTitle}" -description "${dialogText}" -button1 "${yesButton}" -timeout '60' -countdown -startlaunchd`
			fi
		fi
		# No delay.
		if [ "${button}" -eq '1' ] || [ "${button}" -eq '2' ]; then
			installNow='true'
		fi
# 		if [ "${button}" -gt '200' ] && [ "${button}" -lt '300' ]; then
# 			# This logic will need to be adjusted if a delay of 20-30 seconds is available.
# 			if [ "${button}" -ne '239' ] && [ "${button}" -ne '243' ] && [ "${button}" -ne '254' ]; then
# 				echo "Error: Unknown button returned from jamfHelper application: ${button}"
# 				exit "${button}"
# 			fi
# 		fi
	fi
fi

if [ "${installNow}" == 'true' ]; then
	SAVEIFS=$IFS
	IFS=$'\n'
	# Kill everything.
	for i in "${allKillall[@]}"; do
		killall "${i}" > /dev/null 2>&1
	done
	# Delete everything
	for i in "${allRemove[@]}"; do
		# cd into the Applications folder. It's not really sandboxed, but trying to get
		# rid of common accidents. Make sure the folder exists, $i isn't null and the
		# first character is not "/". Not really trying to prevent malicious behavior,
		# just trying to prevent accidental wiping of the machine.
		cd "/Applications/"
		if [ -e "/Applications/${i}" ] && [ -n "${i}" ] && [ "$(echo ${i} | cut -c 1)" != '/' ]; then
			rm -rf "${i}"
		fi
	done
	for i in "${packageList[@]}"; do
		unset futFlag feuFlag
		xmlFUT=`awk -F '[<>]' '/<fut>/ { print $3 }' "${waitingRoom}/${i}.cache.xml"`
		xmlFEU=`awk -F '[<>]' '/<feu>/ { print $3 }' "${waitingRoom}/${i}.cache.xml"`
		xmlName=`awk -F '[<>]' '/<name>/ { print $3 }' "${waitingRoom}/${i}.autoinstall.xml"`
		if [ "${xmlFUT}" == 'true' ]; then
			futFlag='-fut'
		fi
		if [ "${xmlFEU}" == 'true' ]; then
			feuFlag='-feu'
		fi
		# /usr/sbin/jamf installAllCached
		"${jamfBinary}" install -package "${i}" -path "${waitingRoom}" -target / "${futFlag}" "${feuFlag}"
		
		# Remove the autoinstall file.
		rm "${waitingRoom}/${i}.autoinstall.xml"
		if [ "${notificationTool}" == 'cocoaDialog' ]; then
			dialogTitle='Finished Installation'
			dialogText="${xmlName} Installed"
			"${cocoaDialogApp}" bubble --title "${dialogTitle}" --icon 'installer' --text "${dialogText}"
		fi
	done
	IFS=$SAVEIFS
	dialogTitle='Updates Installed'
	dialogIntroText='Updates Have Been Installed'
	dialogText="The following applications have been updated: ${allNames}. ${rebootTextNow}"
	yesButton='OK'

	# If notifying user to reboot, do a recon before telling them to reboot.
	if [ "${myReboot}" == 'true' ]; then
		"${jamfBinary}" recon
	fi

	if [ "${notificationTool}" == 'cocoaDialog' ]; then
		"${cocoaDialogApp}" msgbox --title "${dialogTitle}" --icon 'installer' --text "${dialogIntroText}" --informative-text "${dialogText}" --button1 "${yesButton}" &
	else
		"${jamfHelperApp}" -windowType hud -windowPosition lr -title "${dialogTitle}" -description "${dialogText}" -button1 "${yesButton}" -defaultButton 1 -startlaunchd &
	fi

	# If no reboot is needed, recon after telling them so the visable process doesn't take as long.
	if [ "${myReboot}" != 'true' ]; then
		"${jamfBinary}" recon
	fi
fi

exit "${exitCode}"