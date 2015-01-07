# Downloads the declared version of breakpad source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<breakpad>.tgz amd <breakpad>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_breakpad NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "breakpad")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})

include(CBDepsMacros)
include(CPack)
include(ExternalProject)

find_package(Git REQUIRED)

### Download, configure and build breakpad ####################################
ExternalProject_Add(breakpad
  GIT_REPOSITORY https://github.com/couchbaselabs/breakpad.git
  GIT_TAG ${GIT_TAG}

  CONFIGURE_COMMAND autoreconf -i
            COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>

  # Build in source so breakpad correctly detects it git version.
  BUILD_IN_SOURCE 1
  BUILD_COMMAND make

  INSTALL_DIR ${CMAKE_BINARY_DIR}/install
  INSTALL_COMMAND make install
  COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY lib include DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
)

# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(breakpad package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
