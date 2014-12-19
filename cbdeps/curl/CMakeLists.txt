# Downloads the declared version of libcurl source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<curl>.tgz amd <curl>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_curl NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "curl")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})
include(CBDepsMacros)

include(CPack)
include(ExternalProject)

### Download, configure and build curl ####################################
ExternalProject_Add(curl
   URL http://curl.haxx.se/download/curl-${GIT_TAG}.tar.gz

  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>
                                           --disable-debug
                                           --enable-optimize
                                           --disable-warnings
                                           --disable-werror
                                           --disable-curldebug
                                           --enable-shared
                                           --disable-static
                                           --without-ssl
                                           --without-gnutls
                                           --without-libssh2

  BUILD_COMMAND make all

  INSTALL_DIR ${CMAKE_BINARY_DIR}/install
  INSTALL_COMMAND make install
          COMMAND rm <INSTALL_DIR>/bin/curl
          COMMAND rm <INSTALL_DIR>/bin/curl-config
          COMMAND rm -r <INSTALL_DIR>/lib/pkgconfig
          COMMAND rm -r <INSTALL_DIR>/share
          COMMAND rm <INSTALL_DIR>/lib/libcurl.la

  COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY lib include DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
)

# OS X-only: Custom post-build step to set the shared library install name.
if (APPLE)
  ExternalProject_Add_Step(curl install_name
    COMMAND install_name_tool -id @rpath/libcurl.4.dylib <BINARY_DIR>/lib/.libs/libcurl.4.dylib
    DEPENDEES build
    DEPENDERS install
    WORKING_DIRECTORY <BINARY_DIR>
  )
endif(APPLE)

# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(curl package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
