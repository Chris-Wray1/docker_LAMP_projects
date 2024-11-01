#!/bin/bash
clear

# Define variables
while getopts f: flag
do
	case "${flag}" in
		f) filename="$(echo -e "${OPTARG}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')";;
	esac
done

# Set filename to default if empty
if [ -z "${filename}" ];
then
	filename="container.config";
fi

# Confirm that the file exists
if [ ! -f "${filename}" ];
then 
	echo "$filename is not a file." >&2;
	exit 1;
fi

echo ""
echo "[+] Using the configuration found in $filename";
echo ""
	
#########################################################
#														#
#	This section creates the dockercompose yaml files 	#
#														#
#########################################################

volume=""
section_regex="^[[:blank:]]*\[[[:blank:]]*([[:alpha:]_][[:alnum:]_-]*)[[:blank:]]*\][[:blank:]]*(#.*)?$"
entry_regex_quotes="^[[:blank:]]*([[:alpha:]_][[:alnum:]_]*)[[:blank:]]*=[[:blank:]]*('[^']+'|\"[^\"]+\")[[:blank:]]*(#.*)*$"
entry_regex_loose="^[[:blank:]]*([[:alpha:]_][[:alnum:]_]*)[[:blank:]]*=[[:blank:]]*([^#]*[^#[:blank:]])*"

while read -r line
do
	# Ignore if the line is empty
	if [ -z "${line}" ];
	then
		continue;
	fi

	# Set the volume label from section name
	[[ $line =~ $section_regex ]] && {
		volume=${BASH_REMATCH[1]}
		cp ./apache/dockercompose.txt ./${volume}-compose.yml
		sed -i "s/{volume}/$volume/g" ./${volume}-compose.yml
		continue
	}

	# Ignore the line if no volume label set
	if [ -z "${volume}" ];
	then
		continue;
	fi

	value=""
	key=""
	# Process key/value pairs 
	## When value is in quotes
	if [[ $line =~ $entry_regex_quotes ]]
	then
		value=${BASH_REMATCH[2]#[\'\"]} # strip quotes
		value=${value%[\'\"]}
		key=${BASH_REMATCH[1]}
		sed -i "s/{${key}}/${value}/g" ./${volume}-compose.yml
		continue
	fi
	## When value is not quoted
	if [[ $line =~ $entry_regex_loose ]]
	then
		value=${BASH_REMATCH[2]}
		key=${BASH_REMATCH[1]}
		sed -i "s/{${key}}/${value}/g" ./${volume}-compose.yml
		continue
	fi
done < "$filename"

#########################################################
#														#
#	This section proesses the dockercompose yaml files 	#
#														#
#########################################################

echo "[+] Building your Container(s)"
echo "	[+] Each container will have its own subfolder"
echo ""


## Find the localhost IP Address 
localhost=$(sed -n '/localhost/p' /etc/hosts | head -1)
localhost=${localhost% *}

## Loop through all composer files that match
for f in *-compose.yml; do
	## Get line number of volume info
	lineNum="$(grep -n "volumes" "$f" | head -n 1 | cut -d: -f1)"
	((lineNum++))

	## Define the Volume name (Container)
	volume=$(sed "${lineNum}q;d" "$f")
	volume=${volume#*- }
	volume=${volume%:/*}

	## Display Container working on
	echo " ---> ${volume} conntainer <---"

	## Check that all variables in the yaml file have been set
	if [[ $(grep -o "{*}" "$f" | wc -l) > 0 ]]
	then
		echo "[!] Configuration Error"
		echo ""
		continue
	fi

	## Create the subfolders for the Volume
	mkdir -p $volume/logs
	mkdir -p $volume/public
	## Uncomment if you need to keep the DB after rebuilds
	## BUT you will need to use the alternative dockercompose file in the apache folder
#	mkdir -p $volume/db

	## Create the default index file
	if [ ! -f ./$volume/public/index.php ];
	then
		cp ./apache/index.txt ./$volume/public/index.php
		sed -i "s/xxxx/$volume/g" ./$volume/public/index.php
	fi

	## Create specific Dockerfile
	cp ./apache/dockerfile.txt ./apache/$volume-Dockerfile
	sed -i "s/xxxx/$volume/g" ./apache/$volume-Dockerfile

	## Create virtual host file
	cp ./apache/apache-conf.txt ./apache/$volume.conf
	sed -i "s/xxxx/$volume/g" ./apache/$volume.conf

	## Build docker containers
	docker compose -f "$f" up -d > /dev/null

	## Leave a line space before the next build
	echo ""

	## Update hosts file if needed
	if [[ $(grep -o "${volume}.localhost" /etc/hosts | wc -l) < 1 ]]
	then
		sudo -- sh -c -e "echo '${localhost} ${volume}.localhost' >> /etc/hosts";

		if [ -n "$(grep "${volume}.localhost" /etc/hosts)" ]
		then
			echo "HOSTS file was succesfully updated with ${volume}.localhost";
		else
			echo "Failed to update HOSTS file, please update manually!";
		fi
		echo ""
	fi
done

## Tidy up apache install process
rm ./apache/*-Dockerfile
rm ./apache/*.conf
rm ./*-compose.yml
