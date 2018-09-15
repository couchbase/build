# Couchbase @@VERSION@@ Escrow

The scripts, source, and data in this directory can be used to produce
installer binaries of Couchbase Server @@VERSION@@ Enterprise Edition for any
supported version of CentOS, Debian, or Ubuntu Linux, or SuSE 11. (SuSE 12
or later can be made to work with the information here, but we cannot provide
the buildslave Docker image as it contains licensed code.)

NOTE: Oracle Enterprise Linux 6 (OEL 6) was also a supported platform for
Couchbase Server @@VERSION@@. The installer binaries for this platform were
the same as for Centos 6. Therefore you should follow these instructions
as for Centos 6 when building for OEL 6.

## Requirements

This script can be run on any flavor of Unix (Linux or MacOS) so long
as it has:

* bash
* Docker (at least 1.12)

Because the build toolchain is run inside Docker containers, you may
produce the installer for any or all of the above platforms while running
on any platform. It is not necessary to have, for example, a
Centos machine to produce a Centos binary. The operating system you are
running on does not even have to be one of the supported platforms listed
above.

The host machine should have at least 15-20 GB of free disk space per
flavor of Linux for which you wish to create installers. This does not
include the space used by this escrow distribution itself.

The host machine should have at least two CPU cores (more preferred) and
8 GB of RAM.

The escrow distribution is self contained and should not even need access
to the internet, with two exceptions:

* Couchbase Analytics code is written in Java and built with Maven,
  and Maven needs to download a number of dependencies from Maven
  Central.
* V8's build scripts are
  extremely idiosyncratic and depend heavily on binaries downloaded
  directly from Google. This unfortunately means if Google decides to
  remove those binaries in future, that portion of the build will not
  succeed.

## Build Instructions

The escrow distribution contains a top-level directory named
`couchbase-server-@@VERSION@@`. cd into this directory, and then run

    ./build-couchbase-server-from-escrow.sh <platform>

where <platform> is one of the following exact strings:

    @@PLATFORMS@@

That is all. The build will take roughly 30 minutes depending on the
speed of the machine.

Once the build is complete, the requested installer will be located in
the `couchbase-server-@@VERSION@@` directory. The name of the installer binary
various from Linux flavor to flavor. For example, the Centos 6 binary is
named:

    couchbase-server-enterprise-@@VERSION@@-centos6.x86_64.rpm

There will also be a corresponding debug-symbols package. This package
occasionally made available by Couchbase Support when debugging specific
problems on customer installations. This package should be installed on
a customer machine *in addition* to the main installer. The filename of
this debug-symbols package again varies from flavor to flavor; on Centos
6 it is named

    couchbase-server-enterprise-debug-@@VERSION@@-centos6.x86_64.rpm

## Build Synopsis

The following is a very brief overview of the steps the build takes. THis
may be useful for someone who wishes to integrate a bug fix into an
escrowed release.

### Setting up the container

The `build-couchbase-server-from-escrow.sh` script creates an instance
of a flavor-specific Docker container which contains all the necessary
toolchain elements for that flavor (gcc, CMake, and so on). It starts this
container and the copies the `deps`, `golang`, and `src` directories into
the container under `/home/couchbase`. Finally it launches the script
`in-container-build.sh` inside the container to perform the actual build.

### Building third-party dependencies

The first stage of the `in-container-build.sh` script is creating packages
for the third-party dependencies, known as "cbdeps". For each of these,
the script `src/tlm/deps/scripts/build-one-cbdep` is run to perform the
compilation. The source code for each of these cbdeps is located in the
`deps` directory of the escrow distribution. Some of these dependencies
are exactly the same code as the upstream third-party code. A few of them
have some Couchbase-specific code modifications. The subdirectories of
`deps` are in fact clones of the original Git repositories, and so you
can use `git` to view the commit logs.

The resulting cbdeps packages are stored in `/home/couchbase/.cbdepscache`
inside the container. The main Couchbase Server build process expects
to find them there.

### Go

The Couchbase Server build also makes use of several version of the Go
language. The original `golang.org` distribution packages of the necessary
versions of Go are stored in the `golang` directory.
`in-container-build.sh` simply copies these into
`/home/couchbase/.cbdepscache`, where again the main Couchbase Server
build will expect to find them.

### Couchbase Server source code

The Couchbase Server source code is located in the `src` directory.
Note: This directory is created originally by a tool named
[repo](https://source.android.com/source/downloading.html), which
was developed for the Google Android project. It takes as input an
XML manifest which specifies a number of Git repositories. These
Git repositories are downloaded from specified branches and laid out
on disk in a structure defined by the manifest.

Most of the top-level directories under `src` are such Git repositories
containing Couchbase-specific code. There are also a number of
directories deeper in the directory hierarchy under the top-level
`godeps` and `goproj` directories. These contain Go language code, laid
out on disk as two "Go workspaces". This makes it easier for the build
process to compile them.

Many of the subdirectories under `goproj` are third-party code. Go
does not have a concept of binary "libraries" as such; it always builds
from source. Therefore the normal cbdeps mechanism was not useful for
pre-compiling them. Instead we created forks of those Go projects in
GitHub and then laid them out for builds using the repo manifest. A
few of these projects have Couchbase-specific changes as well.

As with the `deps` directories, all of the repo-managed directories in
`src` are Git repositories, and so you can use the `git` tool to view
their history.

### Couchbase Server build

The main build script driving the Couchbase Server build is

    src/cbbuild/scripts/jenkins/couchbase_server/server-linux-build.sh

The path reflects the fact that this package was normally built from
a Jenkins job. This script expects to be passed several parameters,
including the Linux flavor to build; whether to build the Enterprise or
Community Edition of Couchbase Server; the version number; and a
build number. `in-container-build.sh` invokes this script with
the appropriate arguments to build Couchbase Server @@VERSION@@ Enterprise
Edition, specifying a fake build number "9999".

Couchbase Server is built using [CMake](https://cmake.org/), and
`server-linux-build.sh` mostly does some workspace initialization and
then invokes CMake with a number of arguments. The CMake scripting
has innumerable stages and is out of scope of this document, but one
of the things it does is ensure that all of the cbdeps are "downloaded"
into `/home/couchbase/.cbdepscache` along with the necessary versions
of the Go compiler. It then uncompressed those packages for use in the
remainder of the build.

### Packaging

The package (creation of a `.rpm` or `.deb` file) is handled separately.
The code and configuration for this step is in `src/voltron`.
`server-linux-build.sh` configures the `voltron` directory according to
the specific build, and then invokes a Ruby script called `server-rpm.rb`
or `server-deb.rb` in the `voltron` directory, passing a number of
arguments.

The resulting installer packages (one normal, one debug-symbol) are then
moved to the top of the build workspace. Finally, outside the container,
the original `build-couchbase-server-from-escrow.sh` script copies these
installer packages from inside to the container to the host directory.

## Escrow build notes

* The Docker container for a given build is left running after the build
is complete. If it is running and `build-couchbase-server-from-escrow.sh`
is re-run, the container will be re-used.

* The escrow build scripts are designed to not repeat long build steps
such as compiling cbdeps if built a second time. The containers also
have CCache installed, so re-builds should be relatively quick.

* When re-running `build-couchbase-server-from-escrow.sh`, the local
copy of the escrowed source code is re-copied into the container. So you
can make local modifications and then re-run the script to build them.

* However, the scripts are not heavily tested for re-builds. So we
recommend that if you make local modifications, you should do one final
clean build by first ensuring that the Docker build slave container is
destroyed. You can use `docker rm -f <slavename>` for this. The slave
name will always be "<platform>`-buildslave`", eg. `centos6-buildslave`.
You can use `docker ps -a` to show you any existing containers.

