#!/usr/bin/python
import json
from flask import Flask, request
from flask.json import jsonify

from . import rest
from util.buildDBI import *

@rest.route('/builds/api/lastSuccessfulBuild', methods=['GET'])
def get_last_successful_build():
    version = request.args.get('ver')
    return jsonify({'build_num': db_get_last_successful_build(version)})

