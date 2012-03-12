#!/bin/bash

function isEmpty() {
	var1=$(tr -d ' '<<<$1 | tr -d '\t')
	if [ "x$var1" == "x" ]; then
		return 0
	fi
	return 1
}

while read getPid; do
	isEmpty "$getPid"
	if [ $? == 1 ]; then
		echo Killing pid $getPid
		kill -9 "$getPid"
	fi
done < <(ps -ef | grep org.jboss.Main | grep -v grep | tr -s ' ' | cut -f2 -d ' ')
