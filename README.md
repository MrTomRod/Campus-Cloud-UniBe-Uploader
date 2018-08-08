# Campus-Cloud-UniBe-Uploader
Upload a file or a folder to [campuscloud.unibe.ch](https://campuscloud.unibe.ch/) with this simple bash script!

How to use the script to upload a file:

`./campus-cloud-uploader.sh -l file.zip`

It will prompt for your campus accounts username and password. Next, it will ask what name the top folder should have, suggesting it begin with the current date (for example "2018.07.05-18.29.09_").

The script also supports sharing the uploaded file(s) with others, even users outside the university:

`./campus-cloud-uploader.sh -l file.zip -e u1@example.com,u2@example.com -d 30`

The above code will upload the file and send a notification mail to u1@example.com and u2@example.com. If these mail addresses aren't linked to a campus account, the receivers will first have to create a guest account before being able to access the file. The receivers will be able to see the file for 30 days, as determined by the parameter `-d`. (However, it will **not** automatically be deleted from the uploaders Campus Cloud.)

`./campus-cloud-uploader.sh -l file.zip --public-link`

This code will upload the file and return a publicly accessible hyperlink to the file that will work for 10 days. The `-p/--public-link` option only works for files, not folders!

If `-d` is not specified, the default value is 10 days. `-d 0` will lead to a share that never expires.

# Requirements
On most Linux machines, the only additional software that must be installed is [jq](https://stedolan.github.io/jq/), a JSON parser. The tool is very lightweight and available in most distributions standard repository:


Ubuntu: `sudo apt-get install jq`

Fedora: `sudo dnf install jq`

# Advantages of the script
- Doesn't require a browser to upload. Very convenient and very fast on clusters. :)
- Requires only elementary things like bash, curl and jq.
- Integrated sharing feature. Different mechanisms for external and internal users are implemented, as well as the creation of public links.
- Recursive upload of folders

# Resources for understanding/developing the script
The university's campus cloud is based on [Micro Focus Filr](https://www.microfocus.com/de-de/products/filr/) and the API is documented [here](https://www.novell.com/documentation/filr-rest-api/filr-2-devel-r-api/data/cli001.html).

# Changelog
    v1.0: Initial release
    v1.1: Files can now be shared with anyone, whether or not the person has a CampusCloud account or belongs to the university
    v1.2: Added option to upload folders
    v1.3: Added option to create public links

# Lincence
    Copyright 2017 IT Services Department, University of Bern, Switzerland

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
