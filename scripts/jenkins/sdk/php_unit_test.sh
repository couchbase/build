#!/bin/bash -xe

NODE_IP=${CPDSN:-127.0.0.1}

# phpunit needs 5.6 always
PHP_DIR="${BBSDK}/php-files/build/${phpver}-${phpts}-${arch}"

LCB_PATH="${BBSDK}/lcb-files/dist/${LCBVER}-${arch}/lib"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LCB_PATH

# allow to generate coredumps
ulimit -c unlimited
# display coredump pattern
sysctl kernel.core_pattern

# Test
CPDSN=${NODE_IP} ${PHP_DIR}/bin/php -d extension=phar.so -d extension=./modules/couchbase.so ${PHP_DIR}/phpunit.phar tests/
