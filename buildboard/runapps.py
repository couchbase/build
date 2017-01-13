#!/usr/bin/python

from flask import Flask
from rest import rest
from dashboard import dashboard
from buildHistory import buildHistory

app = Flask(__name__)
app.register_blueprint(rest)
app.register_blueprint(dashboard)
app.register_blueprint(buildHistory)
app.run(debug=True, host='0.0.0.0', port=8082)


