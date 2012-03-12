#!/bin/bash
# feeling-equals.sh - A simple file founder by similar parent path depth
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

# inverse file depth to feeling as same file
INVERSEDEPTHSIZE=4

# regexp to filter some files
REGEXP=".*\\.java$"

# compare mode. size or md5
COMPAREMODE="md5"

# default search directory
WORKDIR="."

# display all inverse depth founded files or only changed
ALLFILES=false

#
# Begin
#

# @param $1 string to be chcked
function isEmpty {
	[[ $1 =~ ^[[:space:]]*$ ]]
	return $?
}

# @oaram $1 string to be checked
# @param $2 string to be printed before exit
function isEmptyAndExit {
	if isEmpty "$1" ; then
		if ! isEmpty "$2"; then
			echo "$2"
		fi
		exit
	fi
}

# @param $1 array of program arguments
function processArgs() {
	argsArray=("$@")
	
	i=0
	while [ "$i" != "${#argsArray[@]}" ] ; do
		case "${argsArray[i]}" in
			-w|--workdir)
				isEmptyAndExit "${argsArray[i+1]}" "Workdir is not set"
				WORKDIR="${argsArray[i+1]}"
				let i++
			;;
			-d|--inverse-max-depth)
				isEmptyAndExit "${argsArray[i+1]}" "Max depth is not set"
				INVERSEDEPTHSIZE="${argsArray[i+1]}"
				let i++
			;;
			-f|--filter)
				isEmptyAndExit "${argsArray[i+1]}" "Filter is not set"
				REGEXP=".*${argsArray[i+1]}$REGEXP"
				let i++
			;;
			-c|--compare-mode)
				isEmptyAndExit "${argsArray[i+1]}" "Compare mode is not set"
				if [ "${argsArray[i+1]}" == "md5" ] || [ "${argsArray[i+1]}" == "size" ]; then
					COMPAREMODE="${argsArray[i+1]}"
				else
					isEmptyAndExit "" "Invalid compare mode. Please use md5 or size"
				fi
				let i++
			;;
			-s|--show-matched-files)
					ALLFILES="true"
			;;
			-h|--help)
				echo "Usage: $0 [ OPTION VALUE ]"
				echo "Options:"
				echo "	[ --workdir/-w DIR ]"
				echo "	[ --inverse-max-depth/-d NUMBER ]"
				echo "	[ --filter/-f STRING ]"
				echo "	[ --compare-mode/-c [ md5 | size ] ]"
				echo "	[ --show-matched-files/-s ]"
				exit
			;;
		esac
		let i++
	done

}

# @param $1 a file
# @param $2 a file
# @action set result variable to size1:size2
function setResultIfSizeNotEquals() {
	local size=($(stat --format %s "$1" "$2"))
	if [ "${size[0]}" != "${size[1]}" ] ; then
		result="${size[0]}:${size[1]}"
	fi
}

# @param $1 a file
# @param $2 a file
# @action set result variable to hash1:hash2
function setResultIfHashNotEquals() {
	local sum=($(md5sum "$1" "$2"))
	if [ "${sum[0]}" != "${sum[2]}" ] ; then
		result="${sum[0]}:${sum[2]}"
	fi
}

# @param $1 compare mode. "size" or "md5"
# @param $2 a file
# @param $3 a file
# @return boolean
function setResultIfFilesNotEquals() {
	result=""
	if [ "$1" == "size" ] ; then
		setResultIfSizeNotEquals "$2" "$3"
	else
		setResultIfHashNotEquals "$2" "$3"
	fi
}

#    compare the first element with others array elements
# if found a element set variable called index to the element position
#
# @param $1 array to be searched
#        the first element is the element to be searched
# @return String
function setArrayIndex() {
	index=""
	local array=("$@")
	local item="${array[i]}"
	i=1
	while [ "$i" != "${#array[@]}" ] ; do
		if [ "${array[i]}" == "$1" ]; then
			let i--
			index=$i
			return 0
		fi
		let i++
	done
}


function main() {

	processArgs "$@"

	while read fullpathIter; do
		revPathIter=$(rev <<<$fullpathIter | cut -d / -f1-$INVERSEDEPTHSIZE | rev)
		setArrayIndex "$revPathIter" "${revPathArray[@]}"
		if ! isEmpty "$index"; then
			status="equals"
			setResultIfFilesNotEquals "$COMPAREMODE"  "$fullpathIter" "${fullPathArray[index]}"
			if ! isEmpty "$result" ; then
				status="changed"
			fi
			if [ "$status" == "equals" ] && [ "x$ALLFILES" == "xfalse" ]  ; then
				continue
			fi
			echo "Origin:	$fullpathIter (${result%%:*})"
			echo "Found:	${fullPathArray[index]} (${result##*:} -> $status)" 
			echo
		else
			fullPathArray=("${fullPathArray[@]}" "$fullpathIter")
			revPathArray=("${revPathArray[@]}" "$revPathIter")
		fi
	done < <(find "$WORKDIR" -regex "$REGEXP")

}

main "$@"


#
# End
#
