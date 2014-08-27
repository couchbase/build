#!/bin/bash

for file in centos* debian* ubuntu*
do
	echo Rebuilding $file docker...
	cd $file
	./go &
	cd ..
done

