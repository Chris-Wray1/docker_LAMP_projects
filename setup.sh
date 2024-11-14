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

project=""
section_regex="^[[:blank:]]*\[[[:blank:]]*([[:alpha:]_][[:alnum:]_-]*)[[:blank:]]*\][[:blank:]]*(#.*)?$"
entry_regex_quotes="^[[:blank:]]*([[:alpha:]_][[:alnum:]_]*)[[:blank:]]*=[[:blank:]]*('[^']+'|\"[^\"]+\")[[:blank:]]*(#.*)*$"
entry_regex_loose="^[[:blank:]]*([[:alpha:]_][[:alnum:]_]*)[[:blank:]]*=[[:blank:]]*([^#]*[^#[:blank:]])*"
region="Europe"
city="London"

while read -r line
do
	# Ignore if the line is empty
	if [ -z "${line}" ];
	then
		continue;
	fi

	# Set the project label from section name
	[[ $line =~ $section_regex ]] && {
		project=${BASH_REMATCH[1]}
		cp ./apache/dockercompose.txt ./${project}-compose.yml
		sed -i "s/{project}/$project/g" ./${project}-compose.yml
		continue
	}

	# Ignore the line if no project label set
	if [ -z "${project}" ];
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
		sed -i "s/{${key}}/${value}/g" ./${project}-compose.yml
		if [[ $key == "region" ]] then 
			region=${value}
		fi
		if [[ $key == "city" ]] then 
			city=${value}
		fi
		continue
	fi
	## When value is not quoted
	if [[ $line =~ $entry_regex_loose ]]
	then
		value=${BASH_REMATCH[2]}
		key=${BASH_REMATCH[1]}
		sed -i "s/{${key}}/${value}/g" ./${project}-compose.yml
		if [[ $key == "region" ]] then 
			region=${value}
		fi
		if [[ $key == "city" ]] then 
			city=${value}
		fi
		continue
	fi
done < "$filename"

#########################################################
#														#
#	This section proesses the dockercompose yaml files 	#
#														#
#########################################################

echo "[+] Building your Container(s)"
echo "	[+] Each project will have its own subfolder"
echo "	[+] with a DB instance"
echo ""


## Find the localhost IP Address 
localhost=$(sed -n '/localhost/p' /etc/hosts | head -1)
localhost=${localhost% *}

## Loop through all composer files that match
for f in *-compose.yml; do
	## Get line number of project info
	lineNum="$(grep -n "volumes" "$f" | head -n 1 | cut -d: -f1)"
	((lineNum++))

	## Define the project name
	project=$(sed "${lineNum}q;d" "$f")
	project=${project#*- }
	project=${project%:/*}

	## Display Container working on
	echo " ---> ${project} project <---"

	## Check that all variables in the yaml file have been set
	if [[ $(grep -o "{*}" "$f" | wc -l) > 0 ]]
	then
		echo "[!] Configuration Error"
		echo ""
		continue
	fi

	## Create the subfolders for the project
	mkdir -p $project/logs
	mkdir -p $project/public
	mkdir -p $project/db

	## Create the default index file
	if [ ! -f ./$project/public/index.php ];
	then
		cp ./apache/index.txt ./$project/public/index.php
		sed -i "s/{project}/$project/g" ./$project/public/index.php
	fi

	## Create specific Dockerfile
	cp ./apache/dockerfile.txt ./apache/$project-Dockerfile
	sed -i "s/{project}/$project/g" ./apache/$project-Dockerfile
	sed -i "s/{region}/$region/g" ./apache/$project-Dockerfile
	sed -i "s/{city}/$city/g" ./apache/$project-Dockerfile

	## Build docker containers
	docker compose -f "$f" up -d > /dev/null

	## Leave a line space before the next build
	echo ""

	## Update hosts file if needed
	if [[ $(grep -o "${project}.localhost" /etc/hosts | wc -l) < 1 ]]
	then
		sudo -- sh -c -e "echo '${localhost} ${project}.localhost' >> /etc/hosts";

		if [ -n "$(grep "${project}.localhost" /etc/hosts)" ]
		then
			echo "HOSTS file was succesfully updated with ${project}.localhost";
		else
			echo "Failed to update HOSTS file, please update manually!";
		fi
		echo ""
	fi
done

## Tidy up apache install process
rm ./apache/*-Dockerfile
rm ./*-compose.yml
