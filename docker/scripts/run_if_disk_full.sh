#!/bin/bash -e

if [ $# -lt 2 ]
then
    echo "Usage: $0 <max_percentage> <command [args]>"
    exit 2
fi

max_percentage=$1
shift
percentage=$(df -k /home/couchbase|perl -n -e '/([0-9]+)%/ && print $1')
if [ $percentage -gt $max_percentage ]
then
    $*
fi

