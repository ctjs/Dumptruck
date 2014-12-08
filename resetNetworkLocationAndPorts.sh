#!/bin/bash

####################################################################################
#
# resetNetworkLocationAndPorts.sh
# 
# Created:  2014-09-15
# Modified: 2014-09-15
#
# jschripsema@expedia.com
#
# This script creates a populates the 'Automatic' location through the use of a
# temporary location 'TempLoc'. This should automatically detect and enable
# Thunderbolt/USB Ethernet dongles on boot.
#
# Priority: At Reboot
# Category: Management Tools - No SS
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

networksetup -createlocation TempLoc populate
sleep 5

networksetup -switchtolocation TempLoc
sleep 2

networksetup -deletelocation Automatic
sleep 2

networksetup -createlocation Automatic populate
sleep 5

networksetup -switchtolocation Automatic
sleep 5

networksetup -deletelocation TempLoc