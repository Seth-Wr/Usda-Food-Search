#!/usr/bin/env bash

# Get the IP address of the main network interface
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' )

# Print the variable to verify
echo "Local IP Address: $LOCAL_IP"

. venv/bin/activate
python -m uvicorn main:app --host 0.0.0.0 --port  8000 --reload
