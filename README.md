# Campus-Cloud-UniBe-Uploader
Upload single files to [campuscloud.unibe.ch](https://campuscloud.unibe.ch/) with this simple bash script!

How to use the script to upload a file:

`./campus-cloud-uploader.sh -l file.zip`

It will prompt for your campus accounts username and password. The new file will be inside a new folder named: upload-date_username_random-letters (for example "2018.07.05-18.29.09_ueli_thaxBXx").

The script also supports sharing the file with others, even users outside the university:

`./campus-cloud-uploader.sh -l file.zip -e u1@example.com,u2@example.com -d 30`

The above code will upload the file and send a notification mail to u1@example.com and u2@example.com. If these mail addresses aren't linked to a campus account, the receivers will first have to create a guest account before being able to access the file. The receivers will be able to see the file for 30 days, as determined by the parameter `-d`. (However, it will **not** automatically be deleted from the uploaders Campus Cloud.)

If `-d` is not specified, the default value is 10 days. `-d 0` will lead to a share that never expires.

# Requirements
On most Linux machines, the only additional software that must be installed is [jq](https://stedolan.github.io/jq/), a JSON parser. The tool is very lightweight and available in most distributions standard repository:


Ubuntu: `sudo apt-get install jq`

Fedora: `sudo dnf install jq`

# Advantages of the script
- Doesn't require a browser to upload. Very convenient and very fast on clusters. :)
- Requires only elementary things like bash, curl and jq.
- Integrated sharing feature.

# Resources for understanding/developing the script
The university's campus cloud is based on [Micro Focus Filr](https://www.microfocus.com/de-de/products/filr/) and the API is documented [here](https://www.novell.com/documentation/filr-rest-api/filr-2-devel-r-api/data/cli001.html).
