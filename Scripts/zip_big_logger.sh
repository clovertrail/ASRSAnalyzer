#!/bin/bash

if [ $# -ne 2 ]
then
  echo "<dir> <file>"
  exit 1
fi
sz=100M
function zip_all() {
  local dir=$1
  local f=$2
  local tdir
  find $dir -iname $f -size +$sz > /tmp/zip_bigger_files.txt
  while read line
  do
    tdir=`dirname $line`
    cd $tdir
    tar zcvf ${f}.tgz $f
    rm $f
    cd -
  done < /tmp/zip_bigger_files.txt
}

zip_all $*
