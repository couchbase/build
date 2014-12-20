# Downloads the declared version of libsnappy source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<snappy>.tgz amd <snappy>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_snappy NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "snappy")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})
include(CBDepsMacros)

include(CPack)
include(ExternalProject)

### Download, configure and build snappy ####################################
ExternalProject_Add(snappy
   URL https://snappy.googlecode.com/files/snappy-${GIT_TAG}.tar.gz

  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>
                                           --enable-shared
                                           --disable-static
                                           --disable-dependency-tracking
                                           --disable-gtest

  BUILD_COMMAND make all

  INSTALL_DIR ${CMAKE_BINARY_DIR}/install
  INSTALL_COMMAND make install
          COMMAND rm -r <INSTALL_DIR>/share
          COMMAND rm <INSTALL_DIR>/lib/libsnappy.la

  COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY lib include DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
)

# OS X-only: Custom post-build step to set the shared library install name.
if (APPLE)
  ExternalProject_Add_Step(snappy install_name
    COMMAND install_name_tool -id @rpath/libsnappy.1.dylib <BINARY_DIR>/.libs/libsnappy.1.dylib
    DEPENDEES build
    DEPENDERS install
    WORKING_DIRECTORY <BINARY_DIR>
  )
endif(APPLE)

# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(snappy package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
