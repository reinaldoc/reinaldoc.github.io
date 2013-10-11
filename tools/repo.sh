#!/bin/bash
# repo.sh - A simple maven repository deployer
# Copyright (c) 2012 - Reinaldo de Carvalho <reinaldoc@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA.

# Maven Repository Path
REPOPATH=/opt/github/reinaldoc.github.io/maven

# pom.xml Relative path inside jar file
POMPATH=pom.xml
POMPATH=archetype-resources/pom.xml

# Temporary directory (content will be deleted), you must update cleanup function too.
TMPFOLDER=/tmp/reposh-tmp

#
# Begin
#

function message() {
	local key="$1"
	shift
	case "$key" in
		"ErrArgNull")	echo "Error: arg should't be null" >&2;;
		"ErrFileNE")	echo "Error: $@ file should't exist" >&2;;
		"ErrDirNE")		echo "Error: $@ directory should't exist" >&2;;
		"ErrNFolder")	echo "Error: $@ isn't a folder" >&2;;
		"ErrMkFolder")	echo "Error: can't create directory $@">&2;;
		"ErrCmdNF")		echo "Error: command $@ not found">&2;;
	esac
}

function usage() {
	cleanup
	message $*
	echo "Usage: $0"
	echo "	[ -g | --group groupId |"
	echo "	  -a ... | --artifact groupId artifactId version |"
	echo "	  -j | --show-jars-content |"
	echo "	  -s | --sum-files |"
	echo "	  -p | --extract-pom |"
	echo "	  -ps | --extract-pom-and-sum-files |"
	echo "	  -c | --convert-local2remote ]"
	exit 1
}

function isEmpty {
	[[ $1 =~ ^[[:space:]]*$ ]]
	return $?
}

function isEmptyAndExit() {
	if isEmpty "$1"; then
		usage ErrArgNull
	fi
}

function isFileAndExit() {
	isEmptyAndExit "$1"
	if [ -f "$1" ]; then
		usage ErrFileNE $1
	fi
}

function isFolderAndExit() {
	isEmptyAndExit "$1"
	if [ -d "$1" ]; then
		usage ErrDirNE $1
	fi
}

function isNotFolderAndExit() {
	isEmptyAndExit "$1"
	if [ ! -d "$1" ]; then
		usage ErrNFolder $1
	fi
}

function createDirectory() {
	isFolderAndExit "$1"
	if ! mkdir -p "$1" ; then
		usage ErrMkFolder $1
	fi
}

function requireCmd() {
	# which from debianutils 3.4 don't have a silent option
	if ! which "$1" >/dev/null 2>&1; then
		usage ErrCmdNF $1
	fi
}

function buildMd5AndShaFromJarXmlPom() {
	requireCmd "md5sum"
	requireCmd "sha1sum"
	echo Building md5 and sha1 files...
	while read line ; do 
		ext=${line##*.}
		if [ -e "$line" ] ; then
			if [ "$ext" == "jar" ] || [ "$ext" == "xml" ] || [ "$ext" == "pom" ]; then
				echo "===> $line"
				echo -n $(md5sum $line) | cut -c1-32 | tr -d '\n' > $line.md5
				echo -n $(sha1sum $line) | cut -c1-40 | tr -d '\n' > $line.sha1
			fi
		fi
	done < <(ls)
}

function extractPomFromJar() {
	isNotFolderAndExit "$TMPFOLDER"
	isEmptyAndExit "$POMPATH"
	requireCmd "unzip"
	echo "Extracting pom.xml file..."
	while read line ; do 
		ext=${line##*.}
		if [ -e "$line" ] && [ "$ext" == "jar" ]; then
			# unzip return 'filename not matched' to stderr if jar doesn't have pom file
			unzip -qq "$line" "$POMPATH" -d "$TMPFOLDER" >/dev/null 2>&1
			if [ $? == 0 ] && [ -f "$TMPFOLDER/$POMPATH" ] ; then
				echo " * $line => ${line%.*}.pom"
				mv "$TMPFOLDER/$POMPATH" "${line%.*}.pom"
			fi
			cleanupAndMakeTmp
		fi
	done < <(ls)
}

function showJarsContent() {
	requireCmd "unzip"
	while read line ; do 
		ext=${line##*.}
		if [ -e "$line" ] && [ "$ext" == "jar" ]; then
			echo -e "###\n### $line\n###"
			unzip -l "$line"
		fi
	done < <(ls)

}

function convertLocal2Remote() {
	find . -name '*.lastUpdated' | xargs -n 1 rm >/dev/null 2>&1
	find . -name '_maven.repositories' | xargs -n 1 rm >/dev/null 2>&1
	find . -name 'm2e-lastUpdated.properties' | xargs -n 1 rm >/dev/null 2>&1
	find . -name 'maven-metadata-local.xml*' | while read line ; do mv "$line" "${line/-local/}" ; done
}

function newGroupId() {
	isEmptyAndExit "$1"
	echo "Creating Group Id $1"
	createDirectory "$REPOPATH/$1"
}

function getDate() {
	echo -n $(date +%Y%m%d%H%M%S)
}

# @param $1 groupId
# @param $2 artifactId
# @param $3 version
# @return void
function newMavenMetaData() {
	isNotFolderAndExit "$REPOPATH/$1"
	isNotFolderAndExit "$REPOPATH/$1/$2"
	isEmptyAndExit "$3"
	createDirectory "$REPOPATH/$1/$2/$3"
	cat <<EOF > "$REPOPATH/$1/$2/maven-metadata.xml"
<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <groupId>$1</groupId>
  <artifactId>$2</artifactId>
  <version>$3</version>
  <versioning>
    <release>$3</release>
    <versions>
      <version>$3</version>
    </versions>
    <lastUpdated>$(getDate)</lastUpdated>
  </versioning>
</metadata>
EOF

}

# @param $1 groupId
# @param $2 artifactId
# @return void
function newArtifactId() {
	isEmptyAndExit "$1"
	isNotFolderAndExit "$REPOPATH/$1"
	isEmptyAndExit "$2"
	isEmptyAndExit "$3"
	echo "Creating Artifact id $2"
	createDirectory "$REPOPATH/$1/$2"
	newMavenMetaData "$1" "$2" "$3"
}


function makeTmp() {
	isFolderAndExit "$TMPFOLDER"
	createDirectory "$TMPFOLDER"
}


function cleanup() {
	# fixed path for precaution
	if [ -d /tmp/reposh-tmp ] ; then
		rm -rf /tmp/reposh-tmp >/dev/null 2>&1
	fi
}

function cleanupAndMakeTmp() {
	cleanup
	makeTmp
}

function initialize() {
	isNotFolderAndExit "$REPOPATH"
	cleanupAndMakeTmp
}

initialize

case "$1" in
	-g|--group)
		newGroupId "$2"
	;;
	-a|--artifact)
		newArtifactId "$2" "$3" "$4"
	;;
	-j|--show-jars-content)
		showJarsContent
	;;
	-s|--sum-files)
		buildMd5AndShaFromJarXmlPom
	;;
	-p|--extract-pom)
		extractPomFromJar
	;;
	-ps|--extract-pom-and-sum-files)
		extractPomFromJar
		buildMd5AndShaFromJarXmlPom
	;;
	-c|--convert-local2remote)
		convertLocal2Remote
	;;
	*)
		usage
	;;
esac

cleanup

#
# End
#
