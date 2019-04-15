#!/bin/bash

function dump_trace_the_same_conn() {
  local traceId=$1
  local asrs_log=$2
  local tracedLog=`grep $traceId $asrs_log`
  local line timestamp eventName duration
  local url
  echo "$tracedLog"|while read line
  do
    timestamp=`echo "$line"|jq "._timestampUtc"|tr -d '"'`
    eventName=`echo "$line"|jq "._eventName"|tr -d '"'`
    duration=`echo "$line"|jq ".duration"|tr -d '"'`
    url=`echo "$line"|jq ".url"|tr -d '"'`
    echo "$timestamp $eventName $url $duration"
  done
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
 grep "ConnectedEnding" $in|grep hzperf > $tmp_out
 while read line
 do
  timestamp=`echo "$line"|jq "._timestampUtc"|tr -d '"'`
  id=`echo "$line"|jq ".userId"|tr -d '"'`
  echo "$timestamp $id"
 done < $tmp_out
 rm $tmp_out
}

function find_all_ASRS_server_drop() {
  local i
  for i in `ls signalr*ASRS.txt`
  do
    echo "====$i====="
    find_server_drop_ASRS $i
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
    grep "$line" $tmpOut >$output_dir/$dateDir/drop.txt
  done < $dateOut
  rm $tmpOut $dateOut
}
