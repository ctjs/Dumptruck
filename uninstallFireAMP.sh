#!/bin/bash

####################################################################################
#
# uninstallFireAMP.sh
# 
# Created:  2014-11-05
# Modified: 2014-11-05
#
# jschripsema@expedia.com
#
# This script will completely uninstall FireAMP Connector and note when this occurred.
#
# Priority: Before
# Category:  Applications - No SS
#
####################################################################################

EXPEDIA_JAMF_PLIST='/Library/Preferences/com.expedia.jamf'
FIREAMP_PREFERENCE='FireAMPUninstalled'

FIREAMP_UNINSTALLER='/Applications/FireAMP/Uninstall FireAMP Mac.pkg'
FIREAMP_MENULET='FireAMP Mac'

FIREAMP_LAUNCH_ARRAY=()
FIREAMP_LAUNCH_ARRAY+=('/Library/LaunchAgents/com.sourcefire.amp.agent.plist')
FIREAMP_LAUNCH_ARRAY+=('/Library/LaunchDaemons/com.sourcefire.amp.daemon.plist')

FIREAMP_KEXT_ARRAY=()
FIREAMP_KEXT_ARRAY+=('com.sourcefire.amp.fileop')
FIREAMP_KEXT_ARRAY+=('com.sourcefire.amp.nke')

FIREAMP_DELETE_PATH=()
FIREAMP_DELETE_PATH+=('/Applications/FireAMP')
FIREAMP_DELETE_PATH+=('/Library/Extensions/ampfileop.kext')
FIREAMP_DELETE_PATH+=('/Library/Extensions/ampnetflow.kext')
FIREAMP_DELETE_PATH+=('/Library/Application Support/Sourcefire/FireAMP Mac')
FIREAMP_DELETE_PATH+=('/usr/local/libexec/sourcefire')

uninstallDate="$(date -ju "+%Y-%m-%d %H:%M:%S")"
printf 'Noting FireAMP Uninstall: %s\n' "${uninstallDate}"
defaults write "${EXPEDIA_JAMF_PLIST}" "${FIREAMP_PREFERENCE}" -date "${uninstallDate}"

printf 'Killing menulet process: %s\n' "${FIREAMP_MENULET}"
killall "${FIREAMP_MENULET}" > /dev/null 2>&1

if [ -f "${FIREAMP_UNINSTALLER}" ]; then
	printf 'Running FireAMP Uninstaller: %s\n' "${FIREAMP_UNINSTALLER}"
	/usr/sbin/installer -dumplog -verbose -pkg "${FIREAMP_UNINSTALLER}" -target "/"
fi

for i in "${FIREAMP_LAUNCH_ARRAY[@]}"; do
	if [ -f "${i}" ]; then
		printf 'Unloading and removing: %s\n' "${i}"
		/bin/launchctl unload "${i}"
		rm -f "${i}"
	fi
done

for i in "${FIREAMP_KEXT_ARRAY[@]}"; do
	if [ "$(/usr/sbin/kextstat -l | grep -c "${i}")" -gt '0' ]; then
		printf 'Unloading kext: %s\n' "${i}"
		/sbin/kextunload "${i}"
	fi
done

for i in "${FIREAMP_DELETE_PATH[@]}"; do
	if [ -e "${i}" ]; then
		printf 'Removing path: %s\n' "${i}"
		rm -rf "${i}"
	fi
done