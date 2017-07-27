#!/usr/bin/python

from flask import Flask, render_template
from pprint import pprint
from . import dashboard

@dashboard.route('/dashboard')
def dashboard():
    print ("Reading live builds")
    return render_template('dashboard.html', dashboard=dashboard)
