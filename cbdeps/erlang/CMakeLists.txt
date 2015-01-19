# Downloads the declared version of Erlang/OTP source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<erlang>.tgz amd <erlang>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_erlang NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "erlang")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})
include(CBDepsMacros)

include(CPack)
include(ExternalProject)

find_package(Git REQUIRED)

### Download, configure and build Erlang ####################################
SET(ERL_CFLAGS "-fno-strict-aliasing -O3 -ggdb3 -DOPENSSL_NO_EC=1")
ExternalProject_Add(erlang
  GIT_REPOSITORY https://github.com/couchbaselabs/otp.git
  GIT_TAG ${GIT_TAG}

  CONFIGURE_COMMAND ./otp_build autoconf
            COMMAND touch <SOURCE_DIR>/lib/debugger/SKIP
                          <SOURCE_DIR>/lib/dialyzer/SKIP
                          <SOURCE_DIR>/lib/megaco/SKIP
                          <SOURCE_DIR>/lib/observer/SKIP
                          <SOURCE_DIR>/lib/wx/SKIP
            COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>
                --enable-smp-support
                --disable-hipe
                --disable-fp-exceptions
                CFLAGS=${ERL_CFLAGS}

  BUILD_IN_SOURCE 1
  BUILD_COMMAND make -j8

  INSTALL_DIR ${CMAKE_BINARY_DIR}/install
  INSTALL_COMMAND make install
          COMMAND ${CMAKE_COMMAND} -E echo "FILE(COPY bin lib DESTINATION \"\${CMAKE_INSTALL_PREFIX}\")" > <INSTALL_DIR>/CMakeLists.txt
  # Invoke Erlang 'Install' to update the Erlang ROOTDIR
          COMMAND ${CMAKE_COMMAND} -E echo "EXECUTE_PROCESS(COMMAND \${CMAKE_INSTALL_PREFIX}/lib/erlang/Install -minimal \${CMAKE_INSTALL_PREFIX}/lib/erlang)" >> <INSTALL_DIR>/CMakeLists.txt
)

# OS X-only: Custom post-build step to set the shared library install name.
#if (APPLE)
#ExternalProject_Add_Step(erlang install_name
#  COMMAND install_name_tool -id @rpath/libjemalloc.2.dylib lib/libjemalloc.2.dylib
#  DEPENDEES build
#  DEPENDERS install
#  WORKING_DIRECTORY <BINARY_DIR>
#)
#endif(APPLE)

# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(erlang package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
