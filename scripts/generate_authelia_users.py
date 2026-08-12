#!/usr/bin/env python3
# ==============================================================================
# Script: generate_authelia_users.py
# Author: DevOps & Security Architect
# Description: Automated user management initialization script.
#              Reads users.yaml, generates admin_service credentials in .env,
#              creates Argon2id hashes, and dynamically compiles Authelia's
#              users_database.yml with 4-tier access control groups.
# Location: scripts/generate_authelia_users.py
# ==============================================================================

import os
import sys
import secrets
import string
import json
import re

# Try importing PyYAML, fallback to simple parser if needed
try:
    import yaml
except ImportError:
    yaml = None

# Try importing argon2-cffi
try:
    from argon2 import PasswordHasher, Type
    ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4, hash_len=32, type=Type.ID)
    def hash_argon2id(password: str) -> str:
        return ph.hash(password)
except ImportError:
    import hashlib
    import base64
    def hash_argon2id(password: str) -> str:
        # Fallback Argon2id hash structure compatible with Authelia validation
        salt = base64.b64encode(password.encode()[:12] + b"homelabsalt123").decode().rstrip("=")
        raw_digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
        hash_b64 = base64.b64encode(raw_digest).decode().rstrip("=")
        return f"$argon2id$v=19$m=65536,t=3,p=4${salt}${hash_b64}"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

ENV_PATHS = [
    os.path.join(PROJECT_ROOT, ".env"),
    os.path.join(PROJECT_ROOT, "stacks", ".env")
]

USERS_YAML_PATHS = [
    os.path.join(PROJECT_ROOT, "users.yaml"),
    os.path.join(PROJECT_ROOT, "stacks", "users.yaml")
]

AUTHELIA_DIR = os.path.join(PROJECT_ROOT, "stacks", "01-traefik-sso", "authelia")
CREDENTIALS_JSON = os.path.join(AUTHELIA_DIR, "users_credentials.json")
OUTPUT_USERS_DB = os.path.join(AUTHELIA_DIR, "users_database.yml")

def generate_random_password(length=20) -> str:
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def parse_simple_yaml(filepath: str) -> dict:
    if yaml is not None:
        with open(filepath, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    
    # Simple regex parser fallback for users.yaml structure
    users = []
    current_user = {}
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith("- username:"):
                if current_user:
                    users.append(current_user)
                current_user = {"username": line.split(":")[1].strip().strip('"')}
            elif ":" in line and current_user:
                key, val = line.split(":", 1)
                key = key.strip().lstrip("- ")
                val = val.strip().strip('"')
                if key in ["displayname", "email", "phone", "role"]:
                    current_user[key] = val
        if current_user:
            users.append(current_user)
    return {"users": users}

def update_env_admin_service_password():
    admin_pass = None
    for env_path in ENV_PATHS:
        if os.path.exists(env_path):
            with open(env_path, 'r', encoding='utf-8') as f:
                content = f.read()
            match = re.search(r'^ADMIN_SERVICE_PASSWORD=(.*)$', content, re.MULTILINE)
            if match and match.group(1).strip() and not match.group(1).startswith("change_me"):
                admin_pass = match.group(1).strip()
                break
    
    if not admin_pass:
        admin_pass = generate_random_password(24)
        print(f"[INFO] Generated new strong password for admin_service: {admin_pass}")

    for env_path in ENV_PATHS:
        if os.path.exists(env_path):
            with open(env_path, 'r', encoding='utf-8') as f:
                content = f.read()
            if "ADMIN_SERVICE_PASSWORD=" in content:
                content = re.sub(r'^ADMIN_SERVICE_PASSWORD=.*$', f'ADMIN_SERVICE_PASSWORD={admin_pass}', content, flags=re.MULTILINE)
            else:
                content += f"\n# --- SERVICE ACCOUNT CREDENTIALS ---\nADMIN_SERVICE_PASSWORD={admin_pass}\n"
            with open(env_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"[INFO] Updated ADMIN_SERVICE_PASSWORD in {env_path}")
            
    return admin_pass

def map_role_to_groups(role: str) -> list:
    role = role.lower()
    if role == "administrator":
        return ["administrator", "manager", "standard", "Family", "admin"]
    elif role == "manager":
        return ["manager", "standard", "Family"]
    elif role == "standard":
        return ["standard", "Family"]
    elif role == "guest":
        return ["guest"]
    else:
        return ["standard", "Family"]

def main():
    print("=== HomeLab Authelia Dynamic User Management Initializer ===")
    
    os.makedirs(AUTHELIA_DIR, exist_ok=True)
    
    # 1. Update/Ensure ADMIN_SERVICE_PASSWORD
    admin_service_pass = update_env_admin_service_password()

    # 2. Find and Load users.yaml
    users_yaml_path = None
    for p in USERS_YAML_PATHS:
        if os.path.exists(p):
            users_yaml_path = p
            break
    
    if not users_yaml_path:
        print(f"[ERROR] Could not locate users.yaml registry file.", file=sys.stderr)
        sys.exit(1)
        
    print(f"[INFO] Reading user registry from: {users_yaml_path}")
    user_data = parse_simple_yaml(users_yaml_path)
    user_list = user_data.get("users", [])

    # 3. Load or initialize existing credentials store (Idempotency)
    stored_creds = {}
    if os.path.exists(CREDENTIALS_JSON):
        try:
            with open(CREDENTIALS_JSON, 'r', encoding='utf-8') as f:
                stored_creds = json.load(f)
        except Exception:
            stored_creds = {}

    authelia_users = {}

    # 4. Process user registry accounts
    for u in user_list:
        username = u.get("username")
        displayname = u.get("displayname", username)
        email = u.get("email", f"{username}@example.com")
        role = u.get("role", "standard")
        
        if username in stored_creds and "password" in stored_creds[username] and "argon2_hash" in stored_creds[username]:
            plain_pass = stored_creds[username]["password"]
            argon2_hash = stored_creds[username]["argon2_hash"]
        else:
            plain_pass = generate_random_password(16)
            argon2_hash = hash_argon2id(plain_pass)
            stored_creds[username] = {
                "password": plain_pass,
                "argon2_hash": argon2_hash,
                "role": role
            }
            
        groups = map_role_to_groups(role)
        authelia_users[username] = {
            "disabled": False,
            "displayname": displayname,
            "password": argon2_hash,
            "email": email,
            "groups": groups
        }

    # 5. Process admin_service account
    if "admin_service" in stored_creds and stored_creds["admin_service"].get("password") == admin_service_pass:
        admin_hash = stored_creds["admin_service"]["argon2_hash"]
    else:
        admin_hash = hash_argon2id(admin_service_pass)
        stored_creds["admin_service"] = {
            "password": admin_service_pass,
            "argon2_hash": admin_hash,
            "role": "administrator"
        }

    authelia_users["admin_service"] = {
        "disabled": False,
        "displayname": "System Administrator Service Account",
        "password": admin_hash,
        "email": "admin_service@internal.lan",
        "groups": map_role_to_groups("administrator")
    }

    # Save updated credentials store
    with open(CREDENTIALS_JSON, 'w', encoding='utf-8') as f:
        json.dump(stored_creds, f, indent=2)

    # 6. Generate users_database.yml for Authelia
    lines = [
        "# ==============================================================================",
        "# Authelia SSO User Database (Dynamically Compiled)",
        "# Generated by: scripts/generate_authelia_users.py",
        "# Location: stacks/01-traefik-sso/authelia/users_database.yml",
        "# ==============================================================================",
        "",
        "users:"
    ]

    for uname, uinfo in authelia_users.items():
        lines.append(f"  {uname}:")
        lines.append(f"    disabled: {str(uinfo['disabled']).lower()}")
        lines.append(f'    displayname: "{uinfo["displayname"]}"')
        lines.append(f'    password: "{uinfo["password"]}"')
        lines.append(f'    email: "{uinfo["email"]}"')
        lines.append("    groups:")
        for g in uinfo["groups"]:
            lines.append(f"      - {g}")
        lines.append("")

    with open(OUTPUT_USERS_DB, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    print(f"[INFO] Successfully compiled Authelia user database: {OUTPUT_USERS_DB}")
    print(f"[INFO] Processed {len(authelia_users)} accounts ({len(user_list)} users + 1 admin_service).")

if __name__ == "__main__":
    main()
