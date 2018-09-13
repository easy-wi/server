#!/bin/bash

# Debug Mode
DEBUG="OFF"

#    Author:     Ulrich Block <ulrich.block@easy-wi.com>,
#                Alexander Doerwald <alexander.doerwald@easy-wi.com>
#
#    This file is part of Easy-WI.
#
#    Easy-WI is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Easy-WI is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Easy-WI.  If not, see <http://www.gnu.org/licenses/>.
#
#    Diese Datei ist Teil von Easy-WI.
#
#    Easy-WI ist Freie Software: Sie koennen es unter den Bedingungen
#    der GNU General Public License, wie von der Free Software Foundation,
#    Version 3 der Lizenz oder (nach Ihrer Wahl) jeder spaeteren
#    veroeffentlichten Version, weiterverbreiten und/oder modifizieren.
#
#    Easy-WI wird in der Hoffnung, dass es nuetzlich sein wird, aber
#    OHNE JEDE GEWAEHELEISTUNG, bereitgestellt; sogar ohne die implizite
#    Gewaehrleistung der MARKTFAEHIGKEIT oder EIGNUNG FUER EINEN BESTIMMTEN ZWECK.
#    Siehe die GNU General Public License fuer weitere Details.
#
#    Sie sollten eine Kopie der GNU General Public License zusammen mit diesem
#    Programm erhalten haben. Wenn nicht, siehe <http://www.gnu.org/licenses/>.

# Backup Path
BACKUP_PATH="your_Backup_path_here"

##################################################
##################################################
##########                              ##########
##########    !!! DO NOT CHANCE !!!     ##########
##########                              ##########
##################################################
##################################################

CURRENT_SCRIPT_VERSION="1.4"
TMP_PATH="/tmp/teamspeak_backup"
BACKUP_FILES=("licensekey.dat" "serverkey.dat" "ts3server.sqlitedb" "query_ip_blacklist.txt" "query_ip_whitelist.txt" "ts3db_mariadb.ini" "ts3db_mysql.ini" "ts3server.ini" "ts3server_startscript.sh" ".bash_history" ".bash_logout" ".bashrc" ".profile")
BACKUP_DIR=("backup" "Backup" "backups" "logs" "files" ".ssh" ".config")
MACHINE=`uname -m`
TS_MASTER_PATH_TMP=`find /home -type f -name 'ts3server'`
TS_USER=`ls -la "$TS_MASTER_PATH_TMP" | awk '{print $3}'`
TS_GROUP=`ls -la "$TS_MASTER_PATH_TMP" | awk '{print $4}'`
TS_MASTER_PATH=`echo "$TS_MASTER_PATH_TMP" | sed 's/\/ts3server//'`

VERSION_CHECK() {
	yellowMessage "Checking for the latest Updater Script"
	LATEST_SCRIPT_VERSION=`wget -q --timeout=60 -O - https://api.github.com/repos/Lacrimosa99/Easy-WI-Teamspeak-Updater/releases/latest | grep -Po '(?<="tag_name": ")([0-9]\.[0-9])'`

	if [ "$LATEST_SCRIPT_VERSION" != "" ]; then
		if [ "`printf "${LATEST_SCRIPT_VERSION}\n${CURRENT_SCRIPT_VERSION}" | sort -V | tail -n 1`" != "$CURRENT_SCRIPT_VERSION" ]; then
			echo
			redMessage "You are using a old TS3 Updater Script Version ${CURRENT_SCRIPT_VERSION}."
			redMessage "Please Upgrade to Version ${LATEST_SCRIPT_VERSION} and retry."
			redMessage "Download Link: https://github.com/Lacrimosa99/Easy-WI-Teamspeak-Updater/releases"
			FINISHED
		else
			greenMessage "You are using a Up-to-Date Script Version ${CURRENT_SCRIPT_VERSION}"
			sleep 2
		fi
	else
		redMessage "Could not detect last Script Version!"
		FINISHED
	fi

	echo
	yellowMessage "Checking for the latest TS3 Server Version"

	if [ "$MACHINE" == "x86_64" ]; then
		ARCH="amd64"
	elif [ "$MACHINE" == "i386" ] || [ "$MACHINE" == "i686" ]; then
		ARCH="x86"
	else
		echo "$MACHINE is not supported!"
	fi

	for LASTEST_TS3_VERSION in `curl -s "http://dl.4players.de/ts/releases/?C=M;O=D" | grep -Po '(?<=href=")[0-9]+(\.[0-9]+){2,3}(?=/")' | sort -Vr`; do
		DOWNLOAD_URL_VERSION="http://dl.4players.de/ts/releases/$LASTEST_TS3_VERSION/teamspeak3-server_linux_$ARCH-$LASTEST_TS3_VERSION.tar.bz2"
		STATUS=`curl -I $DOWNLOAD_URL_VERSION 2>&1 | grep "HTTP/" | awk '{print $2}'`

		if [ "$STATUS" == "200" ]; then
			DOWNLOAD_URL=$DOWNLOAD_URL_VERSION
			break
		fi
	done

	LOCAL_TS3_VERSION=$(if [ -f "$TS_MASTER_PATH"/version ]; then cat "$TS_MASTER_PATH"/version; fi)
	if [ "$LASTEST_TS3_VERSION" != "" ]; then
		if [ "$LOCAL_TS3_VERSION" != "$LASTEST_TS3_VERSION" ]; then
			redMessage "Your TS3 Server Version is deprecated."
			redMessage "Start Update Process"
			sleep 2
			USER_CHECK
		else
			greenMessage "Your TS3 Server Version is Up-to-Date"
			FINISHED
		fi
	else
		redMessage "Could not detect latest TS3 Server Version!"
		FINISHED
	fi
}

USER_CHECK() {
	echo
	if [ "$TS_USER" != "" ]; then
		USER_CHECK=$(cut -d: -f6,7 /etc/passwd | grep "$TS_USER" | head -n1)
		if ([ "$USER_CHECK" != "/home/$TS_USER:/bin/bash" -a "$USER_CHECK" != "/home/$TS_USER/:/bin/bash" ]); then
			redMessage "User $TS_USER not found or wrong shell rights!"
			redMessage "Please check the TS_USER inside this Script or the user shell rights."
			FINISHED
		else
			SERVER_STOP
		fi
	else
		redMessage 'Variable "TS_USER" are empty!'
		FINISHED
	fi
}

SERVER_START_MINIMAL() {
	yellowMessage "starting TS3 Server with ts3server_minimal_runscript.sh to Update Database..."
	yellowMessage "Please do not cancel!"
	echo

	CHECK_MARIADB=$(if [ -f "$TS_MASTER_PATH"/ts3db_mariadb.ini ]; then cat "$TS_MASTER_PATH"/ts3db_mariadb.ini | grep "username="; fi)
	CHECK_MSQL=$(if [ -f "$TS_MASTER_PATH"/ts3db_mysql.ini ]; then cat "$TS_MASTER_PATH"/ts3db_mysql.ini | grep "username="; fi)

	if [ "$CHECK_MARIADB" != "" -o "$CHECK_MSQL" != "" ]; then
		su - -c "ln -s "$TS_MASTER_PATH"/redist/libmariadb.so.2 "$TS_MASTER_PATH"/libmariadb.so.2" "$TS_USER"
		su - -c "$TS_MASTER_PATH/ts3server_minimal_runscript.sh inifile=ts3server.ini 2>&1 | tee $TS_MASTER_PATH/logs/ts3server_minimal_start_$(date +%d-%m-%Y).log" "$TS_USER" &
	else
		su - -c "$TS_MASTER_PATH/ts3server_minimal_runscript.sh | tee $TS_MASTER_PATH/logs/ts3server_minimal_start_$(date +%d-%m-%Y).log" "$TS_USER" &
	fi

	sleep 80
	ps -u "$TS_USER" | grep ts3server | awk '{print $1}' | while read PID; do
		kill "$PID"
	done
	sleep 5
	greenMessage "Done"
	sleep 5
	echo
	SERVER_START
}

SERVER_START() {
	yellowMessage "Start TS3 Server"

	su - -c "$TS_MASTER_PATH/ts3server_startscript.sh start" "$TS_USER" 2>&1 >/dev/null
	sleep 2
	greenMessage "Done"
}

SERVER_STOP() {
	yellowMessage "Stop Server for Update..."

	su - -c "$TS_MASTER_PATH/ts3server_startscript.sh stop" "$TS_USER" 2>&1 >/dev/null
	sleep 10
	ps -u "$TS_USER" | grep ts3server | awk '{print $1}' | while read PID; do
		kill $PID
	done
	sleep 5
	greenMessage "Done"
	sleep 3
	echo
	BACKUP
}

BACKUP() {
	yellowMessage "Make Backup..."

	if [ ! -d "$TMP_PATH" ]; then
		mkdir "$TMP_PATH"
	else
		rm -rf "$TMP_PATH"
		mkdir "$TMP_PATH"
	fi

	for tmp_dir in ${BACKUP_DIR[@]}; do
		if [ -d "$TS_MASTER_PATH"/"$tmp_dir" ]; then
			cp "$TS_MASTER_PATH"/"$tmp_dir" -R "$TMP_PATH" 2>&1 >/dev/null
		fi
	done

	for tmp_file in ${BACKUP_FILES[@]}; do
		if [ -f "$TS_MASTER_PATH"/"$tmp_file" ]; then
			cp "$TS_MASTER_PATH"/"$tmp_file" -R "$TMP_PATH"/ 2>&1 >/dev/null
		fi
	done

	cd /tmp
	DIR_SIZE=$(du --max-depth=0 ./teamspeak_backup | awk '{ print $1 }')

	if [ "$DIR_SIZE" -ge "999000000" ]; then
		tar cpvz ./teamspeak_backup | split -b1024m - Teamspeak_Backup.$(date -I).tar.gz.split.

		if [ "$BACKUP_PATH" != "" -a -d "$BACKUP_PATH" ]; then
			mv Teamspeak_Backup.*.tar.gz.split.* "$BACKUP_PATH"
		else
			mv Teamspeak_Backup.*.tar.gz.split.* /home
		fi
	else
		tar cfvz Teamspeak_Backup.$(date -I).tar.gz ./teamspeak_backup

		if [ "$BACKUP_PATH" != "" -a -d "$BACKUP_PATH" ]; then
			mv Teamspeak_Backup.$(date -I).tar.gz "$BACKUP_PATH"
		else
			mv Teamspeak_Backup.$(date -I).tar.gz /home
		fi
	fi

	sleep 2
	greenMessage "Done"
	sleep 3
	echo
	DOWNLOAD
}

DOWNLOAD() {
	yellowMessage "Downloading TS3 Server Files..."
	echo
	wget --timeout=60 -P /tmp/ "$DOWNLOAD_URL"

	if [ -f /tmp/teamspeak3-server_linux_"$ARCH"-"$LASTEST_TS3_VERSION".tar.bz2 ]; then
		cd /tmp
		tar xfj /tmp/teamspeak3-server_linux_"$ARCH"-"$LASTEST_TS3_VERSION".tar.bz2

		rm -rf "$TS_MASTER_PATH"/*

		mv /tmp/teamspeak3-server_linux_"$ARCH"/* "$TS_MASTER_PATH"
		echo "$LASTEST_TS3_VERSION" >> "$TS_MASTER_PATH"/version
		echo
		sleep 3
		RESTORE
	else
		redMessage "Download the last TS3 Files failed!"
		FINISHED
	fi
}

RESTORE() {
	yellowMessage "Restore TS3 Server Files..."

	for tmp_dir in ${BACKUP_DIR[@]}; do
		if [ -d "$TMP_PATH"/"$tmp_dir" ]; then
			cp "$TMP_PATH"/"$tmp_dir" -R "$TS_MASTER_PATH"/
		fi
	done

	if [ ! -d "$TS_MASTER_PATH"/logs ]; then
		mkdir "$TS_MASTER_PATH"/logs
	fi

	for tmp_file in ${BACKUP_FILES[@]}; do
		if [ -f "$TMP_PATH"/"$tmp_file" ]; then
			rm -rf "$TS_MASTER_PATH"/"$tmp_file"
			mv "$TMP_PATH"/"$tmp_file" "$TS_MASTER_PATH"/
		fi
	done

	chown -cR "$TS_USER":"$TS_GROUP" "$TS_MASTER_PATH" 2>&1 >/dev/null

	rm -rf /tmp/teamspeak3-server_linux_"$ARCH"-"$LASTEST_TS3_VERSION".tar.bz2
	rm -rf /tmp/teamspeak3-server_linux_"$ARCH"
	rm -rf "$TMP_PATH"

	sleep 3
	greenMessage "Done"
	sleep 3
	echo
	SERVER_START_MINIMAL
}

FINISHED() {
	sleep 2
	echo
	echo
	yellowMessage "Thanks for using this script and have a nice Day."
	echo
	if [ "$DEBUG" = "ON" ]; then
		set +x
	fi
	exit 0
}

yellowMessage() {
	echo -e "\\033[33;1m${@}\033[0m"
}

redMessage() {
	echo -e "\\033[31;1m${@}\033[0m"
}

greenMessage() {
	echo -e "\\033[32;1m${@}\033[0m"
}

cyanMessage() {
	echo -e "\\033[36;1m${@}\033[0m"
}

RUN() {
	if [ "$DEBUG" = "ON" ]; then
		set -x
	fi
	clear
	echo
	VERSION_CHECK
	FINISHED
}

RUN
