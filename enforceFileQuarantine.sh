#!/bin/bash

##### HEADER BEGINS #######################################################
#
# enforceFileQuarantine.sh
# 
# Created:  2014-08-14
# Modified: 2014-08-14
#
# jschripsema@expedia.com
#
# Priority: At Reboot
# Category: Applications - No SS
#
# Info: This script reapplies system settings that enforce checking for, and applying, updates to File Quarantine, aka XProtect. Then kicks off a check.
#     
##### HEADER ENDS #########################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

############################## Begin Script ###############################

# Enable downloading of critical updates and config data.
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true

# Trigger background checks
sudo softwareupdate --background
sudo softwareupdate --background-critical

exit 0