#!/usr/bin/python

from flask import Blueprint

buildHistory = Blueprint('buildHistory', __name__)
from . import views
