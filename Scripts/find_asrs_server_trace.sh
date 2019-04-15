#!/bin/bash
dir=`dirname $0`
. $dir/funcs.sh

for i in `ls signalr*ASRS.txt`
do
  echo "====$i====="
  trace_server_connections_in_ASRS $i
done
