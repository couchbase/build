# Downloads the declared version of jemalloc source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<jemalloc>.tgz amd <jemalloc>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_jemalloc NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

include(CPack)
include(ExternalProject)

find_package(Git REQUIRED)

# Check DEP_VERSION was specified, and extract the Git SHA and Couchbase version
#   Expected format of DEP_VERSION: <git_tag>-<couchbase_version>, e.g.
#   a292cf4-cb1
# The additional couchbase_version suffix allows us to update the dependancy
# even if the upstream SHA doesn't.
if(DEP_VERSION)
  string(FIND ${DEP_VERSION} "-" SEPERATOR_POS)
  string(SUBSTRING ${DEP_VERSION} 0 ${SEPERATOR_POS} GIT_TAG)
  string(SUBSTRING ${DEP_VERSION} ${SEPERATOR_POS} -1 CB_IDENTIFIER)
else(DEP_VERSION)
  message(FATAL_ERROR "DEP_VERSION not specified - unable to build jemalloc")
endif(DEP_VERSION)

if(NOT DEFINED ENV{WORKSPACE})
  message(WARNING "ENV{WORKSPACE} not specified - assuming standalone build. Defaulting to ${CMAKE_BINARY_DIR}.")
  set(ENV{WORKSPACE} ${CMAKE_BINARY_DIR})
endif(NOT DEFINED ENV{WORKSPACE})

execute_process(COMMAND uname -m
                COMMAND tr -d '\n'
                OUTPUT_VARIABLE HOST_ARCH)


### Determine OS version. Stolen from tlm/deps. ################################

# Returns a lowercased version of a given lsb_release field.
MACRO (_LSB_RELEASE field retval)
  EXECUTE_PROCESS (COMMAND lsb_release "--${field}"
    OUTPUT_VARIABLE _output ERROR_VARIABLE _output RESULT_VARIABLE _result)
  IF (_result)
    MESSAGE (FATAL_ERROR "Cannot determine Linux revision! Output from "
      "lsb_release --${field}: ${_output}")
  ENDIF (_result)
  STRING (REGEX REPLACE "^[^:]*:" "" _output "${_output}")
  STRING (TOLOWER "${_output}" _output)
  STRING (STRIP "${_output}" ${retval})
ENDMACRO (_LSB_RELEASE)

# Returns a simple string describing the current Linux distribution
# compatibility. Possible return values currently include:
# ubuntu14.04, ubuntu12.04, ubuntu10.04, centos5, centos6, debian7.
MACRO (_DETERMINE_LINUX_DISTRO _distro)
  _LSB_RELEASE (id _id)
  _LSB_RELEASE (release _rel)
  IF (_id STREQUAL "linuxmint")
    # Linux Mint is an Ubuntu derivative; estimate nearest Ubuntu equivalent
    SET (_id "ubuntu")
    IF (_rel VERSION_LESS 13)
      SET (_rel 10.04)
    ELSEIF (_rel VERSION_LESS 17)
      SET (_rel 12.02)
    ELSE (_rel VERSION_LESS 13)
      SET (_rel 14.04)
    ENDIF (_rel VERSION_LESS 13)
  ELSEIF (_id STREQUAL "debian")
    # Just use the major from the Debian identifier - we don't need
    # different builds for different minor versions.
    STRING (REGEX MATCH "[0-9]+" _rel "${_rel}")
  ENDIF (_id STREQUAL "linuxmint")
  SET (${_distro} "${_id}${_rel}")
ENDMACRO (_DETERMINE_LINUX_DISTRO)

# Returns a simple string describing the current platform. Possible
# return values currently include: windows_msvc; macosx; or any value
# from _DETERMINE_LINUX_DISTRO.
MACRO (_DETERMINE_PLATFORM var)
  IF (DEFINED CB_DOWNLOAD_DEPS_PLATFORM)
    SET (_plat ${CB_DOWNLOAD_DEPS_PLATFORM})
  ELSE (DEFINED CB_DOWNLOAD_DEPS_PLATFORM)
    SET (_plat ${CMAKE_SYSTEM_NAME})
    IF (_plat STREQUAL "Windows")
      SET (_plat "windows_msvc")
    ELSEIF (_plat STREQUAL "Darwin")
      SET (_plat "macosx")
    ELSEIF (_plat STREQUAL "Linux")
      _DETERMINE_LINUX_DISTRO (_plat)
    ELSE (_plat STREQUAL "Windows")
      MESSAGE (FATAL_ERROR "Sorry, don't recognize your system ${_plat}. "
        "Please re-run CMake without CB_DOWNLOAD_DEPS.")
    ENDIF (_plat STREQUAL "Windows")
    MESSAGE (STATUS "Set platform to ${_plat}")
    SET (CB_DOWNLOAD_DEPS_PLATFORM ${_plat} CACHE STRING
      "Platform for cbdeps")
    MARK_AS_ADVANCED (CB_DOWNLOAD_DEPS_PLATFORM)
  ENDIF (DEFINED CB_DOWNLOAD_DEPS_PLATFORM)
  SET (${var} ${_plat})
ENDMACRO (_DETERMINE_PLATFORM)

# Need to canonicalize the CMAKE_SYSTEM_NAME to cbdeps' expected name
_DETERMINE_PLATFORM(PLATFORM)


### Download, configure and build jemalloc ####################################
ExternalProject_Add(jemalloc
  GIT_REPOSITORY https://github.com/jemalloc/jemalloc.git
  GIT_TAG ${GIT_TAG}

  CONFIGURE_COMMAND autoconf <SOURCE_DIR>/configure.ac > <SOURCE_DIR>/configure
                    COMMAND chmod u+x <SOURCE_DIR>/configure
                    COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR> --with-jemalloc-prefix=je_

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
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/jemalloc/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/jemalloc-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(jemalloc package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)


### Generate the .md5 file ####################################################
if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
  # No "md5sum" on OS X - use 'md5 instead.
  add_custom_command(TARGET jemalloc
                     POST_BUILD
                     COMMAND md5 -q ${OUTPUT_FILE}.tgz > ${OUTPUT_FILE}.md5)
else(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
  add_custom_command(TARGET jemalloc
                     POST_BUILD
                     COMMAND md5sum ${OUTPUT_FILE}.tgz | cut -d ' ' -f 1 > ${OUTPUT_FILE}.md5)
endif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
