#!/bin/sh
# @author	Ricardo Vargas
# @desc		MySQL Cron Backup
# @version	1.0

### Setup ####
# DB Config
DB_SERVER='localhost' 			# Database Server IP o FDQN Name if you are in the same Network.
DB_USER='[DB_USER]'				# Database User.
DB_PASS='[DB_PASSWORD]'			# Database Password.
DB_DATABASE='[DB_DATABASE]'		# Name of the Database to Backup.

# 
KEEPDAYS=15 					# Total time to keep files on server.

# Directories
DIR_TMP=/tmp/backups/db/$DATE 	# Local Backup route to keed your local DB files.


# Remote Location
RC_USER='smroot'				# Local user with the rclone config profile to use.
RC_CONFIG='Yandex-ShopMundo'	# rclone config profile.
RC_PATH='/backup/db'			# Remote path to save the backup file.

### End Setup ###

#### Don't Touch from Here ####

### System Messages ###
MSN_DONE='[\e[92m  Done \e[0m  ]'
MSN_WARNING='[\e[93m Warn!\e[0m  ]'
MSN_ERROR='[\e[91m Error\e[0m  ]'
MSN_INFO='[\e[96m Info!\e[0m  ]'

# Flags Defaults
SILENT=false

# TEMP vars
DATE=`date +%Y%m%d`      #Current Time
NOW=`date +%s`	#UNIX Timestamp
SESS_DUMP_VAR=$DATE'-'$NOW
#

### Functions ###
# Install rclone
INSTALL_RCLONE (){
	curl https://rclone.org/install.sh | sudo bash
}

# Loading Animation
LOADING (){
	PID=$!; i=1; sp="/-\|"; echo -n ' '
	while [ -d /proc/$PID ]; do
        	printf "\b${sp:i++%${#sp}:1}"
	done;
	echo -ne "\033[2K\b"
}

# Exiting preventing farewell
EXIT (){
        printf -- '\n';
        exit 0;
}

### End Functions ###

### Flags ###
# --help -h flag
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
	printf -- "Help text will be publish soon.";
	EXIT
fi;

# --silent -s

# --interval -i
### daily, weekly, monthly

### End Flags ###

### Sanity Check ###
echo -e "\e[1m-- Sanity Check --\e[0m"
# Are you root?

# Command Check List:
# - rclone
_=$(command -v rclone);
if [ "$?" != "0" ]; then
	echo -e $MSN_ERROR "You don't seen to have rclone installed.";
	echo -e $MSN_INFO "Do you want to install rclone?"; 
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) INSTALL_RCLONE; break ;;
			No ) echo -e $MSN_DONE "Sorry, this backup system only work with rclone."; break;;
		esac
	done
else
	echo -e $MSN_DONE "Perfect! \e[44mrclone\e[0m it's already installed.";
fi;
### End Sanity Check

### Cleanup ###
### End Cleanup ###


### Logic
# TMP folder
echo -e "\n\e[1m-- Directory Verification --\e[0m"
echo -e $MSN_INFO "Verifying TMP directory ..."
echo -e $MSN_INFO "\e[1mDirectory PATH:\e[0m "$DIR_TMP
if [ ! -d "$DIR_TMP" ]; then
	echo -e $MSN_WARNING "TMP Directory don't exits. The system it's going to create it."
	mkdir -p $DIR_TMP
	echo -e $MSN_DONE "Directory successful created!"
else
	echo -e $MSN_INFO "Directory already exist."
fi

# Generating DB Dump
echo -e "\n\e[1m-- Backup Execution --\e[0m"
echo -e $MSN_INFO "\e[1mStarting Database Backup."
echo -e $MSN_INFO "Creating Database structure backup."
echo -e $MSN_INFO "\e[1mFile Name:\e[0m "$DB_DATABASE'-bk-nd-'$SESS_DUMP_VAR'.sql.gz'
echo -e $MSN_INFO "Starting \e[44mMySQLDump\e[0m: Creating backup file with Database Schema without table content."
#mysqldump --no-data -u $DB_USER -p$DB_PASS $DB_DATABASE > $DIR_TMP/$DB_DATABASE'-bk-nd-'$SESS_DUMP_VAR'.sql' 2>/dev/null &
mysqldump --no-data -u $DB_USER -p$DB_PASS $DB_DATABASE 2>/dev/null | gzip > $DIR_TMP/$DB_DATABASE'-bk-nd-'$SESS_DUMP_VAR'.sql.gz' 2>/dev/null &
LOADING
echo -e $MSN_DONE "\e[4mDatabase Structure\e[0m file saved."

echo -e $MSN_INFO "Creating Database information backup."
echo -e $MSN_INFO "\e[1mFile Name:\e[0m "$DB_DATABASE'-bk-jd-'$SESS_DUMP_VAR'.sql.gz'
echo -e $MSN_INFO "Starting \e[44mMySQLDump\e[0m: Creating backup file with ONLY tables content without Database Schema."
echo -e $MSN_INFO "This process can take longer depending on your database size."
#mysqldump --no-create-info -u $DB_USER -p$DB_PASS $DB_DATABASE > $DIR_TMP/$DB_DATABASE'-bk-jd-'$DATE'-'$NOW'.sql' 2>/dev/null &
mysqldump --no-create-info -u $DB_USER -p$DB_PASS $DB_DATABASE 2>/dev/null | gzip > $DIR_TMP/$DB_DATABASE'-bk-jd-'$SESS_DUMP_VAR'.sql.gz' 2>/dev/null &
LOADING
echo -e $MSN_DONE "\e[4mDatabase Information\e[0m file generated."

# Compressing Files
echo -e "\n\e[1m-- Packaging Files --\e[0m"
echo -e $MSN_INFO "\e[1mPackaging files togeter before transfer to external location.\e[0m"
tar czcf $DIR_TMP/$DB_DATABASE'-'$NOW'.tar.gz' --absolute-names $DIR_TMP/*$SESS_DUMP_VAR'.sql.gz' 2>/dev/null &
LOADING
echo -e $MSN_DONE "Package file generated!"

# Saving Backup in a Remote Route
echo -e "\n\e[1m-- Remote Backup --\e[0m"
echo -e $MSN_INFO "\e[1mSaving package file in a remote location.\e[0m"
echo -e $MSN_INFO "\e[1mRClone Config:\e[0m "$RC_CONFIG
echo -e $MSN_INFO "\e[1mRemote Path:\e[0m "$RC_PATH
sudo -u $RC_USER rclone copy $DIR_TMP/$DB_DATABASE'-'$NOW'.tar.gz' $RC_CONFIG:$RC_PATH &
#2>/dev/null &
LOADING
echo -e $MSN_DONE "File backed remotely!"

# Final Check
echo -e "\n\e[1m-- Final Check --\e[0m"
echo -e $MSN_INFO "\e[1mValidating integrity of the files comparing \e[1mCHECKSUM.\e[0m"
sudo -u $RC_USER rclone check $DIR_TMP/$DB_DATABASE'-'$NOW'.tar.gz' $RC_CONFIG:$RC_PATH --one-way &
LOADING
echo -e $MSN_DONE "Files validation Match!"

echo -e "\n\e[1m-- Backup Complete --\e[0m"
sleep 1
echo -e "Exiting..."

#echo -e $MSN_DONE
#echo -e $MSN_WARNING
#echo -e $MSN_ERROR
#echo -e $MSN_INFO
EXIT
### End Logic ###

# ToDo:
# - POSIX validation.
# - Not Compressed option of the DB.
# - Daily, Weekly, Montly flag to setting a Cron Job.
# - rclone Library validation and installation if is required.
