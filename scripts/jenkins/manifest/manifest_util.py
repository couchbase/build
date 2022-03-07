#!/usr/bin/env python

import argparse
import contextlib
import json
import os
import pprint

from subprocess import check_call


@contextlib.contextmanager
def remember_cwd():
    curdir = os.getcwd()
    try:
        yield
    finally:
        os.chdir(curdir)


def scan_manifests(manifest_repo="https://github.com/couchbase/manifest"):
    """
    Syncs to the "manifest" project from the given repository, and
    returns a list of metadata about all discovered manifests
    """
    # Sync manifest project
    # QQQ Probably should create different manifest directories based
    # on the manifest_repo URL here, so we can support multiple manifest
    # repositories.  Doing so will require returning the directory
    # containing the manifest repo as part of the return value of this
    # function, and updating other scripts to reference that if they want
    # to read the actual manifest files.
    if not os.path.isdir("manifest"):
        check_call(["git", "clone", manifest_repo, "manifest"])

    with remember_cwd():
        os.chdir("manifest")
        print("Updating manifest repository...")
        check_call(["git", "pull"])

        # Scan the current directory for build manifests.
        manifests = {}
        for root, dirs, files in os.walk("."):
            # Prune all legacy manifests, including those in the top-level dir
            if root == ".":
                dirs.remove(".git")
                if "toy" in dirs:
                    dirs.remove("toy")

                if "released" in dirs:
                    dirs.remove("released")

                continue

            # Load manifest metadata where specified
            if "product-config.json" in files:
                with open(os.path.join(root, "product-config.json"),
                          "r") as conffile:
                    config = json.load(conffile)
                    if "manifests" not in config:
                        continue

                    for manifest in config["manifests"]:
                        manifests[manifest] = config["manifests"][manifest]

            # Identify each .xml file
            for filename in files:
                if filename[-4:] == ".xml":
                    # If this manifest is listed in a product-config.json,
                    # it will have already been read since we're doing
                    # a top-down walk. So if we don't find it here,
                    # initialize it with a dict that marks it "inactive".
                    # QQQ it should only assume manifests are inactive
                    # if there is NO product-config.json for the current
                    # project.
                    full_filename = os.path.join(root, filename)[2:]
                    if full_filename not in manifests:
                        manifests[full_filename] = {
                          "inactive": True, "type": type
                        }

                    if "type" not in manifests[full_filename]:
                        if root.endswith("toys"):
                            manifests[full_filename]["type"] = "toy"
                        elif root.endswith("features"):
                            manifests[full_filename]["type"] = "feature"
                        else:
                            manifests[full_filename]["type"] = "production"

    return manifests


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--manifest-project", type=str,
                        default="https://github.com/couchbase/manifest",
                        help="Alternate git URL for manifest repository")
    args = parser.parse_args()
    pp = pprint.PrettyPrinter(indent=2)
    pp.pprint(scan_manifests(args.manifest_project))
