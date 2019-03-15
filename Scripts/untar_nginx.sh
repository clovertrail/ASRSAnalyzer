#!/bin/bash

for i in `ls nginx*.log.tgz`
do
  tar zxvf $i
done
