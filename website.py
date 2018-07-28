#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from subprocess import Popen
from flask import Flask, redirect, url_for, render_template, send_file
from uuid import uuid4
import time
from pathlib import Path

app = Flask(__name__)

root_usr_config = Path('client-configs', 'files')


@app.route('/')
def index():
    uuid = str(uuid4())
    p = Popen(["./create_client.sh", uuid])
    while p.poll() is None:
        print('wait')
        time.sleep(1)
    return redirect(url_for('config', uuid=uuid))


@app.route('/config/<uuid>')
def config(uuid):
    all_files = (root_usr_config / uuid).glob('*.ovpn')
    names = [f.name for f in all_files]
    return render_template('config.html', uuid=uuid, filenames=names)


@app.route('/download/<uuid>/<filename>')
def download(uuid, filename):
    to_send = str(root_usr_config / uuid / filename)
    return send_file(to_send, attachment_filename=filename, as_attachment=True, mimetype='application/x-openvpn-profile')

if __name__ == "__main__":
    app.run()
