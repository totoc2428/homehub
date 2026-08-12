#!/usr/bin/env python3
"""
==============================================================================
Script: immich_auto_album.py
Author: DevOps & Linux System Architect
Description: Scans Immich assets, identifies all items not attached to any album,
             and automatically injects them into the "All Photos" album.
Usage:
    export IMMICH_API_KEY="your_key"
    python3 immich_auto_album.py
==============================================================================
"""

import os
import sys
import json
import logging
import urllib.request
import urllib.error
from pathlib import Path

# --- LOGGING CONFIGURATION ---
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("immich_auto_album")


def load_env_file():
    """Locates and loads .env file variables into os.environ if missing."""
    script_dir = Path(__file__).resolve().parent
    env_paths = [
        script_dir / "../stacks/.env",
        script_dir / "../.env",
        Path("/opt/openmedia/stacks/.env"),
    ]
    for env_path in env_paths:
        if env_path.is_file():
            try:
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            os.environ.setdefault(k.strip(), v.strip().strip("'\""))
                logger.info(f"Loaded environment variables from {env_path}")
                break
            except Exception as e:
                logger.warning(f"Could not parse env file {env_path}: {e}")


# Load environment variables
load_env_file()

# --- ENVIRONMENT & CONFIGURATION ---
IMMICH_URL = os.getenv("IMMICH_URL", "http://127.0.0.1:2283").rstrip("/")
IMMICH_API_KEY = os.getenv("IMMICH_API_KEY", "")
TARGET_ALBUM_NAME = os.getenv("TARGET_ALBUM_NAME", "All Photos")

if not IMMICH_API_KEY:
    logger.error("IMMICH_API_KEY environment variable is missing or empty.")
    sys.exit(1)


def api_request(endpoint: str, method: str = "GET", data: dict = None) -> dict:
    """Helper method to make HTTP requests to the Immich REST API using standard urllib."""
    url = f"{IMMICH_URL}{endpoint}"
    headers = {
        "x-api-key": IMMICH_API_KEY,
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    body = json.dumps(data).encode("utf-8") if data else None

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        err_content = e.read().decode("utf-8")
        logger.error(f"HTTP Error {e.code} on {method} {url}: {err_content}")
        raise
    except Exception as e:
        logger.error(f"Failed connection to {method} {url}: {str(e)}")
        raise


def get_or_create_target_album(album_name: str) -> str:
    """Retrieves all existing albums and returns or creates target album by name."""
    logger.info("Retrieving existing albums from Immich...")
    albums = api_request("/api/albums", method="GET")

    for album in albums:
        if album.get("albumName") == album_name:
            album_id = album.get("id")
            logger.info(f"Target album '{album_name}' found (ID: {album_id}).")
            return album_id

    logger.info(f"Album '{album_name}' not found. Creating new album...")
    new_album = api_request("/api/albums", method="POST", data={"albumName": album_name})
    album_id = new_album.get("id")
    logger.info(f"Album '{album_name}' created successfully (ID: {album_id}).")
    return album_id


def get_all_assigned_asset_ids(albums: list) -> set:
    """Collects a set of asset IDs that currently belong to at least one album."""
    assigned_ids = set()
    for album in albums:
        album_id = album.get("id")
        try:
            details = api_request(f"/api/albums/{album_id}", method="GET")
            assets = details.get("assets", [])
            for asset in assets:
                assigned_ids.add(asset.get("id"))
        except Exception as e:
            logger.warning(f"Could not fetch assets for album {album_id}: {e}")
    logger.info(f"Found {len(assigned_ids)} asset(s) currently assigned to albums.")
    return assigned_ids


def get_all_user_assets() -> list:
    """Fetches all assets from the Immich server."""
    logger.info("Fetching all user assets...")
    try:
        results = api_request("/api/search/metadata", method="POST", data={})
        if isinstance(results, dict) and "assets" in results:
            return results["assets"].get("items", [])
        elif isinstance(results, list):
            return results
    except Exception:
        logger.info("Falling back to GET /api/assets...")
        return api_request("/api/assets", method="GET")
    return []


def main():
    logger.info("=== Immich Auto-Album Synchronization Started ===")

    # 1. Get or create "All Photos" album
    target_album_id = get_or_create_target_album(TARGET_ALBUM_NAME)

    # 2. Get list of all albums and build set of assigned assets
    albums = api_request("/api/albums", method="GET")
    assigned_asset_ids = get_all_assigned_asset_ids(albums)

    # 3. Get all user assets
    all_assets = get_all_user_assets()
    logger.info(f"Total assets found on server: {len(all_assets)}")

    # 4. Identify unassigned assets
    unassigned_ids = [
        asset.get("id")
        for asset in all_assets
        if asset.get("id") and asset.get("id") not in assigned_asset_ids
    ]

    logger.info(f"Identified {len(unassigned_ids)} unassigned asset(s).")

    # 5. Inject unassigned assets into target album
    if not unassigned_ids:
        logger.info("No unassigned assets to add. Synchronization complete.")
        return

    # Process in chunks of 500 assets to stay within HTTP payload limits
    chunk_size = 500
    for i in range(0, len(unassigned_ids), chunk_size):
        chunk = unassigned_ids[i : i + chunk_size]
        logger.info(
            f"Adding chunk {i // chunk_size + 1} ({len(chunk)} assets) to album '{TARGET_ALBUM_NAME}'..."
        )
        api_request(
            f"/api/albums/{target_album_id}/assets",
            method="PUT",
            data={"ids": chunk},
        )

    logger.info(f"Successfully added {len(unassigned_ids)} asset(s) to album '{TARGET_ALBUM_NAME}'.")
    logger.info("=== Synchronization Completed Successfully ===")


if __name__ == "__main__":
    main()
