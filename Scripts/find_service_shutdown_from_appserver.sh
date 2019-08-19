#!/bin/bash
dir=`dirname $0`
. $dir/funcs.sh

if [ $# -ne 1 ]
then
  echo "specify app_server_log"
  exit 1
fi

find_service_shutdown_on_applog $1
