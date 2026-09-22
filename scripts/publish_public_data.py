#!/usr/bin/env python3
"""
Maintenance script: refresh the public, link-shared Google Drive zip that
`make up` / `make pull-data` download via `gdown` for zero-login data restore
on a new machine (see Makefile `_ensure-data` / `PUBLIC_DATA_FILE_ID`).

The project keeps TWO independent copies of the four raw data items
(`data/briefing.csv`, `data/campaigns_inventory_updated.csv`,
`data/global_design_data.json`, `data/Creative Assets_`):

  1. The DVC remote (Google Drive, private, requires the maintainer's own
     Google account) -- kept current with `dvc push` (see README).
  2. This public, anyone-with-the-link zip -- kept current by this script.

Whenever the raw source data changes, run BOTH `dvc push` (scoped to the
four raw `.dvc` targets, per README) AND this script, or the two copies
will drift out of sync and new machines will silently bootstrap from a
stale public snapshot.

This script re-uses the same OAuth app/credentials DVC's `gdrive` remote
already has configured (`.dvc/config.local` + the cached pydrive2fs token),
so it only works for whoever has already authenticated `dvc push` on this
machine. It replaces the CONTENTS of the existing public file in place
(`files.update` with the same file ID), so the public download link/ID
(`PUBLIC_DATA_FILE_ID` in the Makefile) never changes.

Usage:
    .venv/bin/python scripts/publish_public_data.py
"""
import configparser
import glob
import json
import os
import sys
import tempfile
import zipfile

import requests

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(REPO_ROOT, "data")
RAW_ITEMS = [
    "briefing.csv",
    "campaigns_inventory_updated.csv",
    "global_design_data.json",
    "Creative Assets_",
]
# Must match Makefile's PUBLIC_DATA_FILE_ID -- update both together if this
# file is ever recreated instead of updated in place.
PUBLIC_DATA_FILE_ID = "1-InNX4PmoM9gRp-y-89u23d-WAz6MOIz"


def _read_dvc_local_config():
    cfg = configparser.ConfigParser()
    cfg.read(os.path.join(REPO_ROOT, ".dvc", "config.local"))
    section = 'remote "gdrive_storage"'
    if section not in cfg:
        sys.exit(
            "No [remote \"gdrive_storage\"] section in .dvc/config.local. "
            "Run `dvc push` once first to authenticate, or see README's "
            "OAuth-client setup instructions."
        )
    return cfg[section]["gdrive_client_id"], cfg[section]["gdrive_client_secret"]


def _find_cached_refresh_token(client_id):
    pattern = os.path.expanduser(f"~/.cache/pydrive2fs/*{client_id}*/default.json")
    matches = glob.glob(pattern)
    if not matches:
        sys.exit(
            "No cached pydrive2fs token found for this OAuth client. Run "
            "`dvc push` once first to authenticate this machine."
        )
    with open(matches[0]) as f:
        token = json.load(f)
    return token["refresh_token"]


def _get_access_token(client_id, client_secret, refresh_token):
    resp = requests.post(
        "https://oauth2.googleapis.com/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def _zip_raw_data(zip_path):
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for item in RAW_ITEMS:
            src = os.path.join(DATA_DIR, item)
            if not os.path.exists(src):
                sys.exit(f"Missing '{src}' -- run `make pull-data` first so all four raw items are present locally.")
            if os.path.isdir(src):
                for root, _dirs, files in os.walk(src):
                    for name in files:
                        full = os.path.join(root, name)
                        arcname = os.path.relpath(full, DATA_DIR)
                        zf.write(full, arcname)
            else:
                zf.write(src, item)


def _update_file_content(access_token, zip_path):
    size = os.path.getsize(zip_path)
    print(f"Uploading {size / 1e6:.1f} MB to Drive file {PUBLIC_DATA_FILE_ID}...")
    with open(zip_path, "rb") as f:
        resp = requests.patch(
            f"https://www.googleapis.com/upload/drive/v3/files/{PUBLIC_DATA_FILE_ID}",
            params={"uploadType": "media"},
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/zip",
            },
            data=f,
            timeout=600,
        )
    resp.raise_for_status()
    return resp.json()


def main():
    client_id, client_secret = _read_dvc_local_config()
    refresh_token = _find_cached_refresh_token(client_id)
    access_token = _get_access_token(client_id, client_secret, refresh_token)

    with tempfile.TemporaryDirectory() as tmpdir:
        zip_path = os.path.join(tmpdir, "adcreative_raw_data.zip")
        print("Zipping raw data (briefing.csv, campaigns_inventory_updated.csv, global_design_data.json, Creative Assets_)...")
        _zip_raw_data(zip_path)
        result = _update_file_content(access_token, zip_path)

    print(f"Done. Public file updated in place: {result.get('id')}")
    print("The download link/ID for `make up` did not change -- nothing else needs updating.")


if __name__ == "__main__":
    main()
