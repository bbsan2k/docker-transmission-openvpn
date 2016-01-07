#!/bin/sh

#Check for Transmission Configuration 
transmission_configuration="/volumes/data/transmission-home/settings.json"
if [ ! -f "$transmission-configuration" ];
then
	# Source our persisted env variables from container startup
	. /etc/transmission/environment-variables.sh
else 
	echo "$transmission_configuration found. Proceeding with configuration from disk"
fi
	
tun0ip=$(ifconfig tun0 | sed -n '2 p' | awk '{print $2}' | cut -d: -f2)
echo "Updating TRANSMISSION_BIND_ADDRESS_IPV4 to tun0 ip: ${tun0ip}"
export TRANSMISSION_BIND_ADDRESS_IPV4=${tun0ip}


#Check for Transmission Configuration 
if [ ! -f "$transmission_configuration" ];
then
	echo "Generating transmission settings.json from env variables"
	# Ensure TRANSMISSION_HOME is created
	mkdir -p ${TRANSMISSION_HOME}
	dockerize -template /etc/transmission/settings.tmpl:${TRANSMISSION_HOME}/settings.json /bin/true
else
	echo "$transmission_configuration found. Proceeding with configuration from disk"
fi

if [ ! -e "/dev/random" ]; then
  # Avoid "Fatal: no entropy gathering module detected" error
  echo "INFO: /dev/random not found - symlink to /dev/urandom"
  ln -s /dev/urandom /dev/random
fi

echo "STARTING TRANSMISSION"
exec /usr/bin/transmission-daemon -g ${TRANSMISSION_HOME} --logfile ${TRANSMISSION_HOME}/transmission.log &

if [ "$OPENVPN_PROVIDER" = "PIA" ]
then
    echo "STARTING PORT UPDATER"
    exec /etc/transmission/periodicUpdates.sh &
else
    echo "NO PORT UPDATER FOR THIS PROVIDER"
fi

echo "Transmission startup script complete."
