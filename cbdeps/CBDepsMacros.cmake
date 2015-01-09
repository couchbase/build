#
# Collection of common macros and code for building CB Dependencies
# e.g. Determine OS platform, create an MD5sum file
#
# The following are the variables set by this script:
# GIT_TAG
# CB_IDENTIFIER
# HOST_ARCH
# PLATFORM

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

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
    ELSEIF (_plat STREQUAL "SunOS")
      SET (_plat "sunos")
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
  ELSEIF (_id STREQUAL "debian" OR _id STREQUAL "centos" )
    # Just use the major version from the CentOS/Debian identifier - we don't
    # need different builds for different minor versions.
    STRING (REGEX MATCH "[0-9]+" _rel "${_rel}")
  ENDIF (_id STREQUAL "linuxmint")
  SET (${_distro} "${_id}${_rel}")
ENDMACRO (_DETERMINE_LINUX_DISTRO)

# Check DEP_VERSION was specified, and extract the Git SHA and Couchbase version
#   Expected format of DEP_VERSION: <git_tag>-<couchbase_version>, e.g.
#   a292cf4-cb1
# The additional couchbase_version suffix allows us to update the dependancy
# even if the upstream SHA doesn't.
MACRO (_CHECK_FOR_DEP_VERSION)
  if(DEP_VERSION)
    string(FIND ${DEP_VERSION} "-" SEPERATOR_POS)
    string(SUBSTRING ${DEP_VERSION} 0 ${SEPERATOR_POS} GIT_TAG)
    string(SUBSTRING ${DEP_VERSION} ${SEPERATOR_POS} -1 CB_IDENTIFIER)
  else(DEP_VERSION)
    message(FATAL_ERROR "DEP_VERSION not specified - unable to build ${DEP_NAME}")
  endif(DEP_VERSION)
ENDMACRO (_CHECK_FOR_DEP_VERSION)

### Generate the .md5 file ####################################################
MACRO (_GENERATE_MD5_FILE sourcefile md5file)
  if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    # No "md5sum" on OS X - use 'md5 instead.
    add_custom_command(TARGET ${DEP_NAME}
      POST_BUILD
    COMMAND md5 -q ${sourcefile} > ${md5file})
  elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    # No "md5sum" on Windows - use cmake's builtin and strip the filename off it.
    add_custom_command(TARGET ${DEP_NAME}
      POST_BUILD
    COMMAND FOR /F "usebackq" %i IN (`cmake -E md5sum ${sourcefile}`) DO echo %i> ${md5file})
  else(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    add_custom_command(TARGET ${DEP_NAME}
      POST_BUILD
    COMMAND md5sum ${sourcefile} | cut -d ' ' -f 1 > ${md5file})
  endif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
ENDMACRO (_GENERATE_MD5_FILE)


#
# Standard code run on include to perform common checks and setup useful vars
#
if (${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
  execute_process(COMMAND isainfo -k
    COMMAND tr -d '\n'
  OUTPUT_VARIABLE HOST_ARCH)
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
  if (DEFINED ENV{PROCESSOR_ARCHITEW6432})
    string(TOLOWER "$ENV{PROCESSOR_ARCHITEW6432}" HOST_ARCH)
   else()
    string(TOLOWER "$ENV{PROCESSOR_ARCHITECTURE}" HOST_ARCH)
  endif()
else(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
  execute_process(COMMAND uname -m
    COMMAND tr -d '\n'
  OUTPUT_VARIABLE HOST_ARCH)
endif(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")

_CHECK_FOR_DEP_VERSION()

if(NOT DEFINED ENV{WORKSPACE})
  message(WARNING "ENV{WORKSPACE} not specified - assuming standalone build. Defaulting to ${CMAKE_BINARY_DIR}.")
  set(ENV{WORKSPACE} ${CMAKE_BINARY_DIR})
endif(NOT DEFINED ENV{WORKSPACE})

# Need to canonicalize the CMAKE_SYSTEM_NAME to cbdeps' expected name
_DETERMINE_PLATFORM(PLATFORM)
