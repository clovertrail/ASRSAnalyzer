#!/bin/bash

for i in `ls *appserver.log.tgz`
do
  tar zxvf $i
done
