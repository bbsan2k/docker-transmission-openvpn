#!/bin/sh
set -x

#Check for OpenVPN Provider 
if [ ! -f "/volumes/config/openvpn-provider.txt" ]; then 
	vpn_provider="$(echo $OPENVPN_PROVIDER | tr '[A-Z]' '[a-z]')"
	vpn_provider_configs="/etc/openvpn/$vpn_provider"
	if [ ! -d "$vpn_provider_configs" ]; then
		echo "Could not find OpenVPN provider: $OPENVPN_PROVIDER"
		echo "Please check your settings."
		exit 1
	else 
		echo $OPENVPN_PROVIDER > /volumes/config/openvpn-provider.txt
	fi
else 
	vpn_provider=`cat /volumes/config/openvpn-provider.txt`
	vpn_provider_configs="/etc/openvpn/$vpn_provider"
fi

echo "Using OpenVPN provider: $vpn_provider"

##Check for OpenVPN Provider Configuration
#Check enviroment variable OPENVPN_CONFIG has been provided by user
if [ ! -z "$OPENVPN_CONFIG" ]; then
	#Check OPENVPN config exists under provider dir
	if [ -f $vpn_provider_configs/"${OPENVPN_CONFIG}".ovpn ]; then	
  		echo "Starting OpenVPN using config ${OPENVPN_CONFIG}.ovpn"
		echo $OPENVPN_CONFIG > /volumes/config/openvpn-config.txt
		OPENVPN_CONFIG=$vpn_provider_configs/${OPENVPN_CONFIG}.ovpn
	#OPENVPN config does not exist under provider dir using default
	else	#OPENVPN config does not exist under provider dir switching to default
		echo "Supplied config ${OPENVPN_CONFIG}.ovpn could not be found."
		echo "Using default OpenVPN gateway for provider ${vpn_provider}"
		OPENVPN_CONFIG=$vpn_provider_configs/default.ovpn
	fi
#No user OPENVPN_CONFIG provided checking for configuration on disk
elif [ -f "/volumes/config/openvpn-config.txt"]; then
	openvpn_config=`cat /volumes/config/openvpn-config.txt`
	OPENVPN_CONFIG=$vpn_provider_configs/${openvpn_config}.ovpn
#No user OPENVPN_CONFIG provided and no on disk. Not happening.
else 
	echo "No VPN configuration provided. Using default."
	OPENVPN_CONFIG=$vpn_provider_configs/default.ovpn
fi

#Check for OpenVPN Credentials 
#Set user varibale to path of credentials on disk and check for non existence else exists and move on
openvpn_credentials="/volumes/config/openvpn-credentials.txt"
if [ ! -f "$openvpn_credentials" ]; then 
	# Exit if OPENVPN credentials haven't been provided else add OpenVPN credentials to disk
	if [ "${OPENVPN_USERNAME}" = "**None**" ] || [ "${OPENVPN_PASSWORD}" = "**None**" ] ; then
	 echo "OpenVPN credentials not set. Exiting."
	 exit 1
	else
	  echo "Setting OPENVPN credentials..."
	  mkdir -p /volumes/config
	  echo $OPENVPN_USERNAME > /volumes/config/openvpn-credentials.txt
	  echo $OPENVPN_PASSWORD >> /volumes/config/openvpn-credentials.txt
	  chmod 600 /volumes/config/openvpn-credentials.txt
	fi
else 
	echo "$openvpn_credentials found. Proceeding with OpenVPN credentials from disk"
fi

#Check for Transmission Credentials 
#Set user varibale to path of credentials on disk and check for non existence else exists and move on
transmission_credentials="/volumes/config/transmission-credentials.txt"
if [ ! -f "$transmission_credentials" ]; then
	# add transmission credentials from env vars
	echo $TRANSMISSION_RPC_USERNAME > /volumes/config/transmission-credentials.txt
	echo $TRANSMISSION_RPC_PASSWORD >> /volumes/config/transmission-credentials.txt
else 
	echo "$transmission_credentials found. Proceeding with Transmission credentials from disk"
fi

#Check for Transmission Configuration 
#Set user varibale to path of configuration on disk and check for non existence else exists and move on
transmission_configuration="/volumes/data/transmission-home/settings.json"
if [ ! -f "$transmission_configuration" ]; then
	# Persist transmission settings for use by transmission-daemon
	dockerize -template /etc/transmission/environment-variables.tmpl:/etc/transmission/environment-variables.sh /bin/true
else 
	echo "$transmission_configuration found. Proceeding with Transmission configuration from disk"
fi

#Bring all this shit together and bring up a VPN tunnel.
exec openvpn --config "$OPENVPN_CONFIG"

#Force Google DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

file="/etc/hosts"
if [ -f "$file" ]
then
	echo "$file found."
else
	echo "$file not found."
fi