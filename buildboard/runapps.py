#!/usr/bin/python

from flask import Flask
from buildHistory import buildHistory
from dashboard import dashboard

app = Flask(__name__)
app.register_blueprint(dashboard)
app.register_blueprint(buildHistory)
app.run(debug=True, host='0.0.0.0', port=8082)


