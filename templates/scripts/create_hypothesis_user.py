#!/usr/bin/env python3
import sys
import subprocess
import secrets


class SafeString(str):
    def __repr__(self):
        return "***"


def run(args):
    print("+", args, flush=True)
    subprocess.run(args)


username = sys.argv[1]
password = SafeString(secrets.token_urlsafe(32))  # 256 bits
authority = ${liquid_domain|tojson}
h_users_txt = sys.argv[2] # get all existing users from argument
h_users = set(h_users_txt.split())
if username not in h_users: 
    run([
        "bin/hypothesis", "user", "add",
        "--username", username,
        "--authority", authority,
        "--email", f"{username}@${liquid_domain}",
        "--password", password,
    ])
    print("Created Hypothesis user " + username + ".")
else:
    print("A user with this username already exists.")
