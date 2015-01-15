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
if(WIN32)
  # msbuild uses a different names for architecture (compared to HOST_ARCH)
  if(HOST_ARCH STREQUAL "amd64")
    SET(MSBUILD_ARCH "x64")
  elseif(HOST_ARCH STREQUAL "x86")
    SET(MSBUILD_ARCH "Win32")
  else(HOST_ARCH STREQUAL "amd64")
    SET(MSBUILD_ARCH ${HOST_ARCH})
  endif(HOST_ARCH STREQUAL "amd64")

  ExternalProject_Add(breakpad
    GIT_REPOSITORY https://github.com/couchbaselabs/breakpad.git
    GIT_TAG ${GIT_TAG}

    # Configure:
    # win_{release,debug}_RuntimeLibrary: Breakpad defaults to building static
    # variants (/MT and /MTd) whereas we need the DLL variants.
    CONFIGURE_COMMAND <SOURCE_DIR>/src/tools/gyp/gyp.bat
                      <SOURCE_DIR>/src/client/windows/breakpad_client.gyp
                      --no-circular-check
                      -D win_release_RuntimeLibrary=2
                      -D win_debug_RuntimeLibrary=3

    # Build in source required for msbuild.
    BUILD_IN_SOURCE 1
    BUILD_COMMAND msbuild /p:Configuration=Debug /p:Platform=${MSBUILD_ARCH} /maxcpucount
                          src/client/windows/breakpad_client.sln
          COMMAND msbuild /p:Configuration=Release /p:Platform=${MSBUILD_ARCH} /maxcpucount
                          src/client/windows/breakpad_client.sln

    INSTALL_DIR ${CMAKE_BINARY_DIR}/install
    # Debug and Release libraries (each in their own subdir)
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/lib/Debug
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/Debug/lib/common.lib <INSTALL_DIR>/lib/Debug
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/Debug/lib/crash_generation_client.lib <INSTALL_DIR>/lib/Debug
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/Debug/lib/exception_handler.lib <INSTALL_DIR>/lib/Debug

            COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/lib/Release
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/Release/lib/common.lib <INSTALL_DIR>/lib/Release
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/Release/lib/crash_generation_client.lib <INSTALL_DIR>/lib/Release
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/Release/lib/exception_handler.lib <INSTALL_DIR>/lib/Release

    # Header files. Unfortunately normal Windows commands (xcopy etc) don't
    # like the Unix-style directory seperators which CMake uses, and CMake's
    # builtin copy / copy_directory commands don't support wildcards so we
    # end up with quite a long, explicit list...
            COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include/client/windows/common
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/common/ipc_protocol.h
                                             <INSTALL_DIR>/include/client/windows/common/

            COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include/client/windows/crash_generation
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/crash_generation/crash_generation_client.h
                                             <INSTALL_DIR>/include/client/windows/crash_generation

            COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include/client/windows/handler
            COMMAND ${CMAKE_COMMAND} -E copy src/client/windows/handler/exception_handler.h
			                                 <INSTALL_DIR>/include/client/windows/handler/

            COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include/common
            COMMAND ${CMAKE_COMMAND} -E copy src/common/scoped_ptr.h
                                             <INSTALL_DIR>/include/common/

            COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include/common/windows
            COMMAND ${CMAKE_COMMAND} -E copy src/common/windows/string_utils-inl.h
                                             <INSTALL_DIR>/include/common/windows/

            COMMAND ${CMAKE_COMMAND} -E make_directory <INSTALL_DIR>/include/google_breakpad/common
            COMMAND ${CMAKE_COMMAND} -E copy_directory src/google_breakpad/common/
                                                       <INSTALL_DIR>/include/google_breakpad/common/

    # Actual CMakeLists.txt file to copy the correct libs into our install directory.
            COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY include DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
            COMMAND ${CMAKE_COMMAND} -E echo FILE "(GLOB _breakpad_libs lib/\${CMAKE_BUILD_TYPE}/*)" >> <INSTALL_DIR>/CMakeLists.txt
            COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY \${_breakpad_libs} DESTINATION \"\${CMAKE_INSTALL_PREFIX}/lib\")" >> <INSTALL_DIR>/CMakeLists.txt
)
else(WIN32)
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
    COMMAND ${CMAKE_COMMAND} -E echo FILE "(COPY bin/minidump-2-core DESTINATION \"\${CMAKE_INSTALL_PREFIX}/bin\")" >> <INSTALL_DIR>/CMakeLists.txt
)
endif(WIN32)

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
