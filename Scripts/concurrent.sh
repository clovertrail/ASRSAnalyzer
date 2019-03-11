#!/bin/bash
if [ $# -ne 1 ]
then
  echo "Specify input file"
  exit 1
fi

input=$1
grep "\[\[" $input|awk -F , {'print $4'}|awk -F \] '{print $1}'|ministat -A
