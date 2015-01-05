# Downloads the declared version of jemalloc source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<jemalloc>.tgz amd <jemalloc>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_jemalloc NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "jemalloc")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})
include(CBDepsMacros)

include(CPack)
include(ExternalProject)

find_package(Git REQUIRED)

if (${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
  set(EXTRA_CONFIGURE_OPTIONS "--disable-tls")
endif(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")

### Download, configure and build jemalloc ####################################
ExternalProject_Add(jemalloc
  GIT_REPOSITORY https://github.com/jemalloc/jemalloc.git
  GIT_TAG ${GIT_TAG}

  CONFIGURE_COMMAND autoconf <SOURCE_DIR>/configure.ac > <SOURCE_DIR>/configure
                    COMMAND chmod u+x <SOURCE_DIR>/configure
                    COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR> --with-jemalloc-prefix=je_
                                                   ${EXTRA_CONFIGURE_OPTIONS}

  # Build in source so jemalloc correctly detects it git version.
  BUILD_IN_SOURCE 1
  BUILD_COMMAND make build_lib_shared

  INSTALL_DIR ${CMAKE_BINARY_DIR}/install
  INSTALL_COMMAND make install_lib_shared install_include
  COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY lib include DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
)

# OS X-only: Custom post-build step to set the shared library install name.
if (APPLE)
ExternalProject_Add_Step(jemalloc install_name
  COMMAND install_name_tool -id @rpath/libjemalloc.2.dylib lib/libjemalloc.2.dylib
  DEPENDEES build
  DEPENDERS install
  WORKING_DIRECTORY <BINARY_DIR>
)
endif(APPLE)

# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(jemalloc package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
