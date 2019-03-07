#!/bin/bash

function find_server_drop_ASRS() {
 local in=$1
 local line
 grep "ConnectedEnding" $in|grep hzperf > /tmp/serverdrop
 while read line
 do
  timestamp=`echo "$line"|jq "._timestampUtc"|tr -d '"'`
  id=`echo "$line"|jq ".userId"|tr -d '"'`
  echo "$timestamp $id"
 done < /tmp/serverdrop
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
  local i
  local totalTop
  local nonZero
  local nonZeroPer
  local ministat result tmpResult
  for i in `ls signalr*top.txt`
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
  calculateCPUTopInternal "Micro" $tailCheck $headCheck
}

function calculateRubyCPUTop() {
  local tailCheck=50
  local headCheck=30
  if [ $# -eq 2 ]
  then
     tailCheck=$1
     headCheck=$2
  fi
  calculateCPUTopInternal "rub" $tailCheck $headCheck
}