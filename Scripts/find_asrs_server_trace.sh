#!/bin/bash
dir=`dirname $0`
. $dir/funcs.sh


for i in `ls signalr*ASRS.txt| awk -F _ '{print $1}'|sort|uniq`
do
   j=${i}*ASRS.txt
   echo "====${j}===="
   trace_server_connections_in_ASRS "$i"
done
