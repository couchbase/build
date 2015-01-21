# Downloads the declared version of icu4c source code, builds it,
# and creates a .tgz ready for uploading to our third-party deps repo.
#
# Resulting files (<icu4c>.tgz amd <icu4c>.md5) placed in the output/
# subdir of the Jenkins workspace.

project(cb_dep_icu4c NONE)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

SET (DEP_NAME "icu4c")

get_filename_component(PARENT_DIR ${CMAKE_CURRENT_LIST_DIR} PATH)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PARENT_DIR})
include(CBDepsMacros)

include(CPack)
include(ExternalProject)

### Download, configure and build icu4c ####################################

SET(ICU_LDFLAGS -Wl,-rpath=\\$$ORIGIN)
ExternalProject_Add(icu4c
  GIT_REPOSITORY https://github.com/couchbase/icu4c.git
  GIT_TAG ${GIT_TAG}

  CONFIGURE_COMMAND <SOURCE_DIR>/source/configure LDFLAGS=${ICU_LDFLAGS}
                                                  --prefix=<INSTALL_DIR>
                                                  --disable-extras
                                                  --disable-layout
                                                  --disable-tests
                                                  --disable-samples

  BUILD_COMMAND make -j4 all

  INSTALL_DIR ${CMAKE_BINARY_DIR}/install
  INSTALL_COMMAND make install
          COMMAND ${CMAKE_COMMAND} -E remove -f <INSTALL_DIR>/bin/derb
                                                <INSTALL_DIR>/bin/genbrk
                                                <INSTALL_DIR>/bin/gencfu
                                                <INSTALL_DIR>/bin/gencnval
                                                <INSTALL_DIR>/bin/genctd
                                                <INSTALL_DIR>/bin/genrb
                                                <INSTALL_DIR>/bin/icuinfo
                                                <INSTALL_DIR>/bin/makeconv
                                                <INSTALL_DIR>/bin/pkgdata
                                                <INSTALL_DIR>/bin/uconv
          COMMAND ${CMAKE_COMMAND} -E remove_directory <INSTALL_DIR>/sbin
          COMMAND ${CMAKE_COMMAND} -E remove_directory <INSTALL_DIR>/share

  # Need to configure icu-config to use the prefix it's been installed into.
  COMMAND ${CMAKE_COMMAND} -E echo "CONFIGURE_FILE(bin/icu-config \${CMAKE_INSTALL_PREFIX}/bin @ONLY)" > <INSTALL_DIR>/CMakeLists.txt
  COMMAND ${CMAKE_COMMAND} -E echo "FILE(COPY include lib DESTINATION \${CMAKE_INSTALL_PREFIX})" >> <INSTALL_DIR>/CMakeLists.txt
)

# Modify icu-config to replace the hardcoded prefix with a variable, which
# will be expanded at cbdeps install time.
ExternalProject_Add_Step(icu4c change_icu_config_prefix
  COMMAND sed -i -E "s/default_prefix=\"[^\"]+\"/default_prefix=\\\@CMAKE_INSTALL_PREFIX\\\@/"
          config/icu-config
  DEPENDEES build
  DEPENDERS install
  WORKING_DIRECTORY <BINARY_DIR>
)


# Custom packaging step to actually create a tar.gz
set(OUTPUT_DIR "$ENV{WORKSPACE}/output/${DEP_NAME}/${DEP_VERSION}")
set(OUTPUT_FILE "${OUTPUT_DIR}/${DEP_NAME}-${PLATFORM}-${HOST_ARCH}-${DEP_VERSION}")

ExternalProject_Add_Step(icu4c package
  COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E tar czf ${OUTPUT_FILE}.tgz .
  DEPENDEES install
  WORKING_DIRECTORY <INSTALL_DIR>
)

_GENERATE_MD5_FILE(${OUTPUT_FILE}.tgz ${OUTPUT_FILE}.md5)
