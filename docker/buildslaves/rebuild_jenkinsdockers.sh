#!/bin/bash

for file in */jenkins */cv-jenkins
do
  echo Rebuilding $file docker...
  (cd $file && ./go $* )
done

