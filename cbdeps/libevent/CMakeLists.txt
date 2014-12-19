# Downloads the declared version of libevent source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<libevent>.tgz amd <libevent>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_libevent NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "libevent")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})
include(CBDepsMacros)

include(CPack)
include(ExternalProject)

### Download, configure and build libevent ####################################
ExternalProject_Add(libevent
   URL https://github.com/downloads/libevent/libevent/libevent-${GIT_TAG}-stable.tar.gz

  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR> --enable-thread-support --disable-dependency-tracking --disable-openssl --disable-debug-mode --disable-libevent-regress --enable-shared --disable-static

  BUILD_COMMAND make all

  INSTALL_DIR ${CMAKE_BINARY_DIR}/install
  INSTALL_COMMAND make install
          COMMAND rm <INSTALL_DIR>/bin/event_rpcgen.py
          COMMAND rm -r <INSTALL_DIR>/lib/pkgconfig
          COMMAND rm <INSTALL_DIR>/lib/libevent.la
          COMMAND rm <INSTALL_DIR>/lib/libevent_core.la
          COMMAND rm <INSTALL_DIR>/lib/libevent_extra.la
          COMMAND rm <INSTALL_DIR>/lib/libevent_pthreads.la
          COMMAND rm -f <INSTALL_DIR>/lib/libevent-2.0.5.dylib
          COMMAND rm -f <INSTALL_DIR>/lib/libevent.dylib
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_extra-2.0.5.dylib
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_extra.dylib
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_pthreads-2.0.5.dylib
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_pthreads.dylib
          COMMAND rm -f <INSTALL_DIR>/lib/libevent-2.0.5.so
          COMMAND rm -f <INSTALL_DIR>/lib/libevent.so
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_extra-2.0.5.so
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_extra.so
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_pthreads-2.0.5.so
          COMMAND rm -f <INSTALL_DIR>/lib/libevent_pthreads.so

  COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY lib include DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
)

# OS X-only: Custom post-build step to set the shared library install name.
if (APPLE)
ExternalProject_Add_Step(libevent install_name
  COMMAND install_name_tool -id @rpath/libevent_core-2.0.5.dylib <BINARY_DIR>/.libs/libevent_core-2.0.5.dylib
  DEPENDEES build
  DEPENDERS install
  WORKING_DIRECTORY <BINARY_DIR>
)
endif(APPLE)

# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(libevent package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
