#!/usr/bin/env python
"""
Simple script for taking the output of alldependencies.py and running it
on the corresponding `fetch_project` script.

It will also return the exit code of alldependencies.py which means commit
validation scripts which use this will exit appropriately.
"""

from __future__ import print_function
import os
import platform
import subprocess
import sys

if platform.system() == 'Windows':
    FETCH_PROJECT = 'fetch_project.bat'
else:
    FETCH_PROJECT = 'fetch_project.sh'

def main():
    if len(sys.argv) != 4:
        print('usage: {} sha project refspec\n'.format(sys.argv[0]), file=sys.stderr)

    script_dir = os.path.dirname(sys.argv[0])
    script_dir = os.path.sep.join(script_dir.split('/'))

    p = subprocess.Popen(
        [sys.executable, os.path.join(script_dir, 'alldependencies.py')] + sys.argv[1:],
        stdout=subprocess.PIPE)
    p.wait()
    if p.returncode:
        return p.returncode

    for line in p.stdout:
        project, path, refspec = line.split(' ')
        print("Checking out {} in ./{} at {}".format(project, path, refspec))
        sys.stdout.flush()

        u = subprocess.Popen(
                [os.path.join(script_dir, FETCH_PROJECT), project, path, refspec])
        u.wait()

    return p.returncode



if __name__ == '__main__':
    sys.exit(main())