#!/bin/bash
# REQUIREMENTS:
# jq (JSON parser)

# CREATED:
# Thomas Roder, 2018.07.05

# DEBUGGING:
# To analyze the output from CURL requests, best store them as a pretty file like this:
# echo "${OUTPUT}" | python -m json.tool > out.json

# HOW TO LEARN ABOUT THE API:
# https://www.novell.com/documentation/filr-rest-api/filr-2-devel-r-api/data/cli001.html

# HELP MESSAGE:
display_help() {
  echo "============================================================================="
  echo "Usage: $(basename "$0") -l l_arg [-e e_arg] [-d d_arg]"
  echo
  echo "Uploads single files to your Campus Cloud (campuscloud.unibe.ch)."
  echo "If you want to upload multiple files, compress them first:"
  echo "                        zip -r myfolder.zip myfolder"
  echo "                      tar -czf myfolder.tar.gz myfolder"
  echo
  echo "This script also supports sharing the file with others, even outside the uni-"
  echo "versity. The recipient will receive an email with a link to the Campus Cloud."
  echo
  echo "   -l, --location     location of file to be shared."
  echo "   -e, --email        email of recipient(s): If multiple, they must be"
  echo "                           separated by comma; e.g., '-e a@x.com,b@x.com'"
  echo "                           (Optional.)"
  echo "   -d, --days         Days until access expires. (Optional. Default = 10 days)"
  echo "                           0 means share doesn't expire."
  echo "   -h, --help         display this help and exit"
  echo
  echo "============================================================================="
}

# Set default value for $DAYS. (Determines how long the share will last.)
DAYS=10

# Import arguments.
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -h|--help)
    display_help
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
    -d|--days)
    DAYS="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    echo "ERROR: UNKNOWN OPTION. The only legal options are -l, -e, -d and -h. For further explanation, type '$(basename "$0") --help'."
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
if ! [ -f $LOCATION ]; then echo "File does not exist."; iserror=true; fi
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

# Create new folder with date, the uploader's username and random string.
date_string=$(date '+%Y.%m.%d-%H.%M.%S')
my_username=$(whoami)
random_salt=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 7 | head -n 1)
folder_name="${date_string}_${my_username}_${random_salt}"

echo "Creating new folder... (${date_string}_${my_username}_${random_salt})"
OUTPUT="$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/self/my_files/library_folders -X POST -H "Content-Type: application/json" -d '{"title": "'$folder_name'"}')"

# Get the new folder's id, which is necessary to upload the file later-on.
folder_id="$(echo $OUTPUT | jq --raw-output '.id')"

# Confirm folder creation was successful.
uploaded_foldername="$(echo $OUTPUT | jq --raw-output '.title' )"
if [ "$folder_name" == "$uploaded_foldername" ]; then echo "The folder ${date_string}_${my_username}_${random_salt} was successfully created."; else echo "ERROR: No new folder was created on the server!"; exit 1; fi

# Cannot upload files with special characters. Thus, remove them from the upload-filename.
harmless_file_name=$(echo $(basename "$LOCATION") | tr -cd '[:alnum:].\-_')

# Start upload.
echo "Uploading $(basename "$LOCATION")..."
OUTPUT="$(curl -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/folders/$folder_id/library_files?file_name=$harmless_file_name -X POST -H "Content-Type: application/octet-stream" --upload-file $LOCATION)"

# Get owning_entity.id, which is necessary to share the file later-on.
file_id="$(echo $OUTPUT | jq --raw-output '.owning_entity.id' )"

# Confirm upload was successful.
uploaded_filename="$(echo $OUTPUT | jq --raw-output '.name' )"
if [ "$harmless_file_name" == "$uploaded_filename" ]; then echo "The file $harmless_file_name was successfully uploaded."; else echo "ERROR: The upload of $(basename "$LOCATION") FAILED!"; exit 1; fi

# Share the file.
# Set up expiration of share.
if [ $DAYS -eq 0 ]; then
  sharestring=""
else
  sharestring=',"days_to_expire":'$DAYS''
fi

for i in "${email_array[@]}"
  do
    echo "Sharing with $i..."
    OUTPUT=$(curl -s -k -u $USERNAME:$PASSWORD https://campuscloud.unibe.ch/rest/folder_entries/$file_id/shares?notify=true -H "Content-Type: application/json" -X POST -d '{"recipient":{"type":"external_user","email":"'"$i"'"},"access":{"role":"VIEWER"}'$sharestring'}}')

    # Confirm the file has been shared.
    recipient_email="$(echo $OUTPUT | jq --raw-output '.recipient.email' )"
    if [ "$i" == "$recipient_email" ]; then echo "The file was successfully shared with $i."; else echo "ERROR: The file was NOT shared with $i!"; fi
  done
