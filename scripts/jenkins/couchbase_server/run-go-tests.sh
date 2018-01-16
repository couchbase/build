#!/bin/bash

mkdir -p ~/go
GOPATH=~/go go get -u github.com/jstemmer/go-junit-report
export PATH=$PATH:~/go/bin

export GOPATH=${WORKSPACE}/godeps:${WORKSPACE}/goproj

function go_test() {
   dir=$1
   pushd $dir

   echo "Running Go tests in dir: $dir"
   echo 
   go test ./... -v | go-junit-report > gotest-report.xml

   popd
}

#go_test  godeps/src/github.com/blevesearch/bleve
go_test  godeps/src/github.com/blevesearch/go-porterstemmer
go_test  godeps/src/github.com/blevesearch/segment
go_test  godeps/src/github.com/couchbase/blance
go_test  goproj/src/github.com/couchbase/cbgt
#go_test  goproj/src/github.com/couchbase/query/test/filestore # godeps/src/github.com/andelf/go-curl/callback.go:6:10: fatal error: curl/curl.h: No such file or directory
