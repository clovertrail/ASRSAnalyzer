#!/bin/bash
dir=`dirname $0`
. $dir/funcs.sh


if [ $# -ne 2 ]
then
  echo "specify app_server_log outDir"
  exit 1
fi

filter_date_prefix $*
