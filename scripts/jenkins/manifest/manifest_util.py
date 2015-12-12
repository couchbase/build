import os
from subprocess import check_call
import json
import contextlib

@contextlib.contextmanager
def remember_cwd():
  curdir = os.getcwd()
  try: yield
  finally: os.chdir(curdir)

def scan_manifests(manifest_repo = "couchbase"):
  """
  Syncs to the "manifest" project from the given repository, and
  returns a list of metadata about all discovered manifests
  """
  # Sync manifest project
  if not os.path.isdir("manifest"):
   check_call(["git", "clone",
     "git://github.com/{}/manifest".format(manifest_repo)])
  with remember_cwd():
    os.chdir("manifest")
    print "Updating manifest repository..."
    check_call(["git", "pull"])

    # Scan the current directory for build manifests.
    manifests = {}
    for root, dirs, files in os.walk("."):
    # Prune all legacy manifests, including those in the top-level dir
      if root == ".":
        dirs.remove(".git")
        if "toy" in dirs: dirs.remove("toy")
        if "released" in dirs: dirs.remove("released")
        continue

      # Load manifest metadata where specified
      if "product-config.json" in files:
        with open(os.path.join(root, "product-config.json"), "r") as conffile:
          config = json.load(conffile)
          if not "manifests" in config:
            continue
          for manifest in config["manifests"]:
            manifests[os.path.join(root, manifest)[2:]] = config["manifests"][manifest]

      # Identify each .xml file
      for filename in files:
        if filename[-4:] == ".xml":
          # If this manifest is listed in a product-config.json, it will have
          # already been read since we're doing a top-down walk. So if we don't
          # find it here, initialize it with a dict that marks it "inactive".
          # QQQ it should only assume manifests are inactive if there is NO
          # product-config.json for the current project.
          full_filename = os.path.join(root, filename)[2:]
          if full_filename not in manifests:
            if root.endswith("toys"):
              type = "toy"
            elif root.endswith("features"):
              type = "feature"
            else:
              type = "production"
            manifests[full_filename] = { "inactive": True, "type": type }

  return manifests

