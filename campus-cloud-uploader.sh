#!/bin/bash
# VERSION: 1.3.1

# REQUIREMENTS:
# jq (JSON parser)

# CREATED:
# Thomas Roder, 2018.07.05
# https://github.com/MrTomRod/Campus-Cloud-UniBe-Uploader/

# DEBUGGING:
# To analyze the output from CURL requests, best store them as a pretty file like this:
# echo "${OUTPUT}" | python -m json.tool > out.json

# HOW TO LEARN ABOUT THE API:
# https://www.novell.com/documentation/filr-rest-api/filr-2-devel-r-api/data/cli001.html

# HELP MESSAGE:
function help() {
	echo "============================================================================="
	echo "Usage: $(basename "$0") -l l_arg [-e e_arg] [-d d_arg] [--public-link]"
	echo
	echo "Upload a file or a folder to your Campus Cloud (campuscloud.unibe.ch)."
	echo "In order to save space, consider compressing the content:"
	echo "                        zip -r myfolder.zip myfolder"
	echo "                      tar -czf myfolder.tar.gz myfolder"
	echo
	echo "This script also supports sharing the file/folder with others, even outside"
	echo "the university. The recipient will receive an email with a link to the Campus"
	echo "Cloud. Alternatively, a public download link can be generated (files only)."
	echo
	echo "   -l, --location     location of file/folder to be shared."
	echo "   -e, --email        email of recipient(s): If multiple, they must be"
	echo "                           separated by comma; e.g., '-e a@x.com,b@x.com'"
	echo "                           (Optional.)"
	echo "   -p, --public-link  return a public link. Takes no arguments. Only works for"
	echo "                      files. (Optional.)"
	echo "   -d, --days         days until access expires. (Optional. Default = 10 days)"
	echo "                           0 means share doesn't expire."
	echo "   -h, --help         display this help and exit"
	echo
	echo "============================================================================="
}

# KEY FUNCTIONS:

# Create folder on server.
# Usage: create_folder <REST endpoint> <folder name>
# Example: Create folder in the root directory:
#    create_folder "/self/my_files/library_folders" "folder name"
#    -> changes global variable $return to the folder ID, e.g. "1234567"
# Example: Create subfolder:
#    create_folder "/folders/$return/library_folders" "subfolder name"
#    -> changes global variable $return to the folders ID, e.g. "1234567"
function create_folder()
{
	# Get arguments:
	local rest_endpoint=$1
	local folder_name=$2

	# Create folder.
	local OUTPUT="$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest$rest_endpoint -X POST -H "Content-Type: application/json" -d '{"title": "'"$folder_name"'"}')"

	# Get the new folder's id, which is necessary to add files to it.
	local folder_id="$(echo "$OUTPUT" | jq --raw-output '.id')"

	# Confirm folder creation was successful.
	local uploaded_foldername="$(echo "$OUTPUT" | jq --raw-output '.title' )"
	if ! [ "$folder_name" == "$uploaded_foldername" ]; then echo "ERROR: No new folder was created on the server!"; exit 1; fi

	return="$folder_id"
}

# Upload file to server.
# Usage: upload_file <parent folder ID> <file name>
# Example: Create file in folder with ID $return:
#    upload_file "$return" "file"
#    -> changes global variable $file_id to the files ID, e.g. "12345678"
function upload_file()
{
	# Get arguments:
	local rest_endpoint="/folders/$1/library_files"
	local file="$2"

	# Prepare variables.
	local file_name=$(echo $(basename "$file"))
	local html_encoded=${file_name// /\%20}  # replace blanks with %20

	# Upload file.
	local OUTPUT="$(curl -# -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest$rest_endpoint?file_name=$html_encoded -X POST -H "Content-Type: application/octet-stream" --upload-file "$file")"

	# Confirm upload was successful.
	local uploaded_filename="$(echo $OUTPUT | jq --raw-output '.name' )"
	if ! [ "$file_name" == "$uploaded_filename" ]; then echo "ERROR: The upload of $file_name FAILED!"; exit 1; fi

	# Return file ID.
	file_id="$(echo "$OUTPUT" | jq --raw-output '.owning_entity.id')"
}

# This function uploads each file in a folder. If it finds a folder, it recursively calls itself.
# Usage: upload_dir <parent folder ID> <folder>
# Example: Upload folder in parent folder with ID $return:
#    upload_dir "$return" "folder"
function upload_dir()
{
	local parent_ID=$1
	local folder=$2

	local folder_name=$(basename "$folder")
	create_folder "/folders/$parent_ID/library_folders" "$folder_name"
	local current_folder_id=$return

	for item in "$folder"/*; do
		if [[ -h $item ]]; then
			echo "SKIPPING SOFTLINK '$item'"
			let ++lincount
			continue
		fi

		if [[ -d $item ]]; then
			# If the item is a directory, recursively start loop_dir there.
			echo "DIR: $item"
			upload_dir "$current_folder_id" "$item"
			let ++dircount
			continue
		fi

		if [[ -f $item ]]; then
			# If the item is a file...
			echo "FIL: $item"
			upload_file "$current_folder_id" "$item"
			let ++filcount
			continue
		fi

		if [[ "$item" == *\* ]]; then
			# skip this nonsense
			continue
		fi

		echo "ERROR HANDLING THIS ITEM: $item"
		exit 1
	done
}

# START THE PROCESS:

# Set default value for $DAYS. (Determines how long the share will last.)
DAYS=10

# Import arguments.
while [[ $# -gt 0 ]]; do
	key="$1"

	case $key in
		-h|--help)
		help
		exit 0
		;;
		-l|--location)
		LOCATION="$2"
		shift # past argument
		shift # past value
		;;
		-e|--email)
		EMAIL="$2"
		shift # past argument
		shift # past value
		;;
		-p|--public-link)
		LINK=true
		shift # past argument
		# do not shift past value because --public-link doesn't have a value.
		;;
		-d|--days)
		DAYS="$2"
		shift # past argument
		shift # past value
		;;
		*)    # unknown option
		echo "ERROR: UNKNOWN OPTION. The only legal options are -l, -e, -p, -d and -h. For further explanation, type '$(basename "$0") --help'."
		echo
		echo "This has caused the error: $1"
		exit 1
		shift # past argument
		;;
	esac
done

# Check input: Was a correct file location entered? Is $DAYS plausible?
iserror=false
if [ -z "${LOCATION}" ]; then echo "Missing parameter: -l"; iserror=true; fi
if ! [[ -f "${LOCATION}" || -d "${LOCATION}" ]]; then echo "File/folder does not exist."; iserror=true; fi
if ! [[ $DAYS =~ ^[0-9]*$ ]] ; then echo "Parameter -d is flawed. Must be positive integer. If d=0, share will never expire."; iserror=true; fi

# Check input: Are emails plausible?
IFS=',' read -r -a email_array <<< "$EMAIL"
for i in "${email_array[@]}"; do
	if ! [[ $i =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then echo "This is not a valid email address: $i"; iserror=true; fi
done

# Abort script if the input is wrong.
if $iserror ; then exit 1; fi

# Prompt for username and password.
read -p "Enter your campus account's username: " USERNAME
read -sp "Enter your campus account's password: " PASSWORD
echo

# Check whether the username-password combination is valid. (Check if a proper JSON file is returned.)
OUTPUT="$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/)"
echo $OUTPUT | jq -e '.links' >> /dev/null
if ! [ ${PIPESTATUS[1]} = 0 ]; then echo "Error: Username AND/OR password incorrect."; exit 1; fi

# Set the top folder's name, suggest it starts with date and time.
date_string=$(date '+%Y.%m.%d-%H.%M.%S')
read -p "Enter the name of the top folder: " -i "$date_string"_ -e folder_name
echo

# Create a new top folder.
create_folder "/self/my_files/library_folders" "$folder_name"
folder_to_share="$return"

# If the item to upload is a file, simply upload it.
if [[ -f "${LOCATION}" ]]; then
	echo "Uploading file..."
	upload_file "$return" "$LOCATION"

	# Create a publicly accessible link to download the file if option --public-link is active.
	if [ $LINK ]; then
		OUTPUT=$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/folder_entries/$file_id/shares?notify=false -H "Content-Type: application/json" -X POST -d '{"recipient":{"type":"public_link"'$sharestring'}}')
		share_link=$(echo $OUTPUT | jq '.permalinks | .[0] | .href' )
		share_link=${share_link:1:-1}
		# This public link doesn't expire. Unless -d is set to 0, the share must be modified.
		if ! [ $DAYS -eq 0 ]; then
			share_id="$(echo $OUTPUT | jq '.id' )"
			OUTPUT=$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/shares/$share_id -H "Content-Type: application/json" -X POST -d '{"days_to_expire":'$DAYS'}')
		fi
		echo "Public link: $share_link"
	fi

	# If the item to upload is a folder, call the upload_dir function.
elif [[ -d "${LOCATION}" ]]; then
	echo "Uploading folder..."
	if [ $LINK ]; then
		echo "Note: The -p/--public-link parameter has no effect when uploading folders. It only works for links."
	fi
	dircount=0
	filcount=0
	lincount=0
	upload_dir "$return" "$LOCATION"
	echo
	echo "================================================================================"
	echo "================================================================================"
	echo "Successful upload!"
	echo "Total folders: $dircount"
	echo "Total files:   $filcount"
	if [ $lincount -ne 0 ]; then echo "Total links:   $lincount (Links were ignored!)"; fi
else
	echo "Something unexpected has occurred. The thing you want to upload must be a regular file or folder."
fi

# Set up expiration of share.
if [ $DAYS -eq 0 ]; then
	sharestring=""
else
	sharestring=',"days_to_expire":'$DAYS''
fi

# Share the top folder.
for i in "${email_array[@]}"; do
	# Does email $i belong to an existing CampusCloud user? Search for $i in database.
	OUTPUT=$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/principals?keyword=$i)
	user_id="$(echo $OUTPUT | jq '.items | .[0] | .id' )"

	# If UserID is a number...
	if [ "$user_id" -eq "$user_id" ] 2>/dev/null; then
		# ...email belongs to regular user.
		OUTPUT=$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/folders/$folder_to_share/shares?notify=true -H "Content-Type: application/json" -X POST -d '{"recipient":{"type":"user","id":"'"$user_id"'"},"access":{"role":"VIEWER"}'$sharestring'}}')

		# Confirm the folder has been shared.
		recipient_id="$(echo $OUTPUT | jq --raw-output '.recipient.id' )"
		if [ "$user_id" == "$recipient_id" ]; then echo "The file was successfully shared with user $i."; else echo "ERROR: The file was NOT shared with user $i!"; fi

	else
		# ...email does not belong to external user.
		OUTPUT=$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/folders/$folder_to_share/shares?notify=true -H "Content-Type: application/json" -X POST -d '{"recipient":{"type":"external_user","email":"'"$i"'"},"access":{"role":"VIEWER"}'$sharestring'}}')

		# Confirm the file has been shared.
		recipient_email="$(echo $OUTPUT | jq --raw-output '.recipient.email' )"
		if [ "${i,,}" == "$recipient_email" ]; then echo "The file was successfully shared with external $i."; else echo "ERROR: The file was NOT shared with external $i!"; fi
	fi
done
