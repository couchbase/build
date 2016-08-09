import json
from jira import JIRA
import os
import re

def connect_jira():
  """
  Uses private files in ~/.ssh to create a connection to Couchbase Jira. Uses
  Python Jira library. See
  https://developer.atlassian.com/jiradev/jira-apis/jira-rest-apis/jira-rest-api-tutorials/jira-rest-api-example-oauth-authentication

  Expected files:
    build_jira.pem - Private key registered with Jira Application
    build_jira.json - JSON block with "access_token", "access_token_secret",
       and "consumer_key" fields as generated per above URL
  """
  with open("{}/.ssh/build_jira.pem".format(os.environ["HOME"]), "r") as key_cert_file:
    key_cert_data = key_cert_file.read()
  with open("{}/.ssh/build_jira.json".format(os.environ["HOME"]), "r") as oauth_file:
    oauth_dict = json.load(oauth_file)
  oauth_dict["key_cert"] = key_cert_data
  jira = JIRA({"server": "https://issues.couchbase.com"}, oauth=oauth_dict)
  return jira

def get_tickets(message):
  """
  Returns a list of ticket IDs mentioned in a string.
  """
  return re.findall("[A-Z]{2,5}-[0-9]{1,6}", message)

