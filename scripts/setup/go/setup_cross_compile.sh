#!/bin/bash

pushd ${GOROOT}/src  2>&1 > /dev/null
echo ......... now in  ${GOROOT}/src

echo -------- step 1
./make.bash

echo -------- step 2
for arch in 8 6
    do
    for cmd in a c g l
        do
        go tool dist install -v cmd/$arch$cmd
    done
done

echo -------- step 3
export CGO_ENABLED=0 

 echo ..............windows........amd64
 CGO_ENABLED=0 GOOS=windows GOARCH=amd64   ./make.bash --no-clean
 CGO_ENABLED=0 GOOS=windows GOARCH=amd64   go tool dist install -v pkg/runtime
 CGO_ENABLED=0 GOOS=windows GOARCH=amd64   go install -v -a std

 echo ..............windows........386
 CGO_ENABLED=0 GOOS=windows GOARCH=386     ./make.bash --no-clean
 CGO_ENABLED=0 GOOS=windows GOARCH=386     go tool dist install -v pkg/runtime
 CGO_ENABLED=0 GOOS=windows GOARCH=386     go install -v -a std

echo -------- step 4
export CGO_ENABLED=0 

 echo ..............linux.............ARM
 CGO_ENABLED=0 GOOS=linux  GOARCH=arm          ./make.bash --no-clean
 CGO_ENABLED=0 GOOS=linux  GOARCH=arm          go tool dist install -v pkg/runtime
 CGO_ENABLED=0 GOOS=linux  GOARCH=arm          go install -v -a std

echo -------- step 5
export CGO_ENABLED=0 

 echo ..............linux.............386
 CGO_ENABLED=0 GOOS=linux  GOARCH=386          ./make.bash --no-clean
 CGO_ENABLED=0 GOOS=linux  GOARCH=386          go tool dist install -v pkg/runtime
 CGO_ENABLED=0 GOOS=linux  GOARCH=386          go install -v -a std

 echo ..............linux.............ARM5
 CGO_ENABLED=0 GOOS=linux  GOARCH=arm GOARM=5  ./make.bash --no-clean
 CGO_ENABLED=0 GOOS=linux  GOARCH=arm GOARM=5  go tool dist install -v pkg/runtime
 CGO_ENABLED=0 GOOS=linux  GOARCH=arm GOARM=5  go install -v -a std

 echo ..............freebsd...........amd64
 CGO_ENABLED=0 GOOS=freebsd    GOARCH=amd64    ./make.bash --no-clean
 CGO_ENABLED=0 GOOS=freebsd    GOARCH=amd64    go tool dist install -v pkg/runtime
 CGO_ENABLED=0 GOOS=freebsd    GOARCH=amd64    go install -v -a std

echo -------- step 6
export CGO_ENABLED=0 
 echo ..............darwin............amd64
 CGO_ENABLED=0 GOOS=darwin     GOARCH=amd64    ./make.bash --no-clean
 CGO_ENABLED=0 GOOS=darwin     GOARCH=amd64    go tool dist install -v pkg/runtime
 CGO_ENABLED=0 GOOS=darwin     GOARCH=amd64    go install -v -a std

echo ......... now back
popd                 2>&1 > /dev/null

