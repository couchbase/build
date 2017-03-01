#!/bin/bash -xe

NODE_IP=${CPDSN:-127.0.0.1}
ADMIN_NAME=${CPUSER:-Administrator}
ADMIN_PASSWORD=${CPPASS:-password}

# phpunit needs 5.6 always
PHP_DIR="${BBSDK}/php-files/build/${phpver}-${phpts}-${arch}"

LCB_PATH="${BBSDK}/lcb-files/dist/${LCBVER}-${arch}/lib"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LCB_PATH

rm -rf core*
# allow to generate coredumps
ulimit -c unlimited
# display coredump pattern
/sbin/sysctl kernel.core_pattern || /usr/sbin/sysctl kernel.core_pattern || sysctl kernel.core_pattern

# Test
PHP_CMD="${PHP_DIR}/bin/php -d extension=phar.so -d extension=igbinary.so -d extension=$(pwd)/modules/couchbase.so -d couchbase.log_level=TRACE"
${PHP_CMD} -m
CPUSER=${ADMIN_NAME} CPPASS=${ADMIN_PASSWORD} CPDSN=${NODE_IP} ${PHP_CMD} ${PHP_DIR}/phpunit.phar --verbose tests/
