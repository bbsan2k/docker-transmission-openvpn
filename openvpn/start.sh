#!/bin/sh
set -x
vpn_provider="$(echo $OPENVPN_PROVIDER | tr '[A-Z]' '[a-z]')"
vpn_provider_configs="/etc/openvpn/$vpn_provider"
if [ ! -d "$vpn_provider_configs" ]; 
then
	echo "Could not find OpenVPN provider: $OPENVPN_PROVIDER"
	echo "Please check your settings."
	exit 1
else 
	echo $OPENVPN_PROVIDER > /volumes/config/openvpn-provider.txt
fi

echo "Using OpenVPN provider: $OPENVPN_PROVIDER"

if [ ! -z "$OPENVPN_CONFIG" ]
then
	if [ -f $vpn_provider_configs/"${OPENVPN_CONFIG}".ovpn ];
  	then
		echo "Starting OpenVPN using config ${OPENVPN_CONFIG}.ovpn"
		echo $OPENVPN_CONFIG > /volumes/config/openvpn-config.txt
		OPENVPN_CONFIG=$vpn_provider_configs/${OPENVPN_CONFIG}.ovpn
	else
		echo "Supplied config ${OPENVPN_CONFIG}.ovpn could not be found."
		echo "Using default OpenVPN gateway for provider ${vpn_provider}"
		OPENVPN_CONFIG=$vpn_provider_configs/default.ovpn
	fi
else
	echo "No VPN configuration provided. Using default."
	OPENVPN_CONFIG=$vpn_provider_configs/default.ovpn
fi

#Check for OpenVPN Credentials 
openvpn_credentials="/volumes/config/openvpn-credentials.txt"
if [ ! -f "$openvpn_credentials" ];
then 
	# add OpenVPN user/pass if not on storage
	if [ "${OPENVPN_USERNAME}" = "**None**" ] || [ "${OPENVPN_PASSWORD}" = "**None**" ] ; then
	 echo "OpenVPN credentials not set. Exiting."
	 exit 1
	else
	  echo "Setting OPENVPN credentials..."
	  mkdir -p /volumes/config
	  echo $OPENVPN_USERNAME > /volumes/config/openvpn-credentials.txt
	  echo $OPENVPN_PASSWORD >> /volumes/config/openvpn-credentials.txt
	  chmod 600 /config/openvpn-credentials.txt
	fi
else 
	echo "$openvpn_credentials found. Proceeding with credentials from disk"
fi

#Check for Transmission Credentials 
transmission-credentials="/volumes/config/transmission-credentials.txt"
if [ ! -f "$transmission-credentials" ];
then
	# add transmission credentials from env vars
	echo $TRANSMISSION_RPC_USERNAME > /volumes/config/transmission-credentials.txt
	echo $TRANSMISSION_RPC_PASSWORD >> /volumes/config/transmission-credentials.txt
else 
	echo "$transmission-credentials found. Proceeding with credentials from disk"
fi

#Check for Transmission Configuration 
transmission-configuration="/volumes/data/transmission-home/settings.json"
if [ ! -f "$transmission-configuration" ];
then
	# Persist transmission settings for use by transmission-daemon
	dockerize -template /etc/transmission/environment-variables.tmpl:/etc/transmission/environment-variables.sh /bin/true
else 
	echo "$transmission-configuration found. Proceeding with configuration from disk"
fi

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