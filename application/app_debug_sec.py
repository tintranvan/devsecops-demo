#!/usr/bin/env python3
import os
import subprocess

# Potential security vulnerability - command injection
def unsafe_command(user_input):
    # This is intentionally vulnerable for testing
    command = f"echo {user_input}"
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return result.stdout

# SQL injection vulnerability
def unsafe_sql(user_id):
    query = f"SELECT * FROM users WHERE id = {user_id}"
    return query

if __name__ == "__main__":
    # Test the vulnerable functions
    print(unsafe_command("test"))
    print(unsafe_sql("1"))

# Hard-coded credentials (security issue)
API_KEY = 'sk-1234567890abcdef'
DATABASE_PASSWORD = 'admin123'

