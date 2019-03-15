#!/bin/bash

for i in `ls signalr*_ASRS.tgz`
do
  tar zxvf $i
done
