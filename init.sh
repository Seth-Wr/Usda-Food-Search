#!/usr/bin/env sh

# create new fastapi app

python3 -m venv --without-pip --copies venv
. venv/bin/activate
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
pip install --upgrade pip
pip install "fastapi[standard]"
pip install pandas
