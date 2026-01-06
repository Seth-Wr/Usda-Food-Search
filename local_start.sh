#!/usr/bin/env bash


. venv/bin/activate
python -m uvicorn main:app --port  8000 --reload
