#!/bin/bash
dir=`dirname $0`

function dump_trace_the_same_conn() {
  local traceId=$1
  local asrs_log=$2
  local tracedLog=`grep $traceId $asrs_log`
  local line timestamp eventName duration startTime endTime
  local url cid uid
  local lifeSpan userId
  local tmpFile=/tmp/traceid`date +%Y%m%d%H%M%S`

  echo "$tracedLog" > $tmpFile
  while read line
  do
    timestamp=`echo "$line"|jq "._timestampUtc"|tr -d '"'`
    eventName=`echo "$line"|jq "._eventName"|tr -d '"'`
    duration=`echo "$line"|jq ".duration"|tr -d '"'`
    url=`echo "$line"|jq ".url"|tr -d '"'`
    uid=`echo "$line"|jq ".userId"|tr -d '"'`
    if [ "$uid" != "null" ]
    then
       userId=$uid
    fi
    if [ "$url" != "null" ] && [ "$duration" == "null" ]
    then
       startTime=$timestamp
       cid=`echo "$url"|awk -F \& '{print $2}'|awk -F = '{print $2}'`
    fi
    if [ "$duration" != "null" ]
    then
       endTime=$timestamp
       lifeSpan=$duration
    fi
  done < $tmpFile
  rm $tmpFile
  echo " $cid $userId $startTime $endTime $lifeSpan"
}

function dump_exception_count() {
  local asrs_log=$1
  local line timestamp eventName
  local tmpFile=/tmp/redistimeout`date +%Y%m%d%H%M%S`
  if [ "$g_exp2" == "" ]
  then
    grep "$g_exp" $asrs_log > $tmpFile
  else
    grep "$g_exp" $asrs_log|grep "$g_exp2" > $tmpFile
  fi
  python $dir/parse_asrs_log.py -i $tmpFile -q counter|sort -k 1
  rm $tmpFile
}

function dump_exception_details() {
  local asrs_log=$1
  local line timestamp eventName
  local tmpFile=/tmp/redistimeout`date +%Y%m%d%H%M%S`
  if [ "$g_exp2" == "" ]
  then
    grep "$g_exp" $asrs_log > $tmpFile
  else
    grep "$g_exp" $asrs_log|grep "$g_exp2" > $tmpFile
  fi
  python $dir/parse_asrs_log.py -i $tmpFile -q details|sort -k 1 -t '|'
  rm $tmpFile
}

function trace_server_connections_in_ASRS() {
  local in=$1 # ASRS.log
  local i traceId line
  local postfix=`date +%Y%m%d%H%M%S`
  local serverConnRaw=/tmp/serverConnRaw${postfix}
  grep "New server connection" $in > $serverConnRaw
  while read line
  do
    traceId=`echo "$line"|jq ".traceId"|tr -d '"'`
    dump_trace_the_same_conn $traceId $in
    #grep $traceId $in
  done < $serverConnRaw
  rm $serverConnRaw
}

function find_server_drop_ASRS() {
 local in=$1
 local tmp_out=/tmp/serverdrop
 local line
 grep "ConnectedEnding" $in|grep "SignalRServerConnection" > $tmp_out
 while read line
 do
  timestamp=`echo "$line"|jq "._timestampUtc"|tr -d '"'`
  id=`echo "$line"|jq ".userId"|tr -d '"'`
  echo "$timestamp $id"
 done < $tmp_out
 rm $tmp_out
}

function find_all_ASRS_server_drop() {
  iterate_all_asrs_log find_server_drop_ASRS
}

function find_all_redis_timeout_count() {
  g_exp="StackExchange.Redis.RedisTimeoutException"
  g_exp2=""
  iterate_all_asrs_log dump_exception_count
}

function find_all_redis_timeout_details() {
  g_exp="StackExchange.Redis.RedisTimeoutException"
  g_exp2=""
  iterate_all_asrs_log dump_exception_details
}

function find_all_redis_conn_count() {
  g_exp="StackExchange.Redis.RedisConnectionException"
  g_exp2=""
  iterate_all_asrs_log dump_exception_count
}

function find_all_redis_conn_details() {
  g_exp="StackExchange.Redis.RedisConnectionException"
  g_exp2=""
  iterate_all_asrs_log dump_exception_details
}

function find_all_redis_route_close_count() {
  g_exp="Connection to Redis failed"
  g_exp2="Microsoft.Azure.SignalR.Redis.RedisClient"
  iterate_all_asrs_log dump_exception_count
}

function find_all_redis_route_restore_count() {
  g_exp="Connection to Redis restored"
  g_exp2="Microsoft.Azure.SignalR.Redis.RedisClient"
  iterate_all_asrs_log dump_exception_count
}

function find_all_redis_route_close_details() {
  g_exp="Connection to Redis failed"
  g_exp2="Microsoft.Azure.SignalR.Redis.RedisClient"
  iterate_all_asrs_log dump_exception_details
}

function find_all_redis_route_restore_details() {
  g_exp="Connection to Redis restored"
  g_exp2="Microsoft.Azure.SignalR.Redis.RedisClient"
  iterate_all_asrs_log dump_exception_details
}

function find_all_redis_pubsub_close_count() {
  g_exp="Connection to Redis failed"
  g_exp2="Microsoft.Azure.SignalR.Redis.PubSubClient"
  iterate_all_asrs_log dump_exception_count
}

function find_all_redis_pubsub_restore_count() {
  g_exp="Starting heartbeat..."
  iterate_all_asrs_log dump_exception_count
}

function find_all_redis_pubsub_close_details() {
  g_exp="Connection to Redis failed"
  g_exp2="Microsoft.Azure.SignalR.Redis.PubSubClient"
  iterate_all_asrs_log dump_exception_details
}

function find_all_redis_pubsub_restore_details() {
  g_exp="Starting heartbeat..."
  iterate_all_asrs_log dump_exception_details
}

function iterate_all_asrs_log() {
  local callback=$1
  local i
  for i in `ls signalr*ASRS.txt`
  do
    echo "====$i====="
    $callback $i
  done
}

function calculateCPUTopInternal()
{
  local key=$1
  local tailCheck=$2
  local headCheck=$3
  local fileReg="$4"
  local i
  local totalTop
  local nonZero
  local nonZeroPer
  local ministat result tmpResult
  for i in `ls $fileReg`
  do
    tmpResult=`grep $key $i|tail -n $tailCheck|head -n $headCheck`
    totalTop=`echo "$tmpResult"|awk '{print $9}'|wc -l`
    nonZero=`echo "$tmpResult"|awk '{if ($9>0) print $9}'|wc -l`
    nonZeroPer=`echo $totalTop $nonZero|awk '{printf("%.2f", $2/$1)}'`
    result=`echo "$tmpResult"|awk '{if ($9>0) print $9}'|ministat -A`
    echo "======$i: $nonZeroPer========"
    echo "$result"
  done
}

function calculateMemMaxMinInternal()
{
  local key=$1
  local seg=$2
  local i
  local min max
  for i in `ls signalr*top.txt`
  do
    max=`grep $key $i|awk '{if ($10>0) print $10}'|sort -k 1 -n -r|head -n $seg|head -n 1`
    min=`grep $key $i|awk '{if ($10>0) print $10}'|sort -k 1 -n -r|head -n $seg|tail -n 1`
    echo "======$i: $min~$max========"
  done
}

function calculateASRSMemMaxMin() {
  local seg=20
  if [ $# -eq 1 ]
  then
    seg=$1
  fi
  calculateMemMaxMinInternal $seg
}

function calculateASRSCPUTop() {
  local tailCheck=50
  local headCheck=30
  if [ $# -eq 2 ]
  then
     tailCheck=$1
     headCheck=$2
  fi
  calculateCPUTopInternal "Micro" $tailCheck $headCheck "signalr*top.txt"
}

function calculateRubyCPUTop() {
  local tailCheck=50
  local headCheck=30
  if [ $# -eq 2 ]
  then
     tailCheck=$1
     headCheck=$2
  fi
  calculateCPUTopInternal "rub" $tailCheck $headCheck "signalr*top.txt"
}

function calculateAppServerCPUTop() {
  local tailCheck=50
  local headCheck=30
  if [ $# -eq 2 ]
  then
     tailCheck=$1
     headCheck=$2
  fi
  calculateCPUTopInternal "dotnet" $tailCheck $headCheck "appserver*_top.txt"
}

function filter_date_prefix() {
  local app_server_log=$1
  local output_dir=$2
  local timestamp=`date +%Y%m%d%H%M%S`
  local tmpOut=/tmp/appserver${timestamp}.log
  local dateOut=/tmp/appserverdate${timestamp}.txt
  grep "drop" $app_server_log > $tmpOut
  # output  [2019:01:24:04:53:29.167]:
  # output  [2019:01:24:04:53:29
  # output [2019:01:24
  awk '{print $1}' $tmpOut| awk -F . '{print $1}'| awk -F : '{printf("%s:%s:%s\n", $1,$2,$3)}'| awk -F \[ '{print $2}'|  sort|uniq > $dateOut
  local line dateDir
  while read line
  do
    dateDir=$line
    mkdir -p $output_dir/$dateDir
    grep "$line" $tmpOut > $output_dir/$dateDir/drop.txt
    # remove "]:"
    sed -i -e 's/\]\://g' $output_dir/$dateDir/drop.txt
    # remove "["
    sed -i -e 's/\[//g' $output_dir/$dateDir/drop.txt
    awk '{print $1 " " $3}' $output_dir/$dateDir/drop.txt > $output_dir/$dateDir/drop_sum.txt
    rm $output_dir/$dateDir/drop.txt
  done < $dateOut
  rm $tmpOut $dateOut
}
