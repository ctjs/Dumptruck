#!/bin/bash

####################################################################################
#
# generateLocalCerts.sh
# 
# Created:  2014-05-14
# Modified: 2014-11-18
# Version:  6.5
#
# jschripsema@expedia.com
#
# This script generates user and computer certificates for the local computer. The
# password specified needs to be base64 encoded.
#
# If the SILENT_EXECUTE_FILE exists, will not output any information or prompt for
# authentication.
#
# Based *heavily* on a script by Steve Keever.
#
# Priority: Before
# Category: Network/VPN - No SS
#
# Two required variable inputs:
#    ! caUserID: $4
#    ! caPassword: $5
#
####################################################################################

# Set the mountpoint passed by Casper.
mountPoint="${1}"

# Set the computername passed by Casper.
computerName="${2}"

# Set the username passed by Casper.
username="${3}"

# Gather the user id used to generate the certificates.
if [ -n "${4}" ]; then
	caUserID="${4}"
else
	printf '%s\n' 'A user id must be specified in order to use this script.'
	exit 1
fi

# Gather the encoded password used to generate the certificates
if [ -n "${5}" ]; then
	caPassword="$(base64 --decode <<< "${5}")"
else
	printf '%s\n' 'A password must be specified in order to use this script.'
	exit 1
fi

#
# Script to auto-enroll an OS X system via an AD CA's web enrollment.
#

## Constants
LOGGER_FLAGS="-t com.expedia.generateLocalCerts"
JAMF_HELPER_APP='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'
JAMF_ICON='/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/Resources/Message.png'
YES_BUTTON='Ok'
DSCL_AD_SEARCH='/Active Directory/SEA/All Domains'
SILENT_EXECUTE_FILE='/tmp/generateLocalCerts_silent_execute'
SECURITY_TEST_ACCOUNT='generateLocalCerts.sh'
SECURITY_TEST_SERVICE='Generate Local Certs Test Item'
SECURITY_TEST_PASSWORD='password'

## Determine if executing silently
if [ -f "${SILENT_EXECUTE_FILE}" ]; then
	silentExecute='true'
else
	unset silentExecute
fi

## Pass in a user variable for the certificate
userSamID="$(who | awk '/console/ { print $1; exit }')"
printf 'User is %s.\n' "${userSamID}"
if [ -z "${silentExecute}" ]; then
	logger ${LOGGER_FLAGS} "$(printf 'User is %s.\n' "${userSamID}")"
fi

## Determine the Dock PID variable for the username
userConsolePID="$(ps -axj | awk "/^$userSamID/ && /System\/Library/ && /\/Dock$/ { print \$2; exit }")"
printf 'PID is %s.\n' "${userConsolePID}"
if [ -z "${silentExecute}" ]; then
	logger ${LOGGER_FLAGS} "$(printf 'PID is %s.\n' "${userConsolePID}")"
fi

# The URL of the CA web enrollment pages.
urlMachine="https://chc-svcpki01.sea.corp.expecn.com/certsrv"
urlUser="https://chc-svcpki02.sea.corp.expecn.com/certsrv"

# Certificate templates to be used.
certTypeMachine="ExpediaComputerMac"
certTypeUser="ExpediaUserApple"

## Create a temp directory and then use that for staging.
tempDir="$(mktemp -d -t autoenroll)"
printf 'Temp is %s.\n' "${tempDir}"
if [ -z "${silentExecute}" ]; then
	logger ${LOGGER_FLAGS} "$(printf 'Temp is %s.\n' "${tempDir}")"
fi
keyFile="${tempDir}/autoenroll.key"
csrFile="${tempDir}/autoenroll.csr"
pemFile="${tempDir}/autoenroll.pem"
pk12File="${tempDir}/autoenroll.p12"
opensslConfFile="${tempDir}/openssl.conf"

## Blank User variables available to all functions.
userLDAP=
userDN=
userEmail=
machineName=
domainName=
userFoundBool=false
computerFoundBool=false
userExpiredBool=false
computerExpiredBool=false


########################
## Check to make sure that the certificate server is available.
check_server_availability() {
	serverAddr="$(awk -F '/' '{ print $3 }' <<< "${urlMachine}")"
	serverPort='443'
	
	nc -z "${serverAddr}" "${serverPort}" 2>/dev/null
	
	if [ "$?" -eq "0" ]; then
		# Server is reachable.
		printf '%s "%s" %s\n' 'Server' "${serverAddr}:${serverPort}" 'reachable. Continuing.'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf '%s "%s" %s\n' 'Server' "${serverAddr}:${serverPort}" 'reachable. Continuing.')"
		fi
	else
		# Server is not reachable.
		printf '%s "%s" %s\n' 'Critical Error: Server' "${serverAddr}:${serverPort}" 'is not reachable.'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf '%s "%s" %s\n' 'Critical Error: Server' "${serverAddr}:${serverPort}" 'is not reachable.')"
		fi
		remove_temp_files
		if [ -z "${silentExecute}" ]; then
			dialogTitle='Could Not Connect'
			userNotification='Unable to connect to the certificate server. Please verify that you are on the corporate network or connected via VPN.'
			"${JAMF_HELPER_APP}" -windowType 'utility' -title "${dialogTitle}" -icon "${JAMF_ICON}" -description "${userNotification}" -button1 "${YES_BUTTON}" -defaultButton 1 -startlaunchd >/dev/null 2>&1 &
		fi
		exit 25
	fi
}

########################
## Notify the end-user of the final result.
notify_results() {
	dialogTitle='Certificate Enrollment Status'
	if [ -n "${1}" ]; then
		if [ "${1}" == 'true' ]; then
			if [ "${userFoundBool}" == false ] || [ "${userExpiredBool}" == true ]; then
				userNotification="${userNotification}Problem installing personal certificate. Please ensure you are on the corporate network. If you continue to experience issues, please restart your computer and try again.^^"
			else
				userNotification="${userNotification}Personal certificate successfully installed.^^"
			fi
		else
			userNotification="${userNotification}Personal certificate already installed.^^"
		fi
	fi
	
	if [ -n "${2}" ]; then
		if [ "${2}" == 'true' ]; then
			if [ "${computerFoundBool}" == false ] || [ "${computerExpiredBool}" == true ]; then
				userNotification="${userNotification}Problem installing machine certificate. Please ensure you are on the corporate network.^^"
			else
				userNotification="${userNotification}Machine certificate successfully installed.^^"
			fi
		else
			userNotification="${userNotification}Machine certificate already installed.^^"
		fi
	fi
	
	"${JAMF_HELPER_APP}" -windowType 'utility' -title "${dialogTitle}" -icon "${JAMF_ICON}" -description "$(tr '^' '\n' <<< ${userNotification})" -button1 "${YES_BUTTON}" -defaultButton 1 -startlaunchd >/dev/null 2>&1 &
}

########################
## Check to ensure we're bound to AD and exit if not.
check_bind_and_name() {
	domainName="$(/usr/sbin/dsconfigad -show | awk '/Active Directory Domain/ { print $NF }')"
	machineName="$(/usr/sbin/dsconfigad -show | awk '/Computer Account/ { print $NF }' | tr -d '$')"

	if [ "${domainName}" != "sea.corp.expecn.com" ]; then
		printf 'Critical Error: You are not bound to AD.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Critical Error: You are not bound to AD.\n')"
		fi
		remove_temp_files
		exit 78 # EX_CONFIG
	fi
}

########################
## Build the directory information for user and computer.
get_directory_info() {
	#  Gather some active directory attributes for the user and machine.
	userDN="$(/usr/bin/dscl /Search -read /Users/${userSamID} distinguishedName 2>/dev/null | grep -e 'CN=' -e 'OU=' -e 'DC=' | tr -d '\n' | awk -F ':' '{ print $NF; exit }')"
	userEmail="$(/usr/bin/dscl /Search -read /Users/${userSamID} EMailAddress 2>/dev/null | awk -F '[ :]' '/EMailAddress:/ && /@/ { print $NF; exit }')"
	userUPN="$(/usr/bin/dscl /Search -read /Users/${userSamID} userPrincipalName 2>/dev/null | awk '/userPrincipalName:/ { print $NF; exit }')"
	
	##  While we are still in user context, get info on the machine
	machineDN="$(/usr/bin/dscl "${DSCL_AD_SEARCH}" -read /Computers/${machineName}\$ distinguishedName 2>/dev/null | grep -e 'CN=' -e 'OU=' -e 'DC=' | tr -d '\n' | awk -F ':' '{ print $NF; exit }')"
	
	# Below is for testing to validate all the variables are being created correctly
# 	printf 'Login SAMID is %s\n.' "${MY_SAMID}"
# 	printf 'DN: %s.\n' "${userDN}"
# 	printf 'Email is %s.\n' "${userEmail}"
# 	printf 'UPN is  %s.\n' "${userUPN}"
# 	exit 78
	
	unset ouAttribute
	oucnt='0'
	tabNext=''
	newLine=$'\n'
	while read i; do
		if [ "$(grep -c '^CN' <<< "${i}")" -gt '0' ]; then
			cnAttribute="$(awk -F '=' '{ print $NF }' <<< "${i}")"
		fi
		if [ "$(grep -c '^OU' <<< "${i}")" -gt '0' ]; then
			ouAttribute="$(printf '%s%s%s.organizationalUnitName = %s' "${ouAttribute}" "${tabNext}" "${oucnt}" "$(awk -F '=' '{ print $NF }' <<< "${i}")")${newLine}"
			let oucnt++
			tabNext=$'\t'
		fi
	done <<< "$(tr ',' '\n' <<< ${userDN})"
}

########################
## Generate csr with openssl for a machine
generate_csr_machine() {
	/usr/bin/openssl req -new -batch -newkey rsa:2048 -nodes -keyout "${keyFile}" -out "${csrFile}" -config "${opensslConfFile}" 2>/dev/null
}

########################
## Generate csr with openssl for a user
generate_csr_user() {
	/usr/bin/openssl req -new -batch -newkey rsa:2048 -nodes -keyout "${keyFile}" -out "${csrFile}" -config "${opensslConfFile}" 2>/dev/null
}

########################
## curl the csr up
curl_csr() {
	# Now to post this to the Web Enrollment page.
	# We'll need to capture the ReqID when it finishes. If it's a 2k8 domain, we just don't use it.
	printf 'Connecting to %s.\n' "${urlCA}/certfnsh.asp"
	if [ -z "${silentExecute}" ]; then
		logger ${LOGGER_FLAGS} "$(printf 'Connecting to %s.\n' "${urlCA}/certfnsh.asp")"
	fi
	requestID="$(curl --digest -u "${caUserID}:${caPassword}" --data-urlencode "CertRequest=$(cat ${csrFile})" -d SaveCert=yes -d Mode=newreq -d "CertAttrib=CertificateTemplate:${certType}" "${urlCA}/certfnsh.asp" 2>/dev/null | grep -o 'ReqID=[0-9]\+' | awk -F '=' '{ print $NF; exit }')"
	
	printf 'requestID is %s.\n' "${requestID}"
	if [ -z "${silentExecute}" ]; then
		logger ${LOGGER_FLAGS} "$(printf 'requestID is %s.\n' "${requestID}")"
	fi
		
	# Verify if we actually have a request ID - if not, we need to bail.
	if [ -z "${requestID}" ]; then 
		printf '%s\n' "Critical Error: Didn't receive a request ID from the Certificate Authority."
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf '%s\n' "Critical Error: Didn't receive a request ID from the Certificate Authority.")"
		fi
		remove_temp_files
		exit 69 #EX_UNAVAILABLE
	fi
}

########################
## curl down the cert after tricking the CA into thinking we are a Windows machine
curl_cert() {
	curl -k -o "${pemFile}" -A "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5" --digest -u "${caUserID}:${caPassword}" "${urlCA}/certnew.cer?ReqID=${requestID}&Enc=b64" 2>/dev/null
}


########################
## Pack the cert up and import it ito the keychain
pack_and_import() {
	## Build the cert and private key into a PKCS12
	/usr/bin/openssl pkcs12 -export -in "${pemFile}" -inkey "${keyFile}" -out "${pk12File}" -name "${machineName}" -passout pass:pass
	if [ "$(grep -c 'login.keychain' <<< "${keychainPath}")" -gt '0' ]; then
		launchctl bsexec "${userConsolePID}" /usr/bin/security import "${pk12File}" -x -k "${keychainPath}" -f pkcs12 -P pass
	else
		/usr/bin/security import "${pk12File}" -x -k "${keychainPath}" -f pkcs12 -P pass
	fi
}

########################
## The below creates the specific certificate format that is needed to make it look exactly like an auto-enrolled cert on a Windows box
## Notice that an assumption is made that this will ALWAYS be a device in the Mac DN.
build_openssl_conf_Machine() {
	##  First validate that the Mac is in the correct OU
	# printf 'Machine DN is %s.\n' "${machineDN}"

	if [ "$(grep -c 'OU=Macs,OU=Clients,DC=SEA,DC=CORP,DC=EXPECN,DC=com' <<< "${machineDN}")" -gt '0' ]; then
		##  Looks like the DN matchs, go ahead and create the Config
		printf 'The DN was found.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'The DN was found.\n')"
		fi
		
		printf '%s' "	[ req ]
	default_bits            = 2048
	default_md              = sha1
	#default_keyfile         = key.pem
	distinguished_name      = req_distinguished_name
	prompt                  = no
	string_mask             = nombstr
	req_extensions          = v3_req

	[ req_distinguished_name ]
	0.domainComponent=com
	1.domainComponent=EXPECN
	2.domainComponent=CORP
	3.domainComponent=SEA
	0.organizationalUnitName=Clients
	1.organizationalUnitName=Macs
	commonName=${machineName}

	[ v3_req ]
	basicConstraints        = CA:FALSE
	keyUsage                = nonRepudiation, digitalSignature
	subjectAltName          = @alt_names

	[ alt_names ]
	DNS.1 = ${machineName}.${domainName}
	DNS.2 = ${machineName} " > "${opensslConfFile}"


	else
		printf 'Critical Error: This Mac was not found in AD.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Critical Error: This Mac was not found in AD.\n')"
		fi
		remove_temp_files
		exit 78
	fi
}

########################
## The below creates the specific certificate format that is needed to make it look exactly like an auto-enrolled cert on a Windows box
build_openssl_conf_User() {
	##  Here we actually build the config OpenSSL will use to craft the certificate request

	printf '%s' "	[ req ]
	default_bits            = 2048
	default_md              = sha1
	distinguished_name      = req_distinguished_name
	prompt                  = no
	string_mask             = nombstr
	req_extensions          = v3_req

	[ req_distinguished_name ]
	0.domainComponent = com
	1.domainComponent = EXPECN
	2.domainComponent = CORP
	3.domainComponent = SEA
	${ouAttribute}	commonName = ${cnAttribute}
	emailAddress = ${userEmail}

	[ v3_req ]
	basicConstraints        = CA:FALSE
	keyUsage                = nonRepudiation, digitalSignature, keyEncipherment
	subjectAltName          = otherName:1.3.6.1.4.1.311.20.2.3;UTF8:${userUPN}, email:${userEmail}
	" > "${opensslConfFile}"
}

########################
## find_cert determines if the certificates are already installed.
find_cert() {
	keychainPath="/Users/${userSamID}/Library/Keychains/login.keychain"
	securityOut="$(/usr/bin/security find-certificate -a -c "${cnAttribute}" "${keychainPath}" 2>/dev/null)"
	if [ "$(grep -c 'EXPEDIA INTERNAL 1U' <<< "${securityOut}")" -gt '0' ]; then
		printf 'User certificate found.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'User certificate found.\n')"
		fi
		userFoundBool=true
	fi
	
	keychainPath="/Library/Keychains/System.keychain"
	securityOut="$(/usr/bin/security find-certificate -a -c "${machineName}" "${keychainPath}" 2>/dev/null)"
	if [ "$(grep -c 'EXPEDIA INTERNAL 1C' <<< "${securityOut}")" -gt '0' ]; then
		printf 'Computer certificate found.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Computer certificate found.\n')"
		fi
		computerFoundBool=true
	fi
}

########################
## find_cert_exp determines if existing certificates are expired.
find_cert_exp() {
	case "${1}" in
	'USER')
		keychainPath="/Users/${userSamID}/Library/Keychains/login.keychain"
		securityOut="$(/usr/bin/security find-certificate -a -c "${cnAttribute}" -p "${keychainPath}" > ${tempDir}/certcheck.pem)"
		while [ "$(grep -c 'END CERTIFICATE' "${tempDir}/certcheck.pem")" -gt '0' ] && [ "$(openssl x509 -noout -in "${tempDir}/certcheck.pem" -issuer | grep -ic 'EXPEDIA INTERNAL 1U')" -eq '0' ]; do
			sed -i '' "1,$(grep -n 'END CERTIFICATE' "${tempDir}/certcheck.pem" | awk -F: '{ print $1; exit }')d" "${tempDir}/certcheck.pem"
		done
		if [ "$(grep -c 'END CERTIFICATE' "${tempDir}/certcheck.pem")" -eq '0' ]; then
			userExpiredBool=true
		else
			certExpire="$(openssl x509 -noout -in "${tempDir}/certcheck.pem" -dates | awk -F '=' '/notAfter/ { print $NF }')"
			certDate="$(date -j -f '%b %d %H:%M:%S %Y %Z' "${certExpire}" +%s)"
			nowDate="$(date +%s)"
			[ "${certDate}" -lt "${nowDate}" ] && userExpiredBool=true
		fi
	;;
	'COMPUTER')
		keychainPath="/Library/Keychains/System.keychain"
		securityOut="$(/usr/bin/security find-certificate -a -c "${machineName}" -p "${keychainPath}" > "${tempDir}/certcheck.pem")"
		while [ "$(grep -c 'END CERTIFICATE' "${tempDir}/certcheck.pem")" -gt '0' ] && [ "$(openssl x509 -noout -in "${tempDir}/certcheck.pem" -issuer | grep -ic 'EXPEDIA INTERNAL 1C')" -eq '0' ]; do
			sed -i '' "1,$(grep -n 'END CERTIFICATE' "${tempDir}/certcheck.pem" | awk -F: '{ print $1; exit }')d" "${tempDir}/certcheck.pem"
		done
		if [ "$(grep -c 'END CERTIFICATE' "${tempDir}/certcheck.pem")" -eq '0' ]; then
			computerExpiredBool=true
		else
			certExpire="$(openssl x509 -noout -in ${tempDir}/certcheck.pem -dates | awk -F '=' '/notAfter/ { print $NF }')"
			certDate="$(date -j -f '%b %d %H:%M:%S %Y %Z' "${certExpire}" +%s)"
			nowDate="$(date +%s)"
			[ "${certDate}" -lt "${nowDate}" ] && computerExpiredBool=true
		fi
	;;
	*)
		printf 'Critical Error: Problem locating certificate expiration.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Critical Error: Problem locating certificate expiration.\n')"
		fi
		remove_temp_files
		exit 67
	;;
	esac
}


########################
## check_CAs makes sure the root/user chain/computer chain certificates are installed.
check_CAs() {
	securityOut="$(/usr/bin/security find-certificate -a)"

	##  Check for the Root certificate
	if [ "$(grep -c "\"alis\"<blob>=\"Expedia MS Root CA (2048)\"" <<< "${securityOut}")" -gt '0' ]; then
		printf 'Root certificate found.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Root certificate found.\n')"
		fi
	else
		printf 'Installing Root certificate.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Installing Root certificate.\n')"
		fi
		curl -k -o "${tempDir}/Root.crt" "https://certs.sea.corp.expecn.com/ca/internal/Root.crt" 2>/dev/null
		/usr/bin/security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain -p ssl -p smime -p codeSign -p IPSec -p iChat -p basic -p swUpdate -p pkgSign -p pkinitClient -p pkinitServer -p eap -p timestamping "${tempDir}/Root.crt"
	fi

	##  Check for the User chain certificate
	if [ "$(grep -c "\"alis\"<blob>=\"Expedia Internal 1U\"" <<< "${securityOut}")" -gt '0' ]; then
		printf 'User chain certificate found.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'User chain certificate found.\n')"
		fi
	else
		printf 'Installing User chain certificate.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Installing User chain certificate.\n')"
		fi
		curl -k -o "${tempDir}/Internal1U.crt" "https://certs.sea.corp.expecn.com/ca/internal/Internal1U.crt" 2>/dev/null
		/usr/bin/security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain "${tempDir}/Internal1U.crt"
	fi

	##  Check for the Computer chain certificate
	if [ "$(grep -c "\"alis\"<blob>=\"Expedia Internal 1C\"" <<< "${securityOut}")" -gt '0' ]; then
		printf 'Computer chain certificate found.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Computer chain certificate found.\n')"
		fi
	else
		printf 'Installing Computer chain certificate.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Installing Computer chain certificate.\n')"
		fi
		curl -k -o "${tempDir}/Internal1C.crt" "https://certs.sea.corp.expecn.com/ca/internal/Internal1C.crt" 2>/dev/null
		/usr/bin/security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain "${tempDir}/Internal1C.crt"
	fi
}

########################
## Last thing to do is delete the temporary file area.
remove_temp_files() {
	if [ -d "${tempDir}" ]; then
		srm -r "${tempDir}"
		printf 'Temp files removed.\n'
		if [ -z "${silentExecute}" ]; then
			logger ${LOGGER_FLAGS} "$(printf 'Temp files removed.\n')"
		fi
	fi
}

########################
## Test modifying the keychain, without prompting, to see if it's unlocked.
test_keychain_modify() {
	# Unload the SecurityAgent to disable prompting for credentials. Ensures failure is silent.
	launchctl unload /System/Library/LaunchDaemons/com.apple.security.agentMain.plist
	
	# Attempt to insert a test generic password into the keychain.
	launchctl bsexec "${userConsolePID}" /usr/bin/security add-generic-password -a "${SECURITY_TEST_ACCOUNT}" -s "${SECURITY_TEST_SERVICE}" -w "${SECURITY_TEST_PASSWORD}" -A "${keychainPath}" > /dev/null 2>&1
	if [ "${?}" -ne '0' ]; then
		keychainModifiable='false'
	fi
	
	# Load the SecurityAgent to allow prompting for credentials after check is complete.
	launchctl load /System/Library/LaunchDaemons/com.apple.security.agentMain.plist
	
	# Verify that the test item was successfully inserted.
	/usr/bin/security find-generic-password -a "${SECURITY_TEST_ACCOUNT}" "${keychainPath}" > /dev/null 2>&1
	if [ "${?}" -ne '0' ]; then
		keychainModifiable='false'
	fi
	
	# Delete the test item to clean up after ourselves.
	/usr/bin/security delete-generic-password -a "${SECURITY_TEST_ACCOUNT}" "${keychainPath}" > /dev/null 2>&1
	if [ "${?}" -ne '0' ]; then
		keychainModifiable='false'
	fi
	
	# No failure yet? Success!
	if [ -z "${keychainModifiable}" ]; then
		keychainModifiable='true'
	fi
	
	if [ "${keychainModifiable}" == 'true' ]; then
		printf 'Successfully modified keychain.\n'
	else
		printf 'Could not modify keychain.\n'
	fi
}

####  Script begins here....

###  Validate that the CA certs are present and install if they are not present
check_CAs

## Verify that the certificates are in place
check_bind_and_name
get_directory_info
find_cert
if [ "${userFoundBool}" == true ]; then
	find_cert_exp "USER"
fi

if [ "${computerFoundBool}" == true ]; then
	find_cert_exp "COMPUTER"
fi

unset userModified
### Now install the user cert if necessary
if [ "${userFoundBool}" == false ] || [ "${userExpiredBool}" == true ] ; then
	check_server_availability
	
	unset keychainModifiable
	printf 'Generating User cert.\n'
	if [ -z "${silentExecute}" ]; then
		logger ${LOGGER_FLAGS} "$(printf 'Generating User cert.\n')"
	else
		# If silently executing, verify that I am able to silently modify the keychain.
		keychainPath="/Users/${userSamID}/Library/Keychains/login.keychain"
		test_keychain_modify
	fi
	
	if [ "${keychainModifiable}" != 'false' ]; then
		urlCA="${urlUser}"
		build_openssl_conf_User
		generate_csr_user
		certType="${certTypeUser}"
		curl_csr
		curl_cert
		keychainPath="/Users/${userSamID}/Library/Keychains/login.keychain"
		pack_and_import
		userModified='true'
	fi
else
	printf 'User certificate is current.\n'
	if [ -z "${silentExecute}" ]; then
		logger ${LOGGER_FLAGS} "$(printf 'User certificate is current.\n')"
	fi
	userModified='false'
fi

unset computerModified
# For now, we will not be installing/generating the computer certificate.
# Leaving it here because we will likely need this in the future.
#
# ### Next install the Computer Cert
# if [ "${computerFoundBool}" == false ] || [ "${computerExpiredBool}" == true ]; then
# 	check_server_availability
# 	printf 'Generating Computer cert.\n'
# 	if [ -z "${silentExecute}" ]; then
# 		logger ${LOGGER_FLAGS} "$(printf 'Generating Computer cert.\n')"
# 	fi
# 	urlCA="${urlMachine}"
# 	build_openssl_conf_Machine
# 	generate_csr_machine
# 	certType="${certTypeMachine}"
# 	curl_csr
# 	curl_cert
# 	keychainPath="/Library/Keychains/System.keychain"
# 	pack_and_import
# 	computerModified='true'
# else
# 	printf 'Computer certificate is current.\n'
# 	if [ -z "${silentExecute}" ]; then
# 		logger ${LOGGER_FLAGS} "$(printf 'Computer certificate is current.\n')"
# 	fi
# 	computerModified='false'
# fi

find_cert
if [ "${userFoundBool}" == true ]; then
	find_cert_exp "USER"
fi

if [ "${computerFoundBool}" == true ]; then
	find_cert_exp "COMPUTER"
fi

if [ -z "${silentExecute}" ]; then
	notify_results "${userModified}" "${computerModified}"
fi

remove_temp_files
exit 0