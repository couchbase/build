# Copies the libstdc++ from the host system into a tgz ready for uploading to
# our third-party deps repo.
#
# Resulting files (<libstdc++11>.tgz amd <libstdc++11.md5) placed in the output/
# subdir of the Jenkins workspace.
#
# Used for platforms which do not ship a C++11 compliant libstdc++.so by default,
# and hence need to redistribute one.

project(cb_dep_libstdcxx NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "libstdcxx")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})
include(CBDepsMacros)

include(ExternalProject)

### Download, configure and build jemalloc ####################################
ExternalProject_Add(libstdcxx
  SOURCE_DIR /usr/lib/x86_64-linux-gnu/

  CONFIGURE_COMMAND echo

  BUILD_COMMAND echo

  INSTALL_COMMAND mkdir <INSTALL_DIR>/lib && cp <SOURCE_DIR>/libstdc++.so.6 <INSTALL_DIR>/lib/
  COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY lib DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
)

# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(libstdcxx package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz lib CMakeLists.txt
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
