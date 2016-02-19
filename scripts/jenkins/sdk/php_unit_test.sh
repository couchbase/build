#!/bin/bash

NODE_IP=${CPDSN:-127.0.0.1}

# phpunit needs 5.6 always
PHP_DIR="${BBSDK}/php-files/build/5.6.17-${phpts}-${arch}/"

LCB_PATH="${BBSDK}/lcb-files/dist/2.5.3-${arch}/lib"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LCB_PATH

# Test 
CPDSN=${NODE_IP} ${PHP_DIR}/bin/php -d extension=phar.so -d extension=./modules/couchbase.so ${PHP_DIR}/phpunit.phar tests/
