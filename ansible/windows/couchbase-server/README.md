# PREREQUISITES

This playbook likely requires at least Ansible 2.3.0.

The remote Windows server needs to be ready for Ansible remote
control; see README.txt in the parent directory.

Your local world needs to have Ansible installed (obviously) and configured
for controlling Windows hosts via WinRM, which means at least running

    pip install "pywinrm>=0.1.1"

See http://docs.ansible.com/ansible/intro_windows.html#installing-on-the-control-machine
for more details.

# PLAYBOOKS

prep-for-installer.yml prepares a VM for MSI installer testing, meaning
it ensures the MS Universal CRT (UCRT) is installed and that remote desktop
is appropriately set up. That's all it does.

playbook.yml installs everything necessary for creating a Couchbase Server
build slave. The rest of this document refers only to this playbook.

# LOCAL FILE MODIFICATIONS NECESSARY BEFORE RUNNING PLAYBOOK

First, add any private key files necessary to the `ssh` directory. The
provided ssh/config file assumes that `buildbot_id_dsa` exists and can
be used to pull from Gerrit (necessary for commit-validation jobs), and
that a default key file such as `id_rsa` exists that can pull all private
GitHub repositories.

The `inventory` file here is a stub to show the required format. Replace at
least the IP address and password. Then you can run the works with

# RUNNING THE PLAYBOOK

The primary playbook here is `playbook.yml`. It will install all toolchain
requirements for building Couchbase Server (spock release or later).

    ansible-playbook -v -i inventory playbook.yml \
      -e vskey=ABCDEFGHIJKLMNOPQRSTUVWYZ

`vskey` is the license key for Visual Studio Professional 2015 (omit any
dashes in the license key).

# THINGS THAT COULD GO WRONG

This playbook worked on May 8, 2017. It does not specify explicit versions
of any of the toolchain requirements, because many of the packages (notably
Visual Studio 2015 itself) are specifically designed to install only the
latest version. That being the case, things could change over time to make
this playbook fail.

One likely issue is JAVA_HOME in ssh/environment, which version- and build-
specific and will need to be changed as newer JREs are released.

Another recurring issue is that with Ansible 2.3.0, the win_chocolatey
task appears to hang on certain packages, including wixtoolset and
visualstudiocode. None of the "Install tools" steps should take more than a
minute or so, so if one hangs for more than two minutes, you'll need to
control-C the ansible-playbook command and restart. Fortunately win_chocolatey
cleanly skips any already-installed targets so you won't lose much time.

Another somewhat likely problem is the file `vs-unattended.xml`, which is
required to specify which Visual Studio optional packages to install. C++
support itself is an optional package, so we cannot just do a default install.
But the set of named optional packages changes over time. The Visual Studio
web installer obtains the current list via a ATOM feed. So it's possible that
this fixed vs-unattended.xml file will fall out of date. (Now that MSVC 2017
has been released, however, it seems less likely.)

If this happens, you can create a new file by:

1. Download the web installer `vs_professional.exe` from

     https://www.visualstudio.com/downloads/download-visual-studio-vs

2. Run `vs_professional.exe /CreateAdminFile C:\vs-unattended.xml` to get
   the current default. (Be sure to provide an absolute path for the .xml.)

3. Edit this file. As of this date, the key thing is to change the element
   for "Common Tools for Visual C++ 2015" to `Selected="yes"`. Currently the
   ID for that element is `NativeLanguageSupport_VCV1`.

4. (Optional) Deselect any unwanted features that are enabled by default by
   setting them to `Selected="no"`. I somewhat blindly deselected the
   following IDs:

   * BlissHidden
   * JavaScript_HiddenV11
   * JavaScript
   * PortableDTPHidden
   * Silverlight5_DRTHidden
   * StoryboardingHidden
   * WebToolsV1

