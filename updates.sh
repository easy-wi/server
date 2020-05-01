#!/bin/bash

#   Author:     Ulrich Block <ulrich.block@easy-wi.com>
#               Alexander Dörwald <alexander.doerwald@easy-wi.com>
#
#   This file is part of Easy-WI.
#
#   Easy-WI is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   Easy-WI is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Easy-WI.  If not, see <http://www.gnu.org/licenses/>.
#
#   Diese Datei ist Teil von Easy-WI.
#
#   Easy-WI ist Freie Software: Sie koennen es unter den Bedingungen
#   der GNU General Public License, wie von der Free Software Foundation,
#   Version 3 der Lizenz oder (nach Ihrer Wahl) jeder spaeteren
#   veroeffentlichten Version, weiterverbreiten und/oder modifizieren.
#
#   Easy-WI wird in der Hoffnung, dass es nuetzlich sein wird, aber
#   OHNE JEDE GEWAEHELEISTUNG, bereitgestellt; sogar ohne die implizite
#   Gewaehrleistung der MARKTFAEHIGKEIT oder EIGNUNG FUER EINEN BESTIMMTEN ZWECK.
#   Siehe die GNU General Public License fuer weitere Details.
#
#   Sie sollten eine Kopie der GNU General Public License zusammen mit diesem
#   Programm erhalten haben. Wenn nicht, siehe <http://www.gnu.org/licenses/>.
#
############################################
#   Moegliche Cronjob Konfiguration
#		15 */3 * * * cd ~/ && ./updates.sh mta
#		15 */3 * * * cd ~/ && ./updates.sh samp
#		15 */3 * * * cd ~/ && ./updates.sh mms
#		15 */3 * * * cd ~/ && ./updates.sh sm
#		15 */3 * * * cd ~/ && ./updates.sh mms_dev
#		15 */3 * * * cd ~/ && ./updates.sh sm_dev
#		30 */1 * * * cd ~/ && ./updates.sh mc
#		30 */1 * * * cd ~/ && ./updates.sh spigot
#		30 */1 * * * cd ~/ && ./updates.sh forge
#		30 */1 * * * cd ~/ && ./updates.sh hexxit
#		30 */1 * * * cd ~/ && ./updates.sh tekkit
#		30 */1 * * * cd ~/ && ./updates.sh tekkit-classic


function greenMessage {
	echo -e "\\033[32;1m${@}\033[0m"
}

function cyanMessage {
	echo -e "\\033[36;1m${@}\033[0m"
}

function redMessage {
	echo -e "\\033[31;1m${@}\033[0m"
}

function InstallasRoot {
	cyanMessage " "
	cyanMessage "$PROGRAM is not installed.. we will installing automatically!"

	if [ "$OScheck" == "debian" -o "$OScheck" == "ubuntu" ]; then
		INSTALLER="apt-get"
	elif [ "$OScheck" == "centos" ]; then
		INSTALLER="yum"
	else
		redMessage "Unsupported system detected!"
		redMessage "We supporting only Debian, Ubuntu and CentOS."
		redMessage " "
		exit 0
	fi

	greenMessage "Please enter your Root Password:"
	su root -c "$INSTALLER install $PROGRAM -y"
	greenMessage " "
}

OScheck=`cat /etc/os-release | egrep -o "centos|debian|ubuntu" | head -n1`

if [ "$(which lynx 2>/dev/null)" == "" ]; then
	PROGRAM="lynx"
	InstallasRoot
fi

function checkJava {
	if [ "$(which java 2>/dev/null)" == "" ]; then
		if [ "$OScheck" == "debian" -o "$OScheck" == "ubuntu" ]; then
			PROGRAM="openjdk-8-jdk"
		elif [ "$OScheck" == "centos" ]; then
			PROGRAM="java-1.8.0-openjdk"
		fi
		InstallasRoot
	fi
}

function checkCreateVersionFile {
	if [ ! -f "$HOME/versions/$1" ]; then
		touch "$HOME/versions/$1"
	fi
}

function checkCreateFolder {
	if [ ! -d "$1" -a "$1" != "" ]; then
		mkdir -p "$1"
	fi
}

function removeFile {
	if [ -f "$1" ]; then
		rm -f "$1"
	fi
}

function downloadExtractFile {

	checkCreateFolder "$HOME/$4/$1/"

	cd "$HOME/$4/$1/"

	removeFile "$2"

	wget "$3"

	if [ -f "$2" ]; then

		if [[ `echo $2 | egrep -o 'samp[[:digit:]]{1,}svr.+'` ]]; then
			tar xfv "$2" --strip-components=1
		else
			tar xfv "$2"
		fi

		rm -f "$2"

		moveFilesFolders "$2" "$4" "$1"

		find -type f ! -perm -750 -exec chmod 640 {} \;
		find -type d -exec chmod 750 {} \;
	fi
}

function moveFilesFolders {

	FOLDER=`echo $1 | sed -r 's/.tar.gz//g'`

	if [ "$FOLDER" != "" -a "" != "$2" -a "$3" != "" -a -d "$HOME/$2/$3/$FOLDER" ]; then

		cd "$HOME/$2/$3/"

		find "$FOLDER/" -mindepth 1 -type d | while read DIR; do

			NEW_FODLER=${DIR/$FOLDER\//}

			if [ ! -d "$HOME/$2/$3/$NEW_FODLER" ]; then
				mkdir -p "$HOME/$2/$3/$NEW_FODLER"
			fi
		done

		find "$FOLDER/" -type f | while read FILE; do

			MOVE_TO=${FILE/$FOLDER\//.\/}

			if [ "$MOVE_TO" != "" ]; then
				mv "$FILE" "$MOVE_TO"
			fi
		done

		rm -rf "$FOLDER"
	fi
}

function update {

	checkCreateVersionFile "$1"

	FILE_NAME=`echo $2 | egrep -o '((sourcemod|mmsource|multitheftauto_linux|baseconfig)-[[:digit:]]|samp[[:digit:]]{1,}svr.+).*$' | tail -1`
	LOCAL_VERSION=`cat $HOME/versions/$1 | tail -1`
	CURRENT_VERSION=`echo $2 | egrep -o '((mmsource|sourcemod|multitheftauto_linux|baseconfig)-[0-9a-z.-]{1,}[0-9]|samp[[:digit:]]{1,}svr.+)' | tail -1`

	if ([ "$CURRENT_VERSION" != "$LOCAL_VERSION" -o "$LOCAL_VERSION" == "" ] && [ "$CURRENT_VERSION" != "" ]); then

		greenMessage "Updating $1 from $LOCAL_VERSION to $CURRENT_VERSION. Name of file is $FILE_NAME"

		downloadExtractFile "$3" "$FILE_NAME" "$2" "$4"
		echo "$CURRENT_VERSION" > "$HOME/versions/$1"

	elif [ "$CURRENT_VERSION" == "" ]; then
		cyanMessage "Could not detect current version for ${1}. Local version is $LOCAL_VERSION."
	else
		cyanMessage "${1} already up to date. Local version is $LOCAL_VERSION. Most recent version is $CURRENT_VERSION"
	fi
}

function updatesAddonSnapshots {

	if [ "$3" == "" ]; then
		cyanMessage "Searching updates for $1 and revision $2"
	else
		cyanMessage "Searching snapshot updates for $1 ($3) and revision $2"
	fi

	if [ "$1" == "sourcemod" ]; then
		DOWNLOAD_URL=`lynx -dump "http://www.sourcemod.net/smdrop/$2/sourcemod-latest-linux" | tr -d " \t\n\r"`
		DOWNLOAD_URL="http://www.sourcemod.net/smdrop/$2/$DOWNLOAD_URL"	
	else
		DOWNLOAD_URL=`lynx -dump "http://www.metamodsource.net/mmsdrop/$2/mmsource-latest-linux" | tr -d " \t\n\r"`
		DOWNLOAD_URL="http://www.metamodsource.net/mmsdrop/$2/$DOWNLOAD_URL
	fi

	if [ "$3" == "" ]; then
		update "${1}.txt" "$DOWNLOAD_URL" "${1}" "masteraddons"
	else
		update "${1}_snapshot_${3}.txt" "$DOWNLOAD_URL" "${1}-${3}" "masteraddons"
	fi
}

function fileUpdate {

	checkCreateVersionFile "$1"

	checkCreateFolder "$HOME/$4/$3"

	cd "$HOME/$4/$3"

	wget "$2"

	NO_HTTP=${2:6}
	FILE_NAME=${NO_HTTP##/*/}

	if [ "$FILE_NAME" != "" -a -f "$FILE_NAME" ]; then

		LOCAL_VERSION=`cat $HOME/versions/$1 | tail -1`
		CURRENT_VERSION=`stat -c "%Y" $FILE_NAME`

		if ([ "$CURRENT_VERSION" != "$LOCAL_VERSION" -o "$LOCAL_VERSION" == "" ] && [ "$CURRENT_VERSION" != "" ]); then

			greenMessage "Updating $3 from $LOCAL_VERSION to $CURRENT_VERSION. Name of file is $FILE_NAME"

			FILENAME_CHECK=`echo "$FILE_NAME" | egrep -o "zip"`
			if [ "$FILENAME_CHECK" == "zip" ]; then
				unzip "$FILE_NAME"
			elif [ "$FILENAME_CHECK" == "tar" ]; then
				tar xfv "$FILE_NAME"
			fi
			echo "$CURRENT_VERSION" > "$HOME/versions/$1"

		else
			cyanMessage "$3 already up to date. Local version is $LOCAL_VERSION. Most recent version is $CURRENT_VERSION"
		fi

		rm -f "$FILE_NAME"
	fi
}

function mtaFiles {
	fileUpdate server_mta_configs.txt "https://linux.mtasa.com/dl/baseconfig.tar.gz" "mtasa" "masterserver"
	fileUpdate server_mta_resources.txt "http://mirror.mtasa.com/mtasa/resources/mtasa-resources-latest.zip" "mtasa" "masterserver"
}

function updateMTA {

	cyanMessage "Searching update for MTA San Andreas"

	checkCreateVersionFile "server_mta.txt"

	FILE_NAME="multitheftauto_linux_x64.tar.gz"
	LOCAL_VERSION=`cat $HOME/versions/server_mta.txt | tail -1`
	CURRENT_VERSION=`lynx -dump http://linux.mtasa.com/ | egrep -o "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tail -1`

	if ([ "$CURRENT_VERSION" != "$LOCAL_VERSION" -o "$LOCAL_VERSION" == "" ] && [ "$CURRENT_VERSION" != "" ]); then

		greenMessage "Updating server_mta.txt from $LOCAL_VERSION to $CURRENT_VERSION. Name of file is $FILE_NAME"

		downloadExtractFile "mtasa" "$FILE_NAME" "https://linux.mtasa.com/dl/multitheftauto_linux_x64.tar.gz" "masterserver"
		echo "$CURRENT_VERSION" > "$HOME/versions/server_mta.txt"

		mtaFiles

	elif [ "$CURRENT_VERSION" == "" ]; then
		cyanMessage "Could not detect current version for mta. Local version is $LOCAL_VERSION."
	else
		cyanMessage "mta already up to date. Local version is $LOCAL_VERSION. Most recent version is $CURRENT_VERSION"
	fi

	if [ "`date +'%H'`" == "00" ]; then
		mtaFiles
	fi
}

function MCfileUpdate {

	checkCreateVersionFile "$1"

	checkCreateFolder "$HOME/$4/$3"

	LOCAL_VERSION=`cat $HOME/versions/$1 | tail -1`

	if [ "$DOWNLOAD_URL" != "" -a "$VERSION_URL" == "" ]; then
		CURRENT_VERSION=`echo $DOWNLOAD_URL | egrep -o [[:digit:]].* | head -n1 | sed 's/.zip\|.tar\|.jar//' | sed 's/\/.*//'`
	fi

	if ([ "$VERSION_URL" != "" ] && [ "$CURRENT_VERSION" == "1" -o "$CURRENT_VERSION" == "" ]); then
		CURRENT_VERSION=`echo $VERSION_URL`
	fi

	if ([ "$CURRENT_VERSION" != "$LOCAL_VERSION" -o "$LOCAL_VERSION" == "" ] && [ "$CURRENT_VERSION" != "" ]); then
		cd "$HOME/$4/$3"

		FILE_NAME=`ls`
		if [ "$FILE_NAME" != "" ]; then
			rm -rf ./*
		fi

		if [ "$2" != "" ]; then
			wget "$2"
		else
			wget "$DOWNLOAD_URL"
		fi

		FILE_NAME=`ls`
		FILE_EXTENSION=`echo $FILE_NAME | egrep -o "zip|tar|jar"`

		if [ "$FILE_EXTENSION" == "zip" ]; then
			unzip "$FILE_NAME"
			rm -rf "$FILE_NAME"
			FILE_NAME=`ls | egrep -o ".*.jar" | egrep -v "minecraft_server.*."`
		elif [ "$FILE_EXTENSION" == "tar" ]; then
			tar xfv "$FILE_NAME"
			rm -rf "$FILE_NAME"
			FILE_NAME=`ls | egrep -o ".*.jar" | egrep -v "minecraft_server.*."`
		elif [ "$FILE_EXTENSION" == "jar" -a "$FILE_NAME" == "server.jar" ]; then
			mv server.jar minecraft_server.jar
			FILE_NAME=`ls | egrep -o ".*.jar"`
		elif [ "$FILE_EXTENSION" == "jar" -a "$(echo $FILE_NAME | egrep -o 'installer')" == "installer" ]; then
			checkJava
			java -jar $FILE_NAME --installServer
			rm -rf $FILE_NAME $FILE_NAME.log
			FILE_NAME=`ls | egrep "universal.jar"`
			mv $FILE_NAME forge.jar
			FILE_NAME="forge.jar"
		fi

		DELETE=`ls | egrep -o ".*.bat|.*.sh"`

		if [ "$DELETE" != "" ]; then
			for delete in ${DELETE[@]}; do
				rm -rf $delete
			done
		fi

		echo "$CURRENT_VERSION" > "$HOME/versions/$1"

		if [ "$LOCAL_VERSION" == "" ]; then
			LOCAL_VERSION="none"
		fi

		MCEULA eula.txt "$HOME/$4/$3"

		greenMessage "Updating $3 from $LOCAL_VERSION to $CURRENT_VERSION. Name of file is $FILE_NAME"

	elif [ "$CURRENT_VERSION" == "" ]; then
		redMessage "Recent version not detected!"
	else
		cyanMessage "$3 already up to date. Local version is $LOCAL_VERSION. Most recent version is $CURRENT_VERSION"
	fi
}

function MCEULA {
	if [ ! -f $2/$1 ]; then
			echo "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
#Tue Jun 23 09:05:11 CEST 2015
eula=true" > $2/$1
	fi
}

function updateSAMP {

	cyanMessage "Searching update for San Andreas Multi Player"

	DOWNLOAD_URL=`lynx -dump "http://files.sa-mp.com/" | egrep -o "http:.*samp.*tar\.gz" | tail -n 1`
	update server_samp.txt "$DOWNLOAD_URL" "samp" "masterserver"
}

function updateMC {

	cyanMessage "Searching update for Minecraft"

	DOWNLOAD_URL=`lynx -dump "https://minecraft.net/de-de/download/server" | egrep -o "https://launcher.*"`
	VERSION_URL=`lynx --dump "https://minecraft.net/de-de/download/server" | egrep -o "minecraft_server.[[:digit:]].[[:digit:]][[:digit:]].[[:digit:]]" | head -n1 | cut -c 18-`
	MCfileUpdate server_mc.txt "$DOWNLOAD_URL" "mc" "masterserver"
}

function updateMCTEKKIT {

	cyanMessage "Searching update for Minecraft Tekkit"

	DOWNLOAD_URL=`lynx -dump "https://www.technicpack.net/tekkit/" | egrep -o "http://servers.technicpack.net/.*Tekkit_Server_.*"`
	MCfileUpdate server_tekkit.txt "$DOWNLOAD_URL" "tekkit" "masterserver"
}

function updateMCTEKKITCLASSIC {

	cyanMessage "Searching update for Minecraft Tekkit-Classic"

	DOWNLOAD_URL=`lynx -dump "https://www.technicpack.net/modpack/tekkit" | egrep -o "http://servers.technicpack.net/.*Tekkit_Server_.*"`
	MCfileUpdate server_tekkit_classic.txt "$DOWNLOAD_URL" "tekkit-classic" "masterserver"
}

function updateMCFORGE {

	cyanMessage "Searching update for Minecraft Forge"

	DOWNLOAD_URL=`lynx -dump "https://files.minecraftforge.net" | egrep -o "https://files..*installer.jar" | sed -n '2p'`
	MCfileUpdate server_forge.txt "$DOWNLOAD_URL" "forge" "masterserver"
}

function updateMCHEXXIT {

	cyanMessage "Searching update for Minecraft Hexxit"

	DOWNLOAD_URL=`lynx -dump "https://www.technicpack.net/hexxit/" | egrep -o "http://servers.technicpack.net/.*Hexxit_Server_.*"`
	MCfileUpdate server_hexxit.txt "$DOWNLOAD_URL" "hexxit" "masterserver"
}

function updateBUKKIT_SPIGOT {

	cyanMessage "Searching update for Minecraft Spigot and CraftBukkit"

	if [ -f $HOME/versions/server_spigot.txt ]; then
		LOCAL_SPIGOT_VERSION=`cat $HOME/versions/server_spigot.txt | tail -1`
	fi
	if [ -f $HOME/versions/server_bukkit.txt ]; then
		LOCAL_CRAFTBUKKIT_VERSION=`cat $HOME/versions/server_bukkit.txt | tail -1`
	fi
	CURRENT_VERSION=`lynx --dump https://www.spigotmc.org/wiki/buildtools/ | grep "Currently" | egrep -o "[[:digit:]].[[:digit:]][[:digit:]].[[:digit:]]"`

	if ([ "$CURRENT_VERSION" != "$LOCAL_SPIGOT_VERSION" -o "$LOCAL_SPIGOT_VERSION" == "" -o "$CURRENT_VERSION" != "$LOCAL_CRAFTBUKKIT_VERSION" -o "$LOCAL_CRAFTBUKKIT_VERSION" == ""  ] && [ "$CURRENT_VERSION" != "" ]); then

		checkJava

		if [ "$(which git 2>/dev/null)" == "" ]; then
			PROGRAM="git"
			InstallasRoot
		fi

		checkCreateFolder "$HOME/MCcompiler"
		cd $HOME/MCcompiler

		cyanMessage "Downloading latest BuildTools"
		if [ -f BuildTools.jar ]; then
			rm -rf ./BuildTools.jar
		fi
		wget -O BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

		cyanMessage "Compile latest Minecraft Spigot and CraftBukkit Build"
		git config --global --unset core.autocrlf
		java -Xmx1024M -jar BuildTools.jar --rev latest

		VERSION_CRAFTBUKKIT=`ls | egrep "craftbukkit" | egrep -o "[[:digit:]].[[:digit:]][[:digit:]].[[:digit:]]"`
		VERSION_SPIGOT=`ls | egrep "spigot" | egrep -o "[[:digit:]].[[:digit:]][[:digit:]].[[:digit:]]"`

		if [ ! -d $HOME/masterserver/bukkit ]; then
			mkdir $HOME/masterserver/bukkit
		elif [ -f $HOME/masterserver/bukkit/craftbukkit.jar ]; then
			rm -rf $HOME/masterserver/bukkit/craftbukkit.jar
		fi
		mv craftbukkit-$VERSION_CRAFTBUKKIT.jar $HOME/masterserver/bukkit/craftbukkit.jar
		MCEULA eula.txt "$HOME/masterserver/bukkit"

		if [ ! -d $HOME/masterserver/spigot ]; then
			mkdir $HOME/masterserver/spigot
		elif [ -f $HOME/masterserver/bukkit/spigot.jar ]; then
			rm -rf $HOME/masterserver/bukkit/spigot.jar
		fi
		mv spigot-$VERSION_SPIGOT.jar $HOME/masterserver/spigot/spigot.jar
		MCEULA eula.txt "$HOME/masterserver/spigot"

		echo "$VERSION_CRAFTBUKKIT" > $HOME/versions/server_bukkit.txt
		echo "$VERSION_SPIGOT" > $HOME/versions/server_spigot.txt

		if [ "$LOCAL_SPIGOT_VERSION" == "" ]; then
			LOCAL_SPIGOT_VERSION="none"
			LOCAL_CRAFTBUKKIT_VERSION="none"
		fi

		rm -rf $HOME/MCcompiler

		greenMessage "Updating Spigot from $LOCAL_SPIGOT_VERSION to $CURRENT_VERSION. Name of file is spigot.jar"
		greenMessage "Updating CraftBukkit from $LOCAL_CRAFTBUKKIT_VERSION to $CURRENT_VERSION. Name of file is craftbukkit.jar"

	elif [ "$CURRENT_VERSION" == "" ]; then
		redMessage "Recent version not detected!"
	else
		cyanMessage "Spigot and CraftBukkit already up to date. Local Spigot version is $LOCAL_SPIGOT_VERSION. Local CraftBukkit version is $LOCAL_CRAFTBUKKIT_VERSION. Most recent versions is $CURRENT_VERSION"
	fi
}

function updateAll {
	updateMTA
	echo
	updateSAMP
	echo
	updatesAddonSnapshots "metamod" "1.10" ""
	echo
	updatesAddonSnapshots "metamod" "1.11" "dev"
	echo
	updatesAddonSnapshots "sourcemod" "1.10" ""
	echo
	updatesAddonSnapshots "sourcemod" "1.11" "dev"
	echo
	updateMC
	echo
	updateBUKKIT_SPIGOT
	echo
	updateMCFORGE
	echo
	updateMCHEXXIT
	echo
	updateMCTEKKIT
	echo
	updateMCTEKKITCLASSIC
}

checkCreateFolder $HOME/versions

case $1 in
	"mta") updateMTA;;
	"samp") updateSAMP;;
	"mms") updatesAddonSnapshots "metamod" "1.10" "";;
	"mms_dev") updatesAddonSnapshots "metamod" "1.11" "dev";;
	"sm") updatesAddonSnapshots "sourcemod" "1.10" "";;
	"sm_dev") updatesAddonSnapshots "sourcemod" "1.11" "dev";;
	"mc") updateMC;;
	"spigot") updateBUKKIT_SPIGOT;;
	"bukkit") updateBUKKIT_SPIGOT;;
	"forge") updateMCFORGE;;
	"hexxit") updateMCHEXXIT;;
	"tekkit") updateMCTEKKIT;;
	"tekkit-classic") updateMCTEKKITCLASSIC;;
	"all") updateAll;;
	*) cyanMessage "Usage: ${0} mta|mms|mms_dev|sm|sm_dev|mc|spigot|bukkit|forge|hexxit|tekkit|tekkit-classic";;
esac

exit 0
