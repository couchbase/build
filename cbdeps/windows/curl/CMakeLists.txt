# Downloads the declared version of libcurl source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.

PROJECT (cb_dep_curl_windows NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (_curlfile "curl-${DEP_VERSION}.zip")
MESSAGE (STATUS "Downloading ${_curlfile}...")
FILE (DOWNLOAD "http://curl.haxx.se/download/${_curlfile}"
  "${CMAKE_BINARY_DIR}/${_curlfile}" STATUS _stat SHOW_PROGRESS)
LIST (GET _stat 0 _retval)
IF (_retval)
  LIST (GET _stat 1 _message)
  MESSAGE (FATAL_ERROR "Error downloading: ${_message}")
ENDIF (_retval)
SET (_explodedir "${CMAKE_BINARY_DIR}/curl.exploded")
FILE (MAKE_DIRECTORY "${_explodedir}")

# Yes, "cmake -E tar" handles zipfiles.
EXECUTE_PROCESS (COMMAND "${CMAKE_COMMAND}" -E
  tar xf "${CMAKE_BINARY_DIR}/${_curlfile}"
  WORKING_DIRECTORY "${_explodedir}")

# Defer to .bat script to invoke MSVC
# QQQ hard-coding amd64 for the moment
EXECUTE_PROCESS (
  COMMAND "${CMAKE_SOURCE_DIR}/compile_curl.bat" AMD64
  WORKING_DIRECTORY "${_explodedir}/curl-${DEP_VERSION}/winbuild"
  RESULT_VARIABLE _retval)
MESSAGE (STATUS "Complete with ${_retval}")

# Here's where the results are!
SET (_resultdir
  "${_explodedir}/curl-${DEP_VERSION}/builds/libcurl-vc-x64-release-dll-ipv6-sspi-spnego-winssl")
# Add the generic CMakeLists.txt
CONFIGURE_FILE ("${CMAKE_SOURCE_DIR}/../../utils/GenericCopyCMakeLists.txt.in"
  "${_resultdir}/CMakeLists.txt" COPY_ONLY)

# tgz up the results
SET (_outputdir "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
# QQQ again hard-coded AMD64
SET (_outputfile "${_outputdir}/${DEP_NAME}-windows-AMD64-${DEP_VERSION}")
FILE (MAKE_DIRECTORY "${_outputdir}")
EXECUTE_PROCESS (COMMAND "${CMAKE_COMMAND}" -E
  tar cvf "${_outputfile}.tgz"
  WORKING_DIRECTORY "${_resultdir}")
FILE (MD5 "${_outputfile}.tgz" _md5)
FILE (WRITE "${_outputfile}.md5" ${_md5})
